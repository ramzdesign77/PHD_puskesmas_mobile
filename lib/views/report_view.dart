import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import '../models/village.dart';
import '../services/api_service.dart';

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
  final _rt = TextEditingController();
  final _rw = TextEditingController();
  final _description = TextEditingController();
  final _imagePicker = ImagePicker();
  late Future<List<Village>> _villages;
  Village? _selectedVillage;
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
    _rt.dispose();
    _rw.dispose();
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
          'rt': _rt.text.trim(),
          'rw': _rw.text.trim(),
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
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.green,
            size: 40,
          ),
          title: const Text('Laporan terkirim'),
          content: Text(
            'Simpan kode tiket ini untuk memeriksa status laporan:\n\n$ticketCode',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
      _formKey.currentState!.reset();
      _name.clear();
      _nik.clear();
      _phone.clear();
      _rt.clear();
      _rw.clear();
      _description.clear();
      setState(() {
        _selectedVillage = null;
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Bagian ini wajib diisi.' : null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Buat laporan',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            const Text(
              'Sampaikan masalah air atau sanitasi di lingkungan Anda.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            _SectionTitle(title: 'Data pelapor'),
            const SizedBox(height: 12),
            _textField(
              controller: _name,
              label: 'Nama lengkap',
              validator: _required,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _nik,
              label: 'NIK',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return RegExp(r'^\d{16}$').hasMatch(value.trim())
                    ? null
                    : 'NIK harus terdiri dari 16 angka.';
              },
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _phone,
              label: 'Nomor telepon',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Lokasi kejadian'),
            const SizedBox(height: 12),
            FutureBuilder<List<Village>>(
              future: _villages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _RetryVillage(
                    onRetry: () => setState(
                      () => _villages = widget.apiService.getVillages(),
                    ),
                  );
                }
                return DropdownButtonFormField<Village>(
                  initialValue: _selectedVillage,
                  decoration: const InputDecoration(
                    labelText: 'Desa / kelurahan',
                  ),
                  items: (snapshot.data ?? [])
                      .map(
                        (village) => DropdownMenuItem(
                          value: village,
                          child: Text(village.name),
                        ),
                      )
                      .toList(),
                  onChanged: snapshot.hasData
                      ? (village) => setState(() => _selectedVillage = village)
                      : null,
                  validator: (_) => _selectedVillage == null
                      ? 'Pilih desa atau kelurahan.'
                      : null,
                  hint: Text(
                    snapshot.connectionState == ConnectionState.waiting
                        ? 'Memuat desa...'
                        : 'Pilih desa',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    controller: _rt,
                    label: 'RT',
                    keyboardType: TextInputType.number,
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    controller: _rw,
                    label: 'RW',
                    keyboardType: TextInputType.number,
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Detail laporan'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori laporan'),
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
              onChanged: (value) =>
                  setState(() => _category = value ?? 'air_masalah'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 4,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Deskripsi masalah',
                alignLabelWithHint: true,
                hintText: 'Jelaskan kondisi dan kapan masalah mulai terjadi.',
              ),
              validator: (value) {
                final required = _required(value);
                if (required != null) return required;
                return value!.trim().length < 10
                    ? 'Deskripsi minimal 10 karakter.'
                    : null;
              },
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: Icon(
                _image == null
                    ? Icons.add_a_photo_outlined
                    : Icons.check_circle_outline,
              ),
              label: Text(
                _image == null
                    ? 'Pilih foto bukti'
                    : 'Foto dipilih: ${_image!.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_image!.path),
                  height: 170,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim laporan'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _RetryVillage extends StatelessWidget {
  const _RetryVillage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Desa / kelurahan',
        errorText: 'Daftar desa tidak dapat dimuat.',
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Muat ulang'),
        ),
      ),
    );
  }
}
