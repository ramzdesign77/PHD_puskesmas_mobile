import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'auth_components.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordObscured = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _requiredValue(String? value) {
    if (value == null || value.trim().isEmpty) return 'Kolom ini wajib diisi.';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    showAuthBackendUnavailable(context);
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
              'Masuk ke Akun',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Portal Resmi E-Klinik Sanitasi Puskesmas',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 22),
            AuthFormField(
              label: 'Username atau Email',
              hint: 'Masukkan username atau email',
              icon: Icons.person_outline,
              controller: _usernameController,
              validator: _requiredValue,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
            ),
            const SizedBox(height: 15),
            AuthFormField(
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              icon: Icons.lock_outline,
              controller: _passwordController,
              validator: _requiredValue,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              obscureText: _passwordObscured,
              onToggleVisibility: () =>
                  setState(() => _passwordObscured = !_passwordObscured),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Login',
              icon: Icons.arrow_forward,
              onPressed: _submit,
            ),
            const SizedBox(height: 21),
            const Divider(color: Color(0xFFF1E9E7), height: 1),
            const SizedBox(height: 17),
            const AuthSecurityNote(),
            const SizedBox(height: 13),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Belum punya akun?',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/register'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Daftar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const AuthCopyright(),
          ],
        ),
      ),
    );
  }
}
