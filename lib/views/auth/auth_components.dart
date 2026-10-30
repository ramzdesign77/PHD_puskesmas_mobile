import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ocean_widgets.dart';

const authSoftBackground = AppColors.canvas;

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({super.key, required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final headingNowTheme = baseTheme.textTheme.apply(
      fontFamily: AppTheme.bodyFontFamily,
    );
    final textTheme = headingNowTheme.copyWith(
      displayLarge: headingNowTheme.displayLarge?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
      displayMedium: headingNowTheme.displayMedium?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
      headlineLarge: headingNowTheme.headlineLarge?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
      headlineMedium: headingNowTheme.headlineMedium?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
      headlineSmall: headingNowTheme.headlineSmall?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
      titleLarge: headingNowTheme.titleLarge?.copyWith(
        fontFamily: AppTheme.headlineFontFamily,
      ),
    );

    return Theme(
      data: baseTheme.copyWith(
        textTheme: textTheme,
        primaryTextTheme: baseTheme.primaryTextTheme.apply(
          fontFamily: AppTheme.bodyFontFamily,
        ),
      ),
      child: Scaffold(
        backgroundColor: authSoftBackground,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      const AuthBrandHeader(),
                      Padding(
                        padding: const EdgeInsets.only(top: 206),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                            border: Border(
                              top: BorderSide(color: Colors.white70),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x140277BD),
                                blurRadius: 22,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicWaterHeader(
      height: 230,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _AuthContourPainter()),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(9),
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.health_and_safety_outlined,
                              color: AppColors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'E-Klinik Sanitasi Air',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.headlineFontFamily,
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ).asHeading,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'UPTD Puskesmas Sumbersari',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.84),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.onToggleVisibility,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 48,
            ),
            suffixIcon: onToggleVisibility == null
                ? null
                : IconButton(
                    tooltip: obscureText
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.muted,
                      size: 20,
                    ),
                  ),
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFB3261E)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFB3261E),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSecurityNote extends StatelessWidget {
  const AuthSecurityNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AppColors.green,
          size: 16,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Akses akun layanan resmi Puskesmas Sumbersari',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class AuthCopyright extends StatelessWidget {
  const AuthCopyright({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '© 2026 E-Klinik Sanitasi Puskesmas',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 10),
      ),
    );
  }
}

void showAuthBackendUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Autentikasi belum terhubung ke backend.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _AuthContourPainter extends CustomPainter {
  const _AuthContourPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < 7; index++) {
      final width = size.width * (0.62 + index * 0.17);
      final height = size.height * (0.55 + index * 0.16);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.88, size.height * 0.04),
          width: width,
          height: height,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuthContourPainter oldDelegate) => false;
}
