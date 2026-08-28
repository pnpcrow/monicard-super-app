import 'package:flutter/material.dart';

class McColors {
  static const bg = Color(0xFF080A10);
  static const panel = Color(0xFF141821);
  static const panel2 = Color(0xFF1B202B);
  static const text = Color(0xFFF7F8FB);
  static const muted = Color(0xFF9DA6B5);
  static const accent = Color(0xFFF3EB28);
  static const danger = Color(0xFFFF6472);
  static const line = Color(0xFF29303D);
  static const ok = Color(0xFF64DF80);
  static const ink = Color(0xFF12141A);
}

ThemeData buildMoniCardTheme() {
  const scheme = ColorScheme.dark(
    surface: McColors.panel,
    primary: McColors.accent,
    onPrimary: McColors.ink,
    onSurface: McColors.text,
    error: McColors.danger,
    secondary: McColors.panel2,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: McColors.bg,
    fontFamily: 'sans-serif',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: McColors.text,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: McColors.text,
      contentTextStyle: const TextStyle(color: McColors.ink, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: McColors.accent,
        foregroundColor: McColors.ink,
        elevation: 0,
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: McColors.text,
        side: const BorderSide(color: McColors.line),
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0B0E14),
      hintStyle: const TextStyle(color: McColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: McColors.accent, width: 1.4),
      ),
    ),
  );
}
