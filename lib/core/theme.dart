import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Lisätään Google Fonts

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Colors.blueGrey[800],
      scaffoldBackgroundColor: const Color(0xFFFFFCF5), // Valkoisempi kelta-oranssi
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: Colors.blueGrey,
        unselectedItemColor: Colors.grey,
        elevation: 0,
      ),
      textTheme: TextTheme(
        // Otsikot (esim. "Historia" HistoryScreenillä)
        headlineSmall: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        // Leipäteksti (esim. budjettikategoriat, tapahtumien kuvaukset)
        bodyLarge: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.black54,
        ),
        // Pienet tekstit (esim. päivämäärät, pudotusvalikot)
        bodySmall: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Colors.grey[500],
        ),
        // Otsikkoteksti (esim. AppBar-otsikot, kuten "Budu")
        titleLarge: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blueGrey[800]!, width: 2),
        ),
      ),
    );
  }
}