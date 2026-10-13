import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'auth_components.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _passwordObscured = true;
  bool _confirmationObscured = true;
  bool _termsAccepted = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email wajib diisi.';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(value.trim())) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    final requiredError = _requiredValue(value);
    if (requiredError != null) {
      return requiredError;
    }
    if (value != _passwordController.text) {
      return 'Kata sandi tidak cocok.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    showAuthBackendUnavailable(context);
  }

  void _showLegalNotice(String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Dokumen ini belum tersedia di aplikasi. Silakan hubungi UPTD '
          'Puskesmas Sumbersari untuk informasi lebih lanjut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageScaffold(
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buat Akun',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
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
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap',
              icon: Icons.person_outline,
              controller: _nameController,
              validator: _requiredValue,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              label: 'Username',
              hint: 'Masukkan username',
              icon: Icons.alternate_email,
              controller: _usernameController,
              validator: _requiredValue,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              label: 'Email',
              hint: 'Masukkan email',
              icon: Icons.mail_outline,
              controller: _emailController,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 13),
            AuthFormField(
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              icon: Icons.lock_outline,
              controller: _passwordController,
              validator: _requiredValue,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _passwordObscured,
              onToggleVisibility: () =>
                  setState(() => _passwordObscured = !_passwordObscured),
            ),
            const SizedBox(height: 13),
            AuthFormField(
              label: 'Konfirmasi Kata Sandi',
              hint: 'Masukkan kembali kata sandi',
              icon: Icons.shield_outlined,
              controller: _confirmationController,
              validator: _validateConfirmation,
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
              label: 'Daftar',
              icon: Icons.arrow_forward,
              onPressed: _submit,
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
