import 'package:flutter/material.dart';

class ThemeNotifier extends ChangeNotifier {
  // Available Accent Colors
  static const Color cyan = Color(0xFF00C8FF);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color green = Color(0xFF22C55E);
  static const Color orange = Color(0xFFF97316);
  static const Color red = Color(0xFFEF4444);

  final List<Color> accentOptions = [
    cyan,
    purple,
    green,
    orange,
    red,
  ];

  Color _accentColor = cyan;

  Color get accentColor => _accentColor;

  void setAccent(Color color) {
    if (_accentColor != color && accentOptions.contains(color)) {
      _accentColor = color;
      notifyListeners();
    }
  }
}