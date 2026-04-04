import 'package:flutter/material.dart';

/// Global app theme — brand red #CE181E with a modern, light Material 3 look.
class AppTheme {
  AppTheme._();

  // ─── Brand ───────────────────────────────────────────────────────────────
  static const Color primaryColor = Color(0xFFCE181E);
  static const Color primaryDark = Color(0xFFA81419);
  static const Color primaryLight = Color(0xFFE84248);

  /// Text & icons on top of solid [primaryColor] (buttons, avatars, chips).
  static const Color onPrimaryColor = Color(0xFFFFFFFF);

  /// Gold accent — pairs with brand red for highlights & secondary actions.
  static const Color accentColor = Color(0xFFC9A44A);
  static const Color onAccentColor = Color(0xFF1E1B16);

  // ─── Background ─────────────────────────────────────────────────────────
  static const Color backgroundColor = Color(0xFFF5F1F2);
  static const Color backgroundColorWarm = Color(0xFFFBF7F8);

  // ─── Containers (M3-style tints) ─────────────────────────────────────────
  static const Color primaryContainer = Color(0xFFFFE8E9);
  static const Color onPrimaryContainer = Color(0xFF5C1014);
  static const Color secondaryContainer = Color(0xFFF5ECD4);
  static const Color onSecondaryContainer = Color(0xFF3D3310);

  // ─── Surfaces ────────────────────────────────────────────────────────────
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFCFC);
  static const Color surfaceContainerHigh = Color(0xFFF0EAEC);

  // ─── Text ────────────────────────────────────────────────────────────────
  static const Color primaryTextColor = Color(0xFF1C1B1F);
  static const Color secondaryTextColor = Color(0xFF5C5658);
  static const Color hintTextColor = Color(0xFF8E8688);

  // ─── Buttons ─────────────────────────────────────────────────────────────
  static const Color buttonPrimaryColor = primaryColor;
  static const Color buttonPrimaryTextColor = onPrimaryColor;
  static const Color buttonInactiveColor = Color(0xFFD8D3D5);
  static const Color buttonInactiveTextColor = Color(0xFFFFFFFF);

  // ─── Inputs ──────────────────────────────────────────────────────────────
  static const Color inputBackgroundColor = Color(0xFFFFFFFF);
  static const Color inputBorderColor = Color(0xFFE5DEE0);

  // ─── Progress / States ───────────────────────────────────────────────────
  static const Color progressActiveColor = primaryColor;
  static const Color progressInactiveColor = Color(0xFFE3DCDE);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color errorColor = Color(0xFFC62828);

  // ─── Decorative ───────────────────────────────────────────────────────────
  static const Color shimmerHighlight = Color(0x22FFFFFF);
  static const Color outlineMuted = Color(0xFFCEC4C7);

  static const String? fontFamily = null;

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  /// Primary CTA + outline inputs (8dp) — shared corner radius.
  static const double radiusPrimaryButton = 8;

  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.light(
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: accentColor,
      onSecondary: onAccentColor,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      surface: surfaceColor,
      onSurface: primaryTextColor,
      onSurfaceVariant: secondaryTextColor,
      error: errorColor,
      onError: onPrimaryColor,
      outline: outlineMuted,
      outlineVariant: inputBorderColor,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: baseScheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: primaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          fontFamily: fontFamily,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.15,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.35,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          height: 1.45,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          color: primaryTextColor,
          fontSize: 14,
          fontWeight: FontWeight.normal,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          color: secondaryTextColor,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          height: 1.35,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          color: primaryTextColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          fontFamily: fontFamily,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonPrimaryColor,
          foregroundColor: buttonPrimaryTextColor,
          elevation: 0,
          shadowColor: primaryColor.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPrimaryButton),
          ),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            fontFamily: fontFamily,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonPrimaryColor,
          foregroundColor: buttonPrimaryTextColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPrimaryButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.25),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
            fontFamily: fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: inputBorderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: hintTextColor, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(onPrimaryColor),
        side: const BorderSide(color: outlineMuted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: inputBorderColor.withValues(alpha: 0.85),
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D2A2B),
        contentTextStyle: const TextStyle(
          color: Color(0xFFF5F5F5),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: progressInactiveColor,
        circularTrackColor: progressInactiveColor,
      ),
    );
  }
}
