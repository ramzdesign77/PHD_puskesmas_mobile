import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/profile_service.dart';
import 'change_password_view.dart';
import 'edit_profile_view.dart';
import 'profile_widgets.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    required this.fallbackName,
    required this.roleLabel,
    required this.onBack,
    required this.onLogout,
    this.isLoggingOut = false,
    this.onProfileChanged,
    this.accountDetails = const {},
    this.logoutKey,
    this.profileService,
  });

  final String fallbackName;
  final String roleLabel;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final bool isLoggingOut;
  final ValueChanged<LocalProfile>? onProfileChanged;
  final Map<String, String> accountDetails;
  final Key? logoutKey;
  final ProfileService? profileService;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final _profileService = widget.profileService ?? ProfileService();
  late Future<LocalProfile> _profile;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _profile = _profileService.load(fallbackName: widget.fallbackName);
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fallbackName != widget.fallbackName) _reload();
  }

  Future<void> _edit(LocalProfile profile) async {
    final updated = await Navigator.of(context).push<LocalProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileView(profile: profile, profileService: _profileService),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _profile = Future.value(updated);
    });
    widget.onProfileChanged?.call(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil disimpan di perangkat ini.')),
    );
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePasswordView(profileService: _profileService),
      ),
    );
    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password berhasil diperbarui.')),
    );
  }

  void _showDetails(String title, Map<String, String> details) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              for (final detail in details.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.key,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        detail.value.trim().isEmpty
                            ? 'Belum tersedia'
                            : detail.value,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<LocalProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Profil belum dapat dimuat.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(_reload),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                key: const Key('profile_settings_scroll'),
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                children: [
                  ProfilePageHeader(title: 'Pengaturan', onBack: widget.onBack),
                  const SizedBox(height: 10),
                  ProfileCard(
                    child: InkWell(
                      key: const Key('profile_edit_button'),
                      onTap: () => _edit(profile),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            ProfileAvatar(
                              name: profile.name,
                              bytes: profile.avatarBytes,
                              size: 58,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.username.isEmpty
                                        ? widget.roleLabel
                                        : '@${profile.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ProfileSettingsGroup(
                    label: 'Akun',
                    children: [
                      ProfileSettingsRow(
                        key: const Key('profile_change_password_button'),
                        icon: Icons.lock_outline_rounded,
                        label: 'Ganti password',
                        onTap: _changePassword,
                      ),
                      ProfileSettingsRow(
                        icon: Icons.badge_outlined,
                        label: 'Informasi akun',
                        onTap: () => _showDetails('Informasi akun', {
                          'Peran akun': widget.roleLabel,
                          'Nama profil di perangkat': profile.name,
                          'Email': profile.email,
                          'Nomor telepon': profile.phone,
                          ...widget.accountDetails,
                        }),
                      ),
                    ],
                  ),
                  const ProfileSettingsGroup(
                    label: 'Preferensi',
                    children: [
                      ProfileSettingsRow(
                        icon: Icons.palette_outlined,
                        label: 'Tampilan',
                        value: 'Biru laut',
                      ),
                      ProfileSettingsRow(
                        icon: Icons.translate_rounded,
                        label: 'Bahasa',
                        value: 'Indonesia',
                      ),
                    ],
                  ),
                  ProfileSettingsGroup(
                    label: 'Bantuan & informasi',
                    children: [
                      ProfileSettingsRow(
                        icon: Icons.help_outline_rounded,
                        label: 'Pusat bantuan',
                        onTap: () => _showDetails('Pusat bantuan', {
                          if (widget.accountDetails.isEmpty) ...{
                            'Bagaimana membuat laporan?':
                                'Buka menu Lapor, lengkapi identitas dan lokasi, '
                                'lalu ceritakan masalah sanitasi yang ditemukan.',
                            'Bagaimana melihat perkembangan laporan?':
                                'Buka menu Lacak dan masukkan kode tiket. '
                                'Saran petugas akan muncul setelah laporan selesai.',
                          } else ...{
                            'Di mana melihat tugas?':
                                'Buka Tugas Aduan untuk melihat dan memverifikasi '
                                'laporan yang masuk.',
                            'Bagaimana mengisi inspeksi?':
                                'Buka Input IKL, pilih kunjungan, lalu isi '
                                'indikator, intervensi, dan rekomendasi.',
                          },
                          'Bagaimana mengubah data akun?':
                              'Pilih Ganti password pada menu Akun untuk '
                              'mengubah password. Untuk mengubah data akun '
                              'lainnya, hubungi petugas pengelola aplikasi di '
                              'puskesmas.',
                        }),
                      ),
                      ProfileSettingsRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Tentang aplikasi',
                        onTap: () => _showDetails('E-Klinik Sanitasi', const {
                          'Layanan sanitasi dalam genggaman':
                              'Aplikasi pelaporan masalah sanitasi, pelacakan '
                              'tindak lanjut, dan inspeksi lapangan oleh petugas.',
                          'Versi aplikasi': '1.0.0',
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  OutlinedButton.icon(
                    key: widget.logoutKey,
                    onPressed: widget.isLoggingOut ? null : widget.onLogout,
                    icon: widget.isLoggingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded, size: 19),
                    label: Text(
                      widget.isLoggingOut ? 'Memproses...' : 'Keluar',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.line),
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'E-Klinik Sanitasi · Versi 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
