import 'package:flutter/material.dart';

class AppTheme {
  static const String fontFamily = 'DengXian'; // 等线字体

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: fontFamily,
      primaryColor: const Color(0xFF6366F1), // 主色调
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        primary: const Color(0xFF6366F1),
        secondary: const Color(0xFFEC4899), // ACG 粉色
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF6366F1),
        unselectedItemColor: Color(0xFF9CA3AF),
      ),
    );
  }
}
