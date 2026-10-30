import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static const headlineFontFamily = 'Heading Now';
  static const bodyFontFamily = 'Heading Now';

  static TextTheme _headingNowTextTheme() {
    final baseTextTheme = ThemeData().textTheme;
    TextStyle? body(TextStyle? style) => style?.copyWith(
      fontFamily: bodyFontFamily,
      fontWeight: FontWeight.w400,
      height: 1.6,
      letterSpacing: (style.fontSize ?? 14) * 0.015,
    );
    TextStyle? heading(TextStyle? style) => style?.copyWith(
      fontFamily: headlineFontFamily,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -(style.fontSize ?? 14) * 0.01,
    );
    TextStyle? medium(TextStyle? style) => style?.copyWith(
      fontFamily: bodyFontFamily,
      fontWeight: FontWeight.w500,
      letterSpacing: (style.fontSize ?? 14) * 0.03,
    );

    return baseTextTheme.copyWith(
      displayLarge: heading(baseTextTheme.displayLarge),
      displayMedium: heading(baseTextTheme.displayMedium),
      displaySmall: heading(baseTextTheme.displaySmall),
      headlineLarge: heading(baseTextTheme.headlineLarge),
      headlineMedium: heading(baseTextTheme.headlineMedium),
      headlineSmall: heading(baseTextTheme.headlineSmall),
      titleLarge: heading(baseTextTheme.titleLarge),
      titleMedium: medium(baseTextTheme.titleMedium),
      titleSmall: medium(baseTextTheme.titleSmall),
      bodyLarge: body(baseTextTheme.bodyLarge),
      bodyMedium: body(baseTextTheme.bodyMedium),
      bodySmall: body(baseTextTheme.bodySmall),
      labelLarge: medium(baseTextTheme.labelLarge),
      labelMedium: medium(baseTextTheme.labelMedium),
      labelSmall: medium(baseTextTheme.labelSmall),
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    );
    final textTheme = _headingNowTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: bodyFontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.softBlue,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        indicatorColor: AppColors.softBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: bodyFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.33,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

extension HeadingNowTextStyle on TextStyle {
  TextStyle get asHeading => copyWith(
    fontFamily: AppTheme.headlineFontFamily,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -(fontSize ?? 14) * 0.01,
  );
}
