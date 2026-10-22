// lib/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static final Color primary = Color(0xFF1A73E8);
  static final Color secondary = Color(0xFF34A853);
  static final Color warning = Color(0xFFFFC107);
  static final Color error = Color(0xFFF44336);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Colors.white,
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF1A73E8),
      secondary: Color(0xFF34A853),
      error: Color(0xFFF44336),
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: Colors.grey),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF323232),
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: Color(0xFF1A73E8),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFF1A73E8)),
  );
}
