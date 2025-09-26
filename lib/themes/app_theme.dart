// lib/themes/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Colors.blueGrey[800],
      colorScheme: ColorScheme.light(
        primary: Colors.blueGrey[800]!,
        secondary: Colors.orange[700]!,
        background: Colors.grey[100]!,
      ),
      fontFamily: 'SourceCodePro',

      // TEXT STYLES
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[900],
        ),
        headlineMedium: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[800],
        ),
        bodyLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 18,
          color: Colors.grey[800],
        ),
        bodyMedium: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 16,
          color: Colors.grey[700],
        ),
        labelLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // BOUTONS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontFamily: 'SourceCodePro',
            fontWeight: FontWeight.bold,
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // APP BAR
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blueGrey[800],
        titleTextStyle: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // CARTES
      cardTheme: CardThemeData(
        elevation: 2,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
