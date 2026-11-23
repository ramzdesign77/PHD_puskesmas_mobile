import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'auth_components.dart';

const _termsSections = [
  _LegalSection(
    '1. Tujuan layanan',
    'Aplikasi Sanitasi Air membantu warga menyampaikan laporan terkait air '
        'dan sanitasi kepada petugas UPTD Puskesmas Sumbersari untuk '
        'ditindaklanjuti sesuai proses dan kewenangan yang berlaku.',
  ),
  _LegalSection(
    '2. Pendaftaran dan keamanan akun',
    'Berikan nama, username, email, dan nomor telepon yang benar dan dapat '
        'dihubungi. Jaga kerahasiaan kata sandi dan jangan menggunakan akun '
        'milik orang lain tanpa izin. Pengguna bertanggung jawab atas '
        'aktivitas yang dilakukan melalui akunnya.',
  ),
  _LegalSection(
    '3. Penggunaan yang bertanggung jawab',
    'Gunakan aplikasi untuk kebutuhan layanan sanitasi. Dilarang mengirim '
        'laporan yang sengaja palsu, mengganggu, mengandung ancaman, '
        'menyamar sebagai orang lain, atau melanggar hak orang lain.',
  ),
  _LegalSection(
    '4. Isi laporan dan foto',
    'Kirim informasi yang relevan dan sesuai keadaan. Pastikan Anda berhak '
        'membagikan foto atau informasi orang lain yang disertakan dalam '
        'laporan. Hindari menyertakan data pribadi yang tidak diperlukan.',
  ),
  _LegalSection(
    '5. Lokasi dan tindak lanjut',
    'Titik GPS bersifat pilihan dan hanya disertakan jika Anda memilih '
        'penggunaan lokasi saat ini. Anda juga dapat mengisi lokasi secara '
        'manual. Laporan membantu petugas melakukan penilaian dan tindak '
        'lanjut, tetapi aplikasi tidak menjamin waktu atau hasil penanganan '
        'tertentu. Untuk keadaan darurat, hubungi layanan darurat yang sesuai.',
  ),
  _LegalSection(
    '6. Ketersediaan layanan',
    'Fitur dapat mengalami pemeliharaan atau gangguan. Pengelola dapat '
        'memperbaiki atau mengubah fitur untuk menjaga layanan tetap berjalan '
        'dan memberi pemberitahuan melalui aplikasi jika perubahan penting.',
  ),
  _LegalSection(
    '7. Privasi dan pertanyaan',
    'Penggunaan data dijelaskan lebih lanjut dalam Kebijakan Privasi. Untuk '
        'pertanyaan, koreksi data, atau kendala akun, hubungi UPTD Puskesmas '
        'Sumbersari melalui kanal resminya.',
  ),
];

const _privacySections = [
  _LegalSection(
    '1. Data yang digunakan',
    'Saat membuat akun, aplikasi meminta nama lengkap, username, email, '
        'nomor telepon, dan kata sandi untuk keperluan akun dan autentikasi. '
        'Saat membuat laporan, aplikasi dapat mengirim nama dan nomor '
        'pelapor, desa, RT/RW, detail alamat, kategori dan uraian keluhan, '
        'serta foto jika Anda memilih untuk melampirkannya.',
  ),
  _LegalSection(
    '2. Data lokasi',
    'Koordinat GPS hanya ditambahkan ke laporan jika Anda memilih fitur '
        'lokasi saat ini dan memberikan izin yang diminta. Jika tidak '
        'memilihnya, Anda dapat mengisi alamat secara manual. Menolak izin '
        'lokasi tidak menghalangi penggunaan formulir laporan manual.',
  ),
  _LegalSection(
    '3. Tujuan penggunaan',
    'Data digunakan untuk membuat dan mengelola akun, menerima serta '
        'memverifikasi laporan, menghubungi pelapor bila diperlukan, '
        'menjadwalkan atau melakukan tindak lanjut, dan meningkatkan '
        'pelayanan sanitasi. Data tidak digunakan untuk tujuan yang tidak '
        'berhubungan dengan layanan tanpa dasar yang sesuai.',
  ),
  _LegalSection(
    '4. Penyimpanan dan pihak yang dapat mengakses',
    'Informasi akun atau sesi tertentu dapat disimpan pada perangkat agar '
        'Anda tetap masuk. Laporan dikirim ke server layanan. Data dapat '
        'diakses oleh petugas berwenang yang menangani layanan dan penyedia '
        'infrastruktur yang diperlukan untuk menjalankan aplikasi. Data tidak '
        'diperjualbelikan. Data dapat disampaikan jika diwajibkan oleh '
        'peraturan atau proses hukum yang sah.',
  ),
  _LegalSection(
    '5. Peta dan layanan eksternal',
    'Peta OpenStreetMap memuat tile peta berdasarkan area yang ditampilkan. '
        'Jika Anda membuka rute di aplikasi peta eksternal, alamat atau '
        'koordinat tujuan dikirim ke penyedia peta tersebut dan tunduk pada '
        'kebijakan privasi penyedia terkait.',
  ),
  _LegalSection(
    '6. Masa penyimpanan',
    'Data disimpan selama diperlukan untuk memberikan layanan, melakukan '
        'tindak lanjut, dan memenuhi ketentuan penyimpanan arsip yang '
        'berlaku. Jangka waktu rinci mengikuti kebijakan retensi resmi '
        'pengelola layanan.',
  ),
  _LegalSection(
    '7. Keamanan dan pilihan pengguna',
    'Pengelola menerapkan upaya perlindungan yang wajar, namun pengiriman '
        'data melalui internet tidak dapat dijamin bebas dari seluruh risiko. '
        'Anda dapat mengatur izin lokasi melalui pengaturan perangkat. Untuk '
        'meminta akses, koreksi, atau penghapusan data, hubungi UPTD '
        'Puskesmas Sumbersari melalui kanal resminya; permintaan diproses '
        'sesuai kebutuhan layanan dan ketentuan yang berlaku.',
  ),
];

class RegisterView extends StatefulWidget {
  const RegisterView({super.key, this.apiService});

  final ApiService? apiService;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordObscured = true;
  bool _confirmationObscured = true;
  bool _termsAccepted = false;
  bool _showTermsError = false;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;
  final Map<String, String> _serverErrors = {};
  late final ApiService _apiService = widget.apiService ?? ApiService();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _requiredValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kolom ini wajib diisi.';
    }
    return null;
  }

  String? _validateName(String? value) {
    final serverError = _serverErrors['name'];
    if (serverError != null) return serverError;
    final requiredError = _requiredValue(value);
    if (requiredError != null) return 'Nama lengkap wajib diisi.';
    if (value!.trim().runes.length < 2) {
      return 'Nama lengkap minimal 2 karakter.';
    }
    if (!RegExp(r'^[\p{L} ]+$', unicode: true).hasMatch(value.trim())) {
      return 'Nama lengkap hanya boleh berisi huruf dan spasi.';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    final serverError = _serverErrors['username'];
    if (serverError != null) return serverError;
    final requiredError = _requiredValue(value);
    if (requiredError != null) return 'Username wajib diisi.';
    final username = value!.trim();
    if (username.length < 3 || username.length > 30) {
      return 'Username harus terdiri dari 3–30 karakter.';
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(username)) {
      return 'Gunakan huruf, angka, titik, garis bawah, atau tanda hubung.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final serverError = _serverErrors['email'];
    if (serverError != null) return serverError;
    if (value == null || value.trim().isEmpty) {
      return 'Email wajib diisi.';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim())) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final serverError = _serverErrors['password'];
    if (serverError != null) return serverError;
    final requiredError = _requiredValue(value);
    if (requiredError != null) return requiredError;
    if (value!.length < 8) return 'Kata sandi minimal 8 karakter.';
    if (utf8.encode(value).length > 72) {
      return 'Kata sandi terlalu panjang (maksimal 72 byte).';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final serverError = _serverErrors['phone'];
    if (serverError != null) return serverError;
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Nomor telepon wajib diisi.';
    final compact = _normalizePhone(phone);
    return RegExp(r'^(?:08[0-9]{8,11}|628[0-9]{8,11})$').hasMatch(compact)
        ? null
        : 'Gunakan format nomor Indonesia: 08... atau +62 8...';
  }

  String? _validateConfirmation(String? value) {
    final serverError = _serverErrors['confirmation'];
    if (serverError != null) return serverError;
    final requiredError = _requiredValue(value);
    if (requiredError != null) {
      return requiredError;
    }
    if (value != _passwordController.text) {
      return 'Kata sandi tidak cocok.';
    }
    return null;
  }

  String _normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s()-]'), '');

  String? _registrationField(String backendField) {
    final field = backendField.toLowerCase().split('.').first;
    return switch (field) {
      'nama_lengkap' || 'name' || 'full_name' => 'name',
      'username' => 'username',
      'email' => 'email',
      'no_telepon' ||
      'no_hp' ||
      'no_wa' ||
      'phone' ||
      'phone_number' => 'phone',
      'password' => 'password',
      'password_confirmation' => 'confirmation',
      _ => null,
    };
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field)) return;
    setState(() => _serverErrors.remove(field));
  }

  void _showApiError(ApiException error) {
    final mappedErrors = <String, String>{};
    var hasUnmappedErrors = false;
    for (final entry in error.fieldErrors.entries) {
      final field = _registrationField(entry.key);
      if (field == null) {
        hasUnmappedErrors = true;
      } else {
        mappedErrors.putIfAbsent(field, () => entry.value);
      }
    }

    if (mappedErrors.isNotEmpty) {
      setState(() => _serverErrors.addAll(mappedErrors));
      _formKey.currentState?.validate();
    }
    if (mappedErrors.isEmpty || hasUnmappedErrors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _hasAttemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await _apiService.register(
        namaLengkap: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim().toLowerCase(),
        phone: _normalizePhone(_phoneController.text),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final token = result['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException('Token registrasi tidak diterima server.');
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'token': token, 'user': result['user']},
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showApiError(error);
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pendaftaran gagal diproses. Silakan coba lagi. $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showLegalNotice(String title) {
    final sections = title == 'Kebijakan Privasi'
        ? _privacySections
        : _termsSections;
    showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.65;
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: const Key('register_legal_notice_draft'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'DRAF: perlu ditinjau dan disahkan pengelola sebelum '
                      'diberlakukan.',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final section in sections) ...[
                    Text(
                      section.heading,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      section.body,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      content: Form(
        key: _formKey,
        autovalidateMode: _hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buat Akun',
              style: const TextStyle(
                fontFamily: AppTheme.headlineFontFamily,
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w400,
              ).asHeading,
            ),
            const SizedBox(height: 5),
            const Text(
              'Daftarkan akun Anda untuk menggunakan layanan Sanitasi Air',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 19),
            AuthFormField(
              fieldKey: const Key('register_name_field'),
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap',
              icon: Icons.person_outline,
              controller: _nameController,
              validator: _validateName,
              onChanged: (_) => _clearServerError('name'),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              fieldKey: const Key('register_username_field'),
              label: 'Username',
              hint: '3–30 karakter',
              icon: Icons.alternate_email,
              controller: _usernameController,
              validator: _validateUsername,
              onChanged: (_) => _clearServerError('username'),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              fieldKey: const Key('register_email_field'),
              label: 'Email',
              hint: 'Masukkan email',
              icon: Icons.mail_outline,
              controller: _emailController,
              validator: _validateEmail,
              onChanged: (_) => _clearServerError('email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              fieldKey: const Key('register_phone_field'),
              label: 'Nomor Telepon',
              hint: 'Contoh: 081234567890 atau +62 812 3456 7890',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              validator: _validatePhone,
              onChanged: (_) => _clearServerError('phone'),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              fieldKey: const Key('register_password_field'),
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              icon: Icons.lock_outline,
              controller: _passwordController,
              validator: _validatePassword,
              onChanged: (_) => _clearServerError('password'),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _passwordObscured,
              onToggleVisibility: () =>
                  setState(() => _passwordObscured = !_passwordObscured),
            ),
            const SizedBox(height: 13),
            AuthFormField(
              fieldKey: const Key('register_confirmation_field'),
              label: 'Konfirmasi Kata Sandi',
              hint: 'Masukkan kembali kata sandi',
              icon: Icons.shield_outlined,
              controller: _confirmationController,
              validator: _validateConfirmation,
              onChanged: (_) => _clearServerError('confirmation'),
              textInputAction: TextInputAction.done,
              obscureText: _confirmationObscured,
              onToggleVisibility: () => setState(
                () => _confirmationObscured = !_confirmationObscured,
              ),
            ),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: _termsAccepted,
                    activeColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) => setState(() {
                      _termsAccepted = value ?? false;
                      _showTermsError = false;
                    }),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Saya menyetujui ',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        _LegalLink(
                          label: 'Syarat & Ketentuan',
                          onTap: () => _showLegalNotice('Syarat & Ketentuan'),
                        ),
                        const Text(
                          ' dan ',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        _LegalLink(
                          label: 'Kebijakan Privasi',
                          onTap: () => _showLegalNotice('Kebijakan Privasi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_showTermsError)
              const Padding(
                padding: EdgeInsets.only(left: 35, top: 2),
                child: Text(
                  'Persetujuan wajib diberikan untuk mendaftar.',
                  style: TextStyle(color: Color(0xFFB3261E), fontSize: 11),
                ),
              ),
            const SizedBox(height: 14),
            AuthPrimaryButton(
              label: _isSubmitting ? 'Memproses...' : 'Daftar',
              icon: _isSubmitting ? Icons.hourglass_top : Icons.arrow_forward,
              onPressed: () {
                if (!_isSubmitting) _submit();
              },
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sudah memiliki akun?',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const AuthCopyright(),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
