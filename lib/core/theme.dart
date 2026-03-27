import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0D9488); // Teal
  static const Color scaffoldBackground = Color(0xFF0F172A); // Midnight Slate
  static const Color surfaceColor = Color(0xFF1E293B); // Surface
  static const String appFontFamily = 'Comic Sans MS';

  static TextTheme _comicSansTextTheme(TextTheme base) {
    return base.apply(fontFamily: appFontFamily);
  }

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: appFontFamily,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: scaffoldBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      surface: surfaceColor,
      background: scaffoldBackground,
    ),
    textTheme: _comicSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldBackground,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: surfaceColor,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 2.0,
        ),
      ),
      hintStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 16.0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 12.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: appFontFamily),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: const TextStyle(fontFamily: appFontFamily),
      ),
    ),
  );
}
