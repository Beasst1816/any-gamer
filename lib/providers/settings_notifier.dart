import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _sensitivityKey = 'sensitivity';
  static const String _deadzoneKey = 'deadzone';
  static const String _vibrationKey = 'vibration';
  static const String _userScaleKey = 'userScale';

  static const double _defaultSensitivity = 75.0;
  static const double _defaultDeadzone = 12.0;
  static const bool _defaultVibration = true;
  static const double _defaultUserScale = 1.0;

  late SharedPreferences _prefs;
  late double _sensitivity;
  late double _deadzone;
  late bool _vibration;
  late double _userScale;

  SettingsNotifier(SharedPreferences prefs) {
    _prefs = prefs;
    _loadFromPreferences();
  }

  void _loadFromPreferences() {
    _sensitivity = _prefs.getDouble(_sensitivityKey) ?? _defaultSensitivity;
    _deadzone = _prefs.getDouble(_deadzoneKey) ?? _defaultDeadzone;
    _vibration = _prefs.getBool(_vibrationKey) ?? _defaultVibration;
    _userScale = _prefs.getDouble(_userScaleKey) ?? _defaultUserScale;
  }

  double get sensitivity => _sensitivity;
  double get deadzone => _deadzone;
  bool get vibration => _vibration;
  double get userScale => _userScale;

  Future<void> setSensitivity(double val) async {
    _sensitivity = val;
    try {
      await _prefs.setDouble(_sensitivityKey, val);
    } catch (e) {
      print('Error persisting sensitivity: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setDeadzone(double val) async {
    _deadzone = val;
    try {
      await _prefs.setDouble(_deadzoneKey, val);
    } catch (e) {
      print('Error persisting deadzone: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setVibration(bool val) async {
    _vibration = val;
    try {
      await _prefs.setBool(_vibrationKey, val);
    } catch (e) {
      print('Error persisting vibration: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setUserScale(double val) async {
    _userScale = val;
    try {
      await _prefs.setDouble(_userScaleKey, val);
    } catch (e) {
      print('Error persisting user scale: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> reset() async {
    _sensitivity = _defaultSensitivity;
    _deadzone = _defaultDeadzone;
    _vibration = _defaultVibration;
    _userScale = _defaultUserScale;

    try {
      await _prefs.setDouble(_sensitivityKey, _defaultSensitivity);
      await _prefs.setDouble(_deadzoneKey, _defaultDeadzone);
      await _prefs.setBool(_vibrationKey, _defaultVibration);
      await _prefs.setDouble(_userScaleKey, _defaultUserScale);
    } catch (e) {
      print('Error resetting settings: $e');
      rethrow;
    }
    notifyListeners();
  }
}