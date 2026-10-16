import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/visit_schedule.dart';
import '../../services/officer_api_service.dart';

/// Halaman Detail Laporan + Form Aksi Petugas.
///
/// Menampilkan:
///   1. Detail laporan warga (read-only)
///   2. Form aksi petugas di bawahnya:
///      - Upload foto bukti (image_picker — kamera)
///      - Dropdown update status
///      - TextField catatan / rekomendasi
///      - Tombol Simpan (multipart/form-data)
class OfficerDetailView extends StatefulWidget {
  const OfficerDetailView({
    super.key,
    required this.schedule,
    required this.token,
    required this.apiService,
  });

  final VisitSchedule schedule;
  final String token;
  final OfficerApiService apiService;

  @override
  State<OfficerDetailView> createState() => _OfficerDetailViewState();
}

class _OfficerDetailViewState extends State<OfficerDetailView> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();

  late String _selectedStatus;
  XFile? _pickedPhoto;
  bool _isSubmitting = false;

  // Opsi status yang bisa dipilih petugas
  static const List<Map<String, String>> _statusOptions = [
    {'value': 'diproses', 'label': 'Diproses'},
    {'value': 'selesai', 'label': 'Selesai'},
  ];

  @override
  void initState() {
    super.initState();
    // Set status awal dari data yang sudah ada
    _selectedStatus =
        widget.schedule.status == 'selesai' ? 'selesai' : 'diproses';
    _noteCtrl.text = widget.schedule.officerNote;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Ambil Foto dari Kamera ─────────────────────────────────────
  Future<void> _pickPhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (photo != null && mounted) {
        setState(() => _pickedPhoto = photo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka kamera: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Simpan / Submit ke Backend ─────────────────────────────────
  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.apiService.submitVisitResult(
        token: widget.token,
        scheduleId: widget.schedule.id,
        status: _selectedStatus,
        officerNote: _noteCtrl.text.trim(),
        photo: _pickedPhoto,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil menyimpan laporan kunjungan!'),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Kembalikan objek yang sudah diperbarui ke dashboard
      final updated = widget.schedule.copyWith(
        status: _selectedStatus,
        officerNote: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiOfficerException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Gagal mengirim data. Periksa koneksi Anda.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          s.ticketCode.isEmpty ? 'Detail Laporan' : s.ticketCode,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.line),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── BAGIAN 1: Detail Laporan Warga ───────────────
            _buildSectionTitle('Informasi Laporan Warga'),
            const SizedBox(height: 10),
            _buildDetailCard(s),
            const SizedBox(height: 24),

            // ── BAGIAN 2: Form Aksi Petugas ──────────────────
            _buildSectionTitle('Form Aksi Petugas'),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Foto Bukti
                  _buildPhotoSection(),
                  const SizedBox(height: 16),

                  // Dropdown Status
                  _buildStatusDropdown(),
                  const SizedBox(height: 16),

                  // Catatan Petugas
                  _buildNoteField(),
                  const SizedBox(height: 24),

                  // Tombol Simpan
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detail Card Laporan ────────────────────────────────────────
  Widget _buildDetailCard(VisitSchedule s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Nama Pelapor', value: s.reporterName),
          _DetailRow(label: 'Kategori', value: s.category),
          _DetailRow(label: 'Desa', value: s.village),
          _DetailRow(label: 'Alamat', value: s.address),
          _DetailRow(label: 'RT / RW', value: 'RT ${s.rt} / RW ${s.rw}'),
          _DetailRow(label: 'Tanggal Kunjungan', value: s.visitDate),
          _DetailRow(
            label: 'Deskripsi Masalah',
            value: s.description,
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ── Upload Foto ────────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: 'Foto Bukti Kunjungan'),
        const SizedBox(height: 8),
        GestureDetector(
          key: const Key('officer_photo_picker'),
          onTap: _pickPhoto,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _pickedPhoto != null
                    ? AppColors.green
                    : AppColors.line,
                width: 1.5,
              ),
            ),
            child: _pickedPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.file(
                      File(_pickedPhoto!.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Ketuk untuk membuka kamera',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Ambil foto bukti kunjungan lapangan',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (_pickedPhoto != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              onPressed: () => setState(() => _pickedPhoto = null),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Hapus Foto'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }

  // ── Dropdown Status ────────────────────────────────────────────
  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Update Status Kunjungan'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('officer_status_dropdown'),
          initialValue: _selectedStatus,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.flag_outlined,
              color: AppColors.muted,
              size: 20,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          items: _statusOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(opt['label']!),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedStatus = v);
          },
        ),
      ],
    );
  }

  // ── TextField Catatan ──────────────────────────────────────────
  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Catatan / Rekomendasi Petugas'),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('officer_note_field'),
          controller: _noteCtrl,
          maxLines: 5,
          minLines: 3,
          textInputAction: TextInputAction.newline,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Catatan tidak boleh kosong.'
              : null,
          decoration: InputDecoration(
            hintText:
                'Tulis temuan lapangan, rekomendasi sanitasi, atau tindak lanjut...',
            hintStyle:
                const TextStyle(color: AppColors.muted, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tombol Simpan ──────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        key: const Key('officer_submit_button'),
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Simpan Laporan Kunjungan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Baris detail info (label + value)
// ────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.line),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Label field form
// ────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}
