import 'package:flutter/material.dart';

class AppTheme {
  static const String fontFamily = 'DengXian'; // 等线字体

  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: fontFamily,
<<<<<<< HEAD
      primaryColor: const Color(0xFFF8FAFC), // 主色调
=======
      primaryColor: const Color(0xFF6366F1), // 主色调
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366F1),
        primary: const Color(0xFF6366F1),
        secondary: const Color(0xFFEC4899), // ACG 粉色
      ),
<<<<<<< HEAD
      scaffoldBackgroundColor: Colors.grey[100],
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
=======
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
>>>>>>> 8c6d29c092719f5a7283fd71eb70ec81efa241e1
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