import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B4A3A),
        brightness: Brightness.light,
        primary: const Color(0xFF0B4A3A),
        onPrimary: Colors.white,
        surface: const Color(0xFFF9F7F1), // Màu nền chính (như cũ)
        onSurface: const Color(0xFF1E1E1E), // Text chính
        secondaryContainer: Colors.white, // Màu Card
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F7F1),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF1E1E1E)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1E1E1E),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFEEEEEE), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEEEEE),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF0B4A3A),
        textColor: Color(0xFF1E1E1E),
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0B4A3A),
        brightness: Brightness.dark,
        primary: const Color(
          0xFF16A085,
        ), // Màu xanh sáng hơn chút cho dark mode
        onPrimary: Colors.white,
        surface: const Color(0xFF121212), // Nền dark
        onSurface: const Color(0xFFE0E0E0), // Text dark
        secondaryContainer: const Color(0xFF1E1E1E), // Card dark
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE0E0E0)),
        titleTextStyle: TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF2C2C2C), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2C2C2C),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFF16A085),
        textColor: Color(0xFFE0E0E0),
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}
