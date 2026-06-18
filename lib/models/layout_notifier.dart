import 'package:flutter/material.dart';

class LayoutNotifier extends ChangeNotifier {
  // We start with Xbox as the default layout
  bool _isXbox = true;

  bool get isXbox => _isXbox;

  void toggleLayout() {
    _isXbox = !_isXbox;
    notifyListeners(); // This tells the UI to instantly rebuild
  }
}