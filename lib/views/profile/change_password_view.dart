import 'dart:convert';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/profile_service.dart';
import 'profile_widgets.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key, required this.profileService});

  final ProfileService profileService;

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSaving = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    try {
      await widget.profileService.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ProfileException
                  ? error.message
                  : 'Password gagal diperbarui. Coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  ProfilePageHeader(
                    title: 'Ganti Password',
                    onBack: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Masukkan password lama, lalu buat password baru minimal '
                    '8 karakter. Setelah berhasil, sesi mobile lainnya akan keluar.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Form(
                    key: _formKey,
                    child: ProfileCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _passwordField(
                              fieldKey: const Key(
                                'profile_current_password_field',
                              ),
                              label: 'Password lama',
                              controller: _currentPassword,
                              obscureText: _obscureCurrentPassword,
                              onToggleVisibility: () => setState(
                                () => _obscureCurrentPassword =
                                    !_obscureCurrentPassword,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Password lama perlu diisi.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _passwordField(
                              fieldKey: const Key('profile_new_password_field'),
                              label: 'Password baru',
                              controller: _newPassword,
                              obscureText: _obscureNewPassword,
                              onToggleVisibility: () => setState(
                                () =>
                                    _obscureNewPassword = !_obscureNewPassword,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password baru perlu diisi.';
                                }
                                if (value.length < 8) {
                                  return 'Password minimal 8 karakter.';
                                }
                                if (utf8.encode(value).length > 72) {
                                  return 'Password terlalu panjang (maksimal 72 byte).';
                                }
                                if (value == _currentPassword.text) {
                                  return 'Password baru harus berbeda dari password lama.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _passwordField(
                              fieldKey: const Key(
                                'profile_password_confirmation_field',
                              ),
                              label: 'Konfirmasi password baru',
                              controller: _confirmation,
                              obscureText: _obscureConfirmation,
                              onToggleVisibility: () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                              validator: (value) => value != _newPassword.text
                                  ? 'Konfirmasi password belum sama.'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('profile_change_password_save_button'),
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan password baru'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      enabled: !_isSaving,
      obscureText: obscureText,
      validator: validator,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Tampilkan password' : 'Sembunyikan password',
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
