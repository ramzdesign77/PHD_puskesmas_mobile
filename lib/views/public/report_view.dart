import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/village.dart';
import '../../services/api_service.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.apiService});

  final ApiService apiService;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nik = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _imagePicker = ImagePicker();

  late Future<List<Village>> _villages;
  Village? _selectedVillage;
  String? _selectedRt;
  String? _selectedRw;
  String _category = 'air_masalah';
  XFile? _image;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _villages = widget.apiService.getVillages();
  }

  @override
  void dispose() {
    _name.dispose();
    _nik.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (mounted && image != null) {
      setState(() => _image = image);
    }
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'Aktifkan layanan lokasi untuk mengirim laporan.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Izin lokasi diperlukan untuk mengirim laporan.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedVillage == null) {
      if (_selectedVillage == null) {
        _showError('Pilih desa atau kelurahan terlebih dahulu.');
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final position = await _currentPosition();
      final ticketCode = await widget.apiService.submitReport(
        fields: {
          'nama_pelapor': _name.text.trim(),
          'nik_pelapor': _nik.text.trim(),
          'no_wa': _phone.text.trim(),
          'id_desa': _selectedVillage!.id.toString(),
          'rt': _selectedRt ?? '',
          'rw': _selectedRw ?? '',
          'kategori_laporan': _category,
          'deskripsi': _description.text.trim(),
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        },
        image: _image,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.green,
            size: 48,
          ),
          title: Text(
            'Laporan Terkirim',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Simpan kode tiket ini untuk memeriksa status laporan:',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.softRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  ticketCode,
                  style: GoogleFonts.dmSans(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Center(
              child: SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Selesai'),
                ),
              ),
            ),
          ],
        ),
      );

      _formKey.currentState!.reset();
      _name.clear();
      _nik.clear();
      _phone.clear();
      _description.clear();
      setState(() {
        _selectedVillage = null;
        _selectedRt = null;
        _selectedRw = null;
        _category = 'air_masalah';
        _image = null;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        'Laporan belum dapat dikirim. Periksa koneksi dan izin lokasi.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.dmSans(
        color: AppColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.softRed,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Header Curved Maroon Background
            Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -25,
                    top: -15,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    top: 48,
                    child: Icon(
                      Icons.health_and_safety,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),

            // Content: Top Bar, Titles, and Overlapping Form Card
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Buat Laporan',
                          style: GoogleFonts.dmSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sampaikan masalah air atau sanitasi\ndi lingkungan Anda.',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],
                    ),
                  ),

                  // Overlapping White Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ============================================
                            // Section 1: Data Pelapor
                            // ============================================
                            _buildSectionHeader(
                              icon: Icons.person_outline,
                              title: 'Data Pelapor',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _name,
                              validator: _required,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Nama lengkap',
                                prefixIcon: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nik,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                return RegExp(r'^\d{16}$').hasMatch(value.trim())
                                    ? null
                                    : 'NIK harus terdiri dari 16 angka.';
                              },
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'NIK',
                                prefixIcon: const Icon(
                                  Icons.badge_outlined,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Nomor telepon',
                                prefixIcon: const Icon(
                                  Icons.phone_outlined,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                              ),
                            ),

                            // ============================================
                            // Section 2: Lokasi Kejadian
                            // ============================================
                            const SizedBox(height: 22),
                            _buildSectionHeader(
                              icon: Icons.location_on_outlined,
                              title: 'Lokasi Kejadian',
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Desa / Kelurahan'),
                            FutureBuilder<List<Village>>(
                              future: _villages,
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return _RetryVillage(
                                    onRetry: () => setState(
                                      () => _villages =
                                          widget.apiService.getVillages(),
                                    ),
                                  );
                                }

                                return DropdownButtonFormField<Village>(
                                  value: _selectedVillage,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.muted,
                                  ),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText: 'Pilih desa',
                                    prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                      color: AppColors.muted,
                                      size: 20,
                                    ),
                                  ),
                                  items: (snapshot.data ?? []).map((village) {
                                    return DropdownMenuItem(
                                      value: village,
                                      child: Text(
                                        village.name,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (village) => setState(
                                    () => _selectedVillage = village,
                                  ),
                                  validator: (val) => val == null
                                      ? 'Pilih desa atau kelurahan.'
                                      : null,
                                  hint: Text(
                                    'Pilih desa',
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRt,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.muted,
                                    ),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                    decoration: _fieldDecoration(
                                      hintText: 'RT',
                                      prefixIcon: const Icon(
                                        Icons.location_on_outlined,
                                        color: AppColors.muted,
                                        size: 20,
                                      ),
                                    ),
                                    hint: Text(
                                      'RT',
                                      style: GoogleFonts.dmSans(
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: List.generate(30, (i) {
                                      final numStr =
                                          (i + 1).toString().padLeft(2, '0');
                                      return DropdownMenuItem(
                                        value: numStr,
                                        child: Text(
                                          'RT $numStr',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) =>
                                        setState(() => _selectedRt = val),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                            ? 'Pilih RT'
                                            : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRw,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.muted,
                                    ),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                    decoration: _fieldDecoration(
                                      hintText: 'RW',
                                      prefixIcon: const Icon(
                                        Icons.home_outlined,
                                        color: AppColors.muted,
                                        size: 20,
                                      ),
                                    ),
                                    hint: Text(
                                      'RW',
                                      style: GoogleFonts.dmSans(
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                    items: List.generate(20, (i) {
                                      final numStr =
                                          (i + 1).toString().padLeft(2, '0');
                                      return DropdownMenuItem(
                                        value: numStr,
                                        child: Text(
                                          'RW $numStr',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      );
                                    }),
                                    onChanged: (val) =>
                                        setState(() => _selectedRw = val),
                                    validator: (val) =>
                                        val == null || val.isEmpty
                                            ? 'Pilih RW'
                                            : null,
                                  ),
                                ),
                              ],
                            ),

                            // ============================================
                            // Section 3: Detail Laporan
                            // ============================================
                            const SizedBox(height: 22),
                            _buildSectionHeader(
                              icon: Icons.description_outlined,
                              title: 'Detail Laporan',
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Kategori Laporan'),
                            DropdownButtonFormField<String>(
                              value: _category,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.muted,
                              ),
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Kategori Laporan',
                                prefixIcon: const Icon(
                                  Icons.water_drop,
                                  color: Color(0xFF374151),
                                  size: 20,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'air_masalah',
                                  child: Text('Masalah air'),
                                ),
                                DropdownMenuItem(
                                  value: 'sanitasi_lingkungan',
                                  child: Text('Sanitasi lingkungan'),
                                ),
                              ],
                              onChanged: (val) => setState(
                                () => _category = val ?? 'air_masalah',
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFieldLabel('Deskripsi masalah'),
                            Stack(
                              children: [
                                TextFormField(
                                  controller: _description,
                                  minLines: 4,
                                  maxLines: 6,
                                  maxLength: 2000,
                                  buildCounter: (
                                    context, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) =>
                                      null,
                                  onChanged: (_) => setState(() {}),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText:
                                        'Jelaskan secara singkat dan jelas mengenai masalah yang terjadi...',
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      40,
                                      14,
                                      14,
                                      28,
                                    ),
                                  ),
                                  validator: (value) {
                                    final required = _required(value);
                                    if (required != null) return required;
                                    return value!.trim().length < 10
                                        ? 'Deskripsi minimal 10 karakter.'
                                        : null;
                                  },
                                ),
                                const Positioned(
                                  top: 14,
                                  left: 12,
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: AppColors.muted,
                                    size: 20,
                                  ),
                                ),
                                Positioned(
                                  right: 14,
                                  bottom: 8,
                                  child: Text(
                                    '${_description.text.length}/2000',
                                    style: GoogleFonts.dmSans(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Optional photo proof attachment
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _pickImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _image == null
                                          ? Icons.camera_alt_outlined
                                          : Icons.check_circle,
                                      color: AppColors.primary,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _image == null
                                            ? 'Pilih foto bukti (opsional)'
                                            : 'Foto: ${_image!.name}',
                                        style: GoogleFonts.dmSans(
                                          color: _image == null
                                              ? AppColors.muted
                                              : AppColors.ink,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_image != null)
                                      InkWell(
                                        onTap: () => setState(() => _image = null),
                                        child: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_image != null) ...[
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_image!.path),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],

                            // ============================================
                            // Tombol Aksi Utama: Kirim Laporan
                            // ============================================
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shadowColor: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.rotate(
                                            angle: -0.4,
                                            child: const Icon(
                                              Icons.send_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Kirim Laporan',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryVillage extends StatelessWidget {
  const _RetryVillage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Desa / kelurahan',
        errorText: 'Daftar desa tidak dapat dimuat.',
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          label: Text(
            'Muat ulang',
            style: GoogleFonts.dmSans(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
