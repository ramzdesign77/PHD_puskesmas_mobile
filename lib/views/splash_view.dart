import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'auth_components.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final Timer _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(const Duration(milliseconds: 1500), _openLogin);
  }

  void _openLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _navigationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: authSoftBackground,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.health_and_safety_outlined,
                            color: AppColors.primary,
                            size: 62,
                          ),
                        ),
                      ),
                      const SizedBox(height: 23),
                      Text(
                        'E-Klinik Sanitasi',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primaryDark,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Sanitasi Air • UPTD Puskesmas Sumbersari',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    children: [
                      Text(
                        'UPTD Puskesmas Sumbersari © 2026',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Surveilans Kesehatan Lingkungan Terpadu',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.muted.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
