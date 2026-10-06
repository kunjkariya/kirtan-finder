import 'package:flutter/material.dart';

/// AppTheme provides a classic, timeless monochrome black/white/grey aesthetic.
/// Inspired by Apple-like simplicity, typography-focused clarity, and calm reading.
/// NO orange. NO brown. NO bright accent colors.
class AppTheme {
  // Monochrome Light Palette
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F6F8);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE5E5EA);
  static const Color lightTextPrimary = Color(0xFF111111);
  static const Color lightTextSecondary = Color(0xFF6E6E73);
  static const Color lightTextTertiary = Color(0xFF8E8E93);

  // Monochrome Dark Palette
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF141416);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF8E8E93);
  static const Color darkTextTertiary = Color(0xFF636366);

  // Highlights
  static const Color highlightBgLight = Color(0xFFE5E5EA);
  static const Color highlightTextLight = Color(0xFF000000);
  static const Color highlightBgDark = Color(0xFF38383A);
  static const Color highlightTextDark = Color(0xFFFFFFFF);

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF000000),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF3A3A3C),
      onSecondary: Color(0xFFFFFFFF),
      surface: lightBackground,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightSurface,
      onSurfaceVariant: lightTextSecondary,
      outline: lightBorder,
      outlineVariant: Color(0xFFE5E5EA),
      error: Color(0xFFD32F2F),
      onError: Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightBackground,
        indicatorColor: const Color(0xFFE5E5EA),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? lightTextPrimary : lightTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? lightTextPrimary : lightTextSecondary,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFD1D1D6),
      onSecondary: Color(0xFF000000),
      surface: darkBackground,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSurface,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: Color(0xFF2C2C2E),
      error: Color(0xFFCF6679),
      onError: Color(0xFF000000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        indicatorColor: const Color(0xFF2C2C2E),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? darkTextPrimary : darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? darkTextPrimary : darkTextSecondary,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}
