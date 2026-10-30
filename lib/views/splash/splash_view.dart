import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/officer_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocean_widgets.dart';
import '../auth/auth_components.dart';
import '../auth/login_view.dart';
import '../officer/officer_dashboard_view.dart';
import '../public/main_shell.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key, this.apiService, this.authService});

  final ApiService? apiService;
  final AuthService? authService;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  late final ApiService _apiService = widget.apiService ?? ApiService();
  late final AuthService _authService = widget.authService ?? AuthService();
  String? _storageError;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _resolveStartupRoute();
  }

  Future<void> _resolveStartupRoute() async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
      _storageError = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final session = await _apiService.loadSavedSession();
      if (!mounted) return;

      final destination = session == null
          ? LoginView(authService: _authService)
          : ApiService.isOfficerRole(session.role)
          ? OfficerDashboardView(
              token: session.token,
              officerName: session.userName.isEmpty
                  ? 'Petugas'
                  : session.userName,
              apiService: OfficerApiService(),
            )
          : MainShell(apiService: _apiService, authService: _authService);
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute<void>(builder: (_) => destination));
    } catch (_) {
      if (mounted) {
        setState(() {
          _storageError =
              'Sesi tidak dapat diperiksa. Coba lagi untuk membuka aplikasi.';
        });
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_storageError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _storageError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isResolving ? null : _resolveStartupRoute,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DynamicWaterHeader(height: 210, child: SizedBox.expand()),
          ),
          SafeArea(
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
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
                              color: AppColors.primaryDark,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ).asHeading,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Sanitasi Air • UPTD Puskesmas Sumbersari',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
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
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Surveilans Kesehatan Lingkungan Terpadu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFontFamily,
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
        ],
      ),
    );
  }
}
