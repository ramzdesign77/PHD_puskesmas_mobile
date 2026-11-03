import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';

class ProfilePageHeader extends StatelessWidget {
  const ProfilePageHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Kembali',
            onPressed: onBack,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.line),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.headlineFontFamily,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.bytes,
    this.size = 56,
  });

  final String name;
  final Uint8List? bytes;
  final double size;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+'));
    final letters = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.characters.first)
        .join();
    return letters.isEmpty ? 'KS' : letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.line),
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
          ),
          child: bytes == null
              ? initials
              : Image.memory(
                  bytes!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class ProfileSettingsRow extends StatelessWidget {
  const ProfileSettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.primary),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.ink),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileSettingsGroup extends StatelessWidget {
  const ProfileSettingsGroup({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 9),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.headlineFontFamily,
                color: AppColors.muted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ProfileCard(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 50,
                      color: AppColors.line,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
