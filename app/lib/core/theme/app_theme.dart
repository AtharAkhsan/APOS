import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Material 3 theme for the Toempah Rempah app based on "The Artisanal Interface"
class AppTheme {
  AppTheme._();

  // ── Brand Palette (From General Ledger Design System) ──────────────────
  static const Color primary = Color(0xFF361F1A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF4E342E);
  static const Color onPrimaryContainer = Color(0xFFC19C94);

  static const Color secondary = Color(0xFF655D5A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFECE0DC);
  static const Color onSecondaryContainer = Color(0xFF6B6360);

  static const Color tertiary = Color(0xFF142919);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF293F2D);
  static const Color onTertiaryContainer = Color(0xFF92AA93);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color background = Color(0xFFFBFBE2);
  static const Color onBackground = Color(0xFF1B1D0E);
  static const Color surface = Color(0xFFFBFBE2);
  static const Color onSurface = Color(0xFF1B1D0E);

  static const Color surfaceVariant = Color(0xFFE4E4CC);
  static const Color onSurfaceVariant = Color(0xFF504442);
  static const Color outline = Color(0xFF827471);
  static const Color outlineVariant = Color(0xFFD4C3BF);

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
  );

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.manrope(fontSize: 57, fontWeight: FontWeight.normal),
      displayMedium: GoogleFonts.manrope(fontSize: 45, fontWeight: FontWeight.normal),
      displaySmall: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.normal),
      headlineLarge: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.normal),
      headlineMedium: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.normal),
      headlineSmall: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.normal),
      titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal),
      bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      brightness: Brightness.light,
      textTheme: _buildTextTheme(),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        foregroundColor: onBackground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFE4E4CC), // surface_container_highest
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1), // "ghost border fallback" style
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFFE4E4CC), // surface_container_highest
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))), // md corners
        margin: EdgeInsets.all(8),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), // xl for primary buttons
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF5F5DC), // _kSurfaceLow
        indicatorColor: primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: onPrimary, size: 22);
          }
          return const IconThemeData(color: onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: primary);
          }
          return GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: onSurfaceVariant);
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFFF5F5DC), // _kSurfaceLow
        indicatorColor: primary,
        selectedIconTheme: const IconThemeData(color: onPrimary, size: 22),
        unselectedIconTheme: const IconThemeData(color: onSurfaceVariant, size: 22),
        selectedLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
        unselectedLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: onSurfaceVariant),
      ),
    );
  }

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF0BD8B),
    onPrimary: Color(0xFF482904),
    primaryContainer: Color(0xFF311900),
    onPrimaryContainer: Color(0xFFAA7E51),
    secondary: Color(0xFFDDC0BB),
    onSecondary: Color(0xFF3E2C29),
    secondaryContainer: Color(0xFF5B4743),
    onSecondaryContainer: Color(0xFFD1B6B1),
    tertiary: Color(0xFFCEC5BB),
    onTertiary: Color(0xFF353028),
    tertiaryContainer: Color(0xFF221E17),
    onTertiaryContainer: Color(0xFF8D857C),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF191210),
    onSurface: Color(0xFFF0DFDB),
    surfaceContainerHighest: Color(0xFF3D3230),
    onSurfaceVariant: Color(0xFFD2C3C0),
    outline: Color(0xFF9B8E8B),
    outlineVariant: Color(0xFF4F4442),
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      brightness: Brightness.dark,
      textTheme: _buildTextTheme().apply(
        bodyColor: const Color(0xFFF0DFDB),
        displayColor: const Color(0xFFF0DFDB),
      ),
      scaffoldBackgroundColor: const Color(0xFF191210),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF191210),
        foregroundColor: Color(0xFFF0DFDB),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF3D3230),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0BD8B), width: 1),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF221A17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFD4A373),
        contentTextStyle: GoogleFonts.inter(color: const Color(0xFF2C1600), fontWeight: FontWeight.w500),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0BD8B),
          foregroundColor: const Color(0xFF482904),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF191210),
        indicatorColor: const Color(0xFFF0BD8B),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF482904), size: 22);
          }
          return const IconThemeData(color: Color(0xFFD2C3C0), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF0BD8B));
          }
          return GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFFD2C3C0));
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF191210),
        indicatorColor: const Color(0xFFF0BD8B),
        selectedIconTheme: const IconThemeData(color: Color(0xFF482904), size: 22),
        unselectedIconTheme: const IconThemeData(color: Color(0xFFD2C3C0), size: 22),
        selectedLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFF0BD8B)),
        unselectedLabelTextStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFD2C3C0)),
      ),
    );
  }
}

extension CustomThemeExtension on ThemeData {
  Color get surfaceLow => brightness == Brightness.light ? const Color(0xFFF5F5DC) : const Color(0xFF221A17);
  Color get surfaceHighest => brightness == Brightness.light ? const Color(0xFFE4E4CC) : const Color(0xFF3D3230);
  Color get surfaceDim => brightness == Brightness.light ? const Color(0xFFDBDCC3) : const Color(0xFF191210);
  Color get cardWhite => brightness == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF261E1B);
  Color get tertiaryFixedDim => brightness == Brightness.light ? const Color(0xFFB4CDB5) : const Color(0xFFCEC5BB);
  Color get onTertiaryFixed => brightness == Brightness.light ? const Color(0xFF0A2010) : const Color(0xFF1F1B14);
  Color get outlineVariantCustom => brightness == Brightness.light ? const Color(0xFFD4C3BF) : const Color(0xFF4F4442);

  // Accent button color for FABs (Add Product, Add Expense)
  Color get accentButton => brightness == Brightness.light ? const Color(0xFF361F1A) : const Color(0xFFD4A373);
  Color get onAccentButton => brightness == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF2C1600);

  // Stock badge colors
  Color get stockInBg => brightness == Brightness.light ? const Color(0xFFE8F5E9) : const Color(0xFF1B3A1E);
  Color get stockInFg => brightness == Brightness.light ? const Color(0xFF2E7D32) : const Color(0xFF81C784);
  Color get stockLowBg => brightness == Brightness.light ? const Color(0xFFFFECB3) : const Color(0xFF3E2E10);
  Color get stockLowFg => brightness == Brightness.light ? const Color(0xFF8D6E00) : const Color(0xFFFFD54F);
}

extension BuildContextThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
}
