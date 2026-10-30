import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/visit_schedule.dart';
import '../../services/officer_api_service.dart';
import '../../theme/app_theme.dart';

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
  final _distanceController = TextEditingController();
  final _interventionNoteController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _legacyNoteController = TextEditingController();
  final _picker = ImagePicker();
  final List<bool> _riskIndicators = List<bool>.filled(5, false);

  String _waterSource = 'Sumur Gali';
  String _intervention = 'Tidak Ada';
  String _selectedStatus = 'diproses';
  XFile? _pickedPhoto;
  bool _isSubmitting = false;

  static const _waterSources = [
    'Sumur Gali',
    'Sumur Bor/Pompa',
    'Perpipaan/PDAM',
  ];
  static const _interventions = [
    'Pemberian Kaporit',
    'Pemberian Bubuk Abate',
    'Edukasi & Konseling PAMMRT',
    'Tidak Ada',
  ];
  static const _riskLabels = [
    'Air berwarna, keruh, atau memiliki rasa tidak normal',
    'Air berbau tidak normal',
    'Terdapat kemungkinan pencemaran di sekitar sumber air',
    'Konstruksi sumber air tidak terlindungi dengan baik',
    'Jarak sumber air ke sumber pencemar kurang dari 10 meter',
  ];

  int get _riskScore => _riskIndicators.where((indicator) => indicator).length;

  Color get _riskColor {
    if (_riskScore <= 1) return AppColors.green;
    if (_riskScore <= 3) return AppColors.orange;
    return const Color(0xFFE53935);
  }

  String get _riskTitle {
    if (_riskScore <= 1) return 'Aman / Risiko Rendah';
    if (_riskScore <= 3) return 'Risiko Sedang';
    return 'Risiko Tinggi';
  }

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.schedule.status.toLowerCase() == 'selesai'
        ? 'selesai'
        : 'diproses';
    _legacyNoteController.text = widget.schedule.officerNote;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _interventionNoteController.dispose();
    _recommendationController.dispose();
    _legacyNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (photo != null && mounted) setState(() => _pickedPhoto = photo);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal membuka kamera: $error', isError: true);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final distance = double.parse(_distanceController.text.trim());
      await widget.apiService.submitInspection(
        token: widget.token,
        scheduleId: widget.schedule.id,
        waterSource: _waterSource,
        pollutantDistance: distance,
        riskIndicators: List.unmodifiable(_riskIndicators),
        intervention: _intervention,
        interventionNote: _interventionNoteController.text.trim(),
        recommendation: _recommendationController.text.trim(),
        visitStatus: _selectedStatus,
        officerNote: _legacyNoteController.text.trim(),
      );

      if (_pickedPhoto != null) {
        await widget.apiService.submitVisitResult(
          token: widget.token,
          scheduleId: widget.schedule.id,
          status: _selectedStatus,
          officerNote: _legacyInspectionNote,
          photo: _pickedPhoto,
        );
      }

      if (!mounted) return;
      _showMessage('Form inspeksi IKL berhasil disimpan.');
      Navigator.of(context).pop(
        widget.schedule.copyWith(
          status: _selectedStatus,
          officerNote: _recommendationController.text.trim(),
        ),
      );
    } on ApiOfficerException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        await _submitLegacyResult();
      } else if (mounted) {
        _showMessage(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal mengirim form IKL: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitLegacyResult() async {
    try {
      await widget.apiService.submitVisitResult(
        token: widget.token,
        scheduleId: widget.schedule.id,
        status: _selectedStatus,
        officerNote: _legacyInspectionNote,
        photo: _pickedPhoto,
      );
      if (!mounted) return;
      _showMessage(
        'Endpoint IKL belum tersedia. Catatan kunjungan tersimpan melalui layanan lama.',
      );
      Navigator.of(context).pop(
        widget.schedule.copyWith(
          status: _selectedStatus,
          officerNote: _legacyNoteController.text.trim(),
        ),
      );
    } on ApiOfficerException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal menyimpan kunjungan: $error', isError: true);
      }
    }
  }

  String get _legacyInspectionNote => [
    if (_legacyNoteController.text.trim().isNotEmpty)
      _legacyNoteController.text.trim(),
    'Sarana air: $_waterSource',
    'Jarak sumber pencemar: ${_distanceController.text.trim()} meter',
    'Indikator risiko: ${_riskIndicators.map((active) => active ? 1 : 0).join(',')}',
    'Skor risiko: $_riskScore/5 ($_riskTitle)',
    'Intervensi: $_intervention',
    if (_interventionNoteController.text.trim().isNotEmpty)
      'Catatan intervensi: ${_interventionNoteController.text.trim()}',
    'Rekomendasi: ${_recommendationController.text.trim()}',
  ].join('\n');

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primaryDark : AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          schedule.ticketCode.isEmpty
              ? 'Form Inspeksi IKL'
              : schedule.ticketCode,
          style: const TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ).asHeading,
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _sectionTitle('Informasi Laporan / Jadwal'),
            const SizedBox(height: 10),
            _buildScheduleCard(schedule),
            const SizedBox(height: 22),
            _sectionTitle('Kuesioner Inspeksi Kesehatan Lingkungan'),
            const SizedBox(height: 10),
            _buildWaterSourceCard(),
            const SizedBox(height: 14),
            _buildRiskIndicators(),
            const SizedBox(height: 14),
            _buildRiskScore(),
            const SizedBox(height: 22),
            _sectionTitle('Intervensi dan Rekomendasi'),
            const SizedBox(height: 10),
            _buildInterventionFields(),
            const SizedBox(height: 14),
            _buildLegacyVisitFields(),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const Key('officer_submit_button'),
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSubmitting ? 'Menyimpan...' : 'Simpan Hasil IKL',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(VisitSchedule schedule) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Nama Pelapor', value: schedule.reporterName),
          _InfoRow(label: 'Kategori', value: schedule.category),
          _InfoRow(label: 'Desa', value: schedule.village),
          _InfoRow(label: 'Alamat', value: schedule.address),
          _InfoRow(
            label: 'RT / RW',
            value: 'RT ${schedule.rt} / RW ${schedule.rw}',
          ),
          _InfoRow(label: 'Tanggal Kunjungan', value: schedule.visitDate),
          _InfoRow(
            label: 'Keterangan',
            value: schedule.description,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterSourceCard() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Jenis Sarana Air'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('officer_water_source_dropdown'),
            initialValue: _waterSource,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.water_drop_outlined),
              isDense: true,
            ),
            items: _waterSources
                .map(
                  (source) =>
                      DropdownMenuItem(value: source, child: Text(source)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _waterSource = value);
            },
          ),
          const SizedBox(height: 15),
          const _FieldLabel(text: 'Jarak ke Sumber Pencemar'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_pollutant_distance_field'),
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            validator: (value) {
              final distance = double.tryParse(value?.trim() ?? '');
              if (distance == null) return 'Masukkan jarak dalam meter.';
              if (distance < 0) return 'Jarak tidak boleh kurang dari nol.';
              return null;
            },
            decoration: const InputDecoration(
              hintText: 'Contoh: 10',
              suffixText: 'meter',
              prefixIcon: Icon(Icons.straighten_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskIndicators() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Indikator Risiko Fisik Air'),
          const SizedBox(height: 4),
          const Text(
            'Pilih semua kondisi yang ditemukan saat inspeksi.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _riskLabels.length; index++)
            CheckboxListTile(
              key: Key('officer_ikl_p${index + 1}'),
              value: _riskIndicators[index],
              onChanged: (value) =>
                  setState(() => _riskIndicators[index] = value ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                _riskLabels[index],
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiskScore() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _riskColor.withValues(alpha: 0.1),
        border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: _riskColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.health_and_safety_outlined, color: _riskColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Skor Risiko Real-time',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  _riskTitle,
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_riskScore/5',
            style: TextStyle(
              color: _riskColor,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterventionFields() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Intervensi Fisik'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('officer_intervention_dropdown'),
            initialValue: _intervention,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.medical_services_outlined),
              isDense: true,
            ),
            items: _interventions
                .map(
                  (intervention) => DropdownMenuItem(
                    value: intervention,
                    child: Text(intervention, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _intervention = value);
            },
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Catatan Intervensi'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_intervention_note_field'),
            controller: _interventionNoteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Dosis Kaporit/Abate, jumlah, dan tindakan...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Rekomendasi Sanitarian'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_recommendation_field'),
            controller: _recommendationController,
            maxLines: 3,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Rekomendasi sanitarian perlu diisi.'
                : null,
            decoration: const InputDecoration(
              hintText: 'Tulis tindak lanjut dan edukasi yang disarankan...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyVisitFields() {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Status Kunjungan'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('officer_status_dropdown'),
            initialValue: _selectedStatus,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'diproses', child: Text('Diproses')),
              DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedStatus = value);
            },
          ),
          const SizedBox(height: 14),
          const _FieldLabel(text: 'Foto Bukti Kunjungan (opsional)'),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('officer_photo_picker'),
            borderRadius: BorderRadius.circular(12),
            onTap: _pickPhoto,
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _pickedPhoto == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Ketuk untuk mengambil foto',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(
                        File(_pickedPhoto!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          if (_pickedPhoto != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _pickedPhoto = null),
                child: const Text('Hapus foto'),
              ),
            ),
          const SizedBox(height: 12),
          const _FieldLabel(text: 'Catatan Kunjungan'),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('officer_note_field'),
            controller: _legacyNoteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Catatan tambahan kunjungan lapangan...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 19,
          width: 4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTheme.headlineFontFamily,
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ).asHeading,
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 117,
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.line),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}
