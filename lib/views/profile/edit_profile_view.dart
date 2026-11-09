import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../services/profile_service.dart';
import 'profile_widgets.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({
    super.key,
    required this.profile,
    required this.profileService,
    this.openPhotoPickerOnStart = false,
  });

  final LocalProfile profile;
  final ProfileService profileService;
  final bool openPhotoPickerOnStart;

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.name);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _username = TextEditingController(text: widget.profile.username);
  late Uint8List? _avatar = widget.profile.avatarBytes;
  late String? _avatarUrl = widget.profile.avatarUrl;
  String? _avatarFileName;
  bool _removeAvatar = false;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  @override
  void initState() {
    super.initState();
    if (widget.openPhotoPickerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _changePhoto();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Foto profil', style: TextStyle(fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (_avatar != null || (_avatarUrl?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Hapus foto profil'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == 'remove') {
      setState(() {
        _avatar = null;
        _avatarUrl = null;
        _avatarFileName = null;
        _removeAvatar = true;
      });
      return;
    }
    setState(() => _isPickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        _showError('Pilih foto berukuran maksimal 5 MB.');
        return;
      }
      setState(() {
        _avatar = bytes;
        _avatarFileName = photo.name;
        _removeAvatar = false;
      });
    } catch (_) {
      if (mounted) {
        _showError('Foto belum dapat dibuka. Periksa izin kamera atau galeri.');
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_isSaving || _isPickingPhoto || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);
    final updated = widget.profile.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      username: _username.text.trim().replaceFirst(RegExp(r'^@'), ''),
      avatarBytes: _avatar,
      avatarFileName: _avatarFileName,
      clearAvatar: _removeAvatar,
    );
    try {
      final saved = await widget.profileService.save(updated);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        _showError(
          error is ProfileException
              ? error.message
              : 'Profil gagal disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                    title: 'Edit Profil',
                    onBack: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ProfileAvatar(
                          name: widget.profile.name,
                          bytes: _avatar,
                          url: _avatarUrl,
                          size: 112,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: IconButton.filled(
                            tooltip: 'Ubah foto profil',
                            onPressed: _isSaving || _isPickingPhoto
                                ? null
                                : _changePhoto,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.canvas,
                                width: 3,
                              ),
                            ),
                            icon: _isPickingPhoto
                                ? const SizedBox(
                                    height: 19,
                                    width: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Foto profil Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 30),
                  Form(
                    key: _formKey,
                    child: ProfileCard(
                      child: Column(
                        children: [
                          _ProfileField(
                            fieldKey: const Key('profile_name_field'),
                            label: 'Nama lengkap',
                            hint: 'Nama Anda',
                            controller: _name,
                            enabled: !_isSaving,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Nama perlu diisi.'
                                : null,
                          ),
                          const _FieldDivider(),
                          _ProfileField(
                            fieldKey: const Key('profile_phone_field'),
                            label: 'Nomor telepon',
                            hint: '08xxxxxxxxxx',
                            controller: _phone,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) return null;
                              final compact = phone.replaceAll(
                                RegExp(r'[\s()-]'),
                                '',
                              );
                              return RegExp(r'^\+?[0-9]{8,15}$')
                                      .hasMatch(compact)
                                  ? null
                                  : 'Nomor telepon tidak valid.';
                            },
                          ),
                          const _FieldDivider(),
                          _ProfileField(
                            fieldKey: const Key('profile_email_field'),
                            label: 'Email',
                            hint: 'nama@email.com',
                            controller: _email,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Email wajib diisi.';
                              return email.length <= 255 &&
                                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                          .hasMatch(email)
                                  ? null
                                  : 'Alamat email tidak valid.';
                            },
                          ),
                          const _FieldDivider(),
                          _ProfileField(
                            fieldKey: const Key('profile_username_field'),
                            label: 'Nama pengguna',
                            hint: '@username',
                            controller: _username,
                            enabled: !_isSaving,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                            validator: (value) {
                              final username =
                                  value?.trim().replaceFirst(
                                    RegExp(r'^@'),
                                    '',
                                  ) ??
                                  '';
                              return RegExp(r'^[a-zA-Z0-9_-]{3,50}$')
                                      .hasMatch(username)
                                  ? null
                                  : 'Gunakan 3–50 karakter: huruf, angka, - atau _.';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('profile_save_button'),
                    onPressed: _isSaving || _isPickingPhoto ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Simpan Perubahan'),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Perubahan profil dan foto disimpan pada akun Anda. '
                      'Gunakan email atau nama pengguna terbaru saat login berikutnya.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.7,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    thickness: 1,
    indent: 16,
    endIndent: 16,
    color: AppColors.line,
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    this.keyboardType,
    this.autofillHints,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(13) > 18;
        final labelWidget = Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        );
        final field = TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          textAlign: stacked ? TextAlign.start : TextAlign.end,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorMaxLines: 3,
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelWidget, field],
                )
              : Row(
                  children: [
                    SizedBox(width: 108, child: labelWidget),
                    const SizedBox(width: 8),
                    Expanded(child: field),
                  ],
                ),
        );
      },
    );
  }
}
