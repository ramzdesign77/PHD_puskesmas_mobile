import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'auth_components.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordObscured = true;
  bool _isSubmitting = false;
  late final AuthService _authService = widget.authService ?? AuthService();

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

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final user = await _authService.login(
        identifier: _usernameController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      final destination = _destinationFor(user);
      if (destination == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role akun tidak dikenali.')),
        );
        return;
      }
      Navigator.of(context)
          .pushNamedAndRemoveUntil(destination, (route) => false);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login gagal: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _destinationFor(UserModel user) {
    if (user.roles.contains('petugas') || user.roles.contains('admin')) {
      return '/dashboard-petugas';
    }
    if (user.roles.isNotEmpty && user.roles.every((role) => role == 'warga')) {
      return '/home';
    }
    return null;
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
              label: _isSubmitting ? 'Memproses...' : 'Login',
              icon: _isSubmitting ? Icons.hourglass_top : Icons.arrow_forward,
              onPressed: () {
                if (!_isSubmitting) _submit();
              },
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
