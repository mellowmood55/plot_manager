import 'package:flutter/material.dart';

class AppTheme {
  // Light mode - Primary accent (warm light brown)
  static const Color primaryColor = Color(0xFFB8956A);

  // Dark mode - Primary accent (warm gold/amber for visibility on dark)
  static const Color darkPrimaryColor = Color(0xFFD4A574);

  // Secondary & tertiary accent colors for charts and highlights
  static const Color secondaryAccent = Color(0xFF7A5634); // Deep cocoa brown
  static const Color tertiaryAccent = Color(0xFFC47C3A); // Burnt caramel
  static const Color highlightAccent = Color(0xFFE3C9A3); // Warm sand

  // Chart colors - cream/brown palette with stronger separation
  static const Color chartColor1 = Color(0xFF9A744A); // Walnut tan
  static const Color chartColor2 = Color(0xFFC47C3A); // Burnt caramel
  static const Color chartColor3 = Color(0xFFE3C9A3); // Warm sand
  static const Color chartColor4 = Color(0xFF7A5634); // Deep cocoa

  // Dark mode (Midnight Slate)
  static const Color scaffoldBackground = Color(0xFF0F172A);
  static const Color darkSurfaceColor = Color(0xFF1E293B);
  static const Color darkCardBorder = Color(0xFF334155); // Slate border for dark cards

  // Shared light surface token used by most screens/cards.
  static const Color surfaceColor = Color(0xFFF8F1E7);

  // Light mode (Cream + Deep Slate)
  static const Color lightScaffoldBackground = Color(0xFFF7F1E8);
  static const Color lightSurfaceColor = Color(0xFFFDF7EF);
  static const Color lightTextColor = Color(0xFF1E293B);

  static const String appFontFamily = 'Comic Sans MS';

  static TextTheme _comicSansTextTheme(TextTheme base) {
    return base.apply(fontFamily: appFontFamily);
  }

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: appFontFamily,
    primaryColor: darkPrimaryColor,
    scaffoldBackgroundColor: scaffoldBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor,
      surface: darkSurfaceColor,
      background: scaffoldBackground,
    ),
    textTheme: _comicSansTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    iconTheme: const IconThemeData(size: 20),
    cardTheme: CardThemeData(
      color: darkSurfaceColor,
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: const BorderSide(color: darkCardBorder, width: 1.0),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: scaffoldBackground,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: darkSurfaceColor,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: darkCardBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: darkCardBorder, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: darkPrimaryColor,
          width: 2.0,
        ),
      ),
      hintStyle: TextStyle(
        color: Colors.grey[500],
        fontSize: 16.0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor,
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

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    fontFamily: appFontFamily,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightScaffoldBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: lightSurfaceColor,
      onSurface: lightTextColor,
      background: lightScaffoldBackground,
      onBackground: lightTextColor,
    ),
    textTheme: _comicSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(
      bodyColor: lightTextColor,
      displayColor: lightTextColor,
    ),
    iconTheme: const IconThemeData(size: 20, color: lightTextColor),
    cardTheme: CardThemeData(
      color: lightSurfaceColor,
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: const BorderSide(color: Color(0xFFD9CFC1), width: 1.2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightScaffoldBackground,
      foregroundColor: lightTextColor,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: const Color(0xFFF5EEDF),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFD9CFC1), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Color(0xFFD9CFC1), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.8,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF64748B),
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
