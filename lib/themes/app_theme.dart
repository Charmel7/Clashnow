import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      // 🎯 CONSERVER LES COULEURS EXISTANTES MAIS AUGMENTER LES CONTRASTES
      primaryColor: Colors.blueGrey[900], // Plus foncé pour meilleur contraste
      colorScheme: ColorScheme.light(
        primary: Colors.blueGrey[900]!,
        secondary: Colors.orange[700]!,
        background: Colors.grey[100]!,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),

      // 🎯 GARDER SOURCE CODE PRO MAIS AJUSTER LES POIDS
      fontFamily: 'SourceCodePro',

      textTheme: TextTheme(
        // TITRES TRÈS VISIBLES (projection)
        headlineLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 32,
          fontWeight: FontWeight.w700, // Semi-bold pour Source Code Pro
          color: Colors.blueGrey[900],
          letterSpacing: 1.0, // Augmenter l'espacement pour lisibilité
        ),
        headlineMedium: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey[900],
          letterSpacing: 0.8,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey[900],
          letterSpacing: 0.5,
        ),

        // CORPS DE TEXTE RENFORCÉ
        bodyLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 18,
          fontWeight: FontWeight.w500, // Medium au lieu de regular
          color: Colors.grey[900], // Plus foncé
          height: 1.5, // Meilleur interligne
        ),
        bodyMedium: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.grey[700],
        ),

        // LABELS TRÈS GRAS
        labelLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 18,
          fontWeight: FontWeight.w700, // Bold
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        labelMedium: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.8,
        ),

        // TITRES APP BAR
        titleLarge: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.8,
        ),
      ),

      // 🎯 BOUTONS PLUS CONTRASTÉS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[900],
          foregroundColor: Colors.white,
          textStyle: TextStyle(
            fontFamily: 'SourceCodePro',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ), // Plus grand
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 4, // Ombre plus prononcée
        ),
      ),

      // 🎯 APP BAR PLUS CONTRASTÉ
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blueGrey[900],
        titleTextStyle: TextStyle(
          fontFamily: 'SourceCodePro',
          fontSize: 22, // Légèrement plus grand
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        elevation: 6, // Plus d'ombre pour la profondeur
      ),

      // 🎯 CARTES AVEC BORDURES PRONONCÉES
      cardTheme: CardThemeData(
        elevation: 4,
        margin: EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ), // Bordure visible
        ),
      ),

      // 🎯CHAMPS FORMULAIRES PLUS VISIBLES
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[400]!, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blueGrey[900]!, width: 2.5),
        ),
        labelStyle: TextStyle(
          fontFamily: 'SourceCodePro',
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
