import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTheme {
  // Base Colors
  static const Color kBackground = Color(0xFF0A0F1E);
  static const Color kHudSurface = Color(0xFF111827);
  static const Color kHudBorder = Color(0x2600C8FF); // rgba(0,200,255,0.15)
  static const Color kTextPrimary = Colors.white;
  static const Color kTextSecondary = Color(0x73FFFFFF); // rgba(255,255,255,0.45)

  // Xbox Face Button Colors
  static const Color kA = Color(0xFF22C55E);
  static const Color kB = Color(0xFFEF4444);
  static const Color kX = Color(0xFF3B82F6);
  static const Color kY = Color(0xFFEAB308);

  // PlayStation Face Button Colors
  static const Color kPS_Cross = Color(0xFF3B82F6);
  static const Color kPS_Circle = Color(0xFFEF4444);
  static const Color kPS_Square = Color(0xFFEC4899);
  static const Color kPS_Triangle = Color(0xFF22C55E);

  // Typography
  static TextStyle labelStyle(double size, {Color color = kTextPrimary, FontWeight weight = FontWeight.w600}) {
    try {
      return GoogleFonts.rajdhani(
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.2,
      );
    } catch (_) {
      // Fallback if GoogleFonts fails to load offline
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 1.2,
      );
    }
  }
}