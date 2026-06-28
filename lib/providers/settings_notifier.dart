import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  static const String _sensitivityKey = 'sensitivity';
  static const String _deadzoneKey = 'deadzone';
  static const String _vibrationKey = 'vibration';
  static const String _userScaleKey = 'userScale';
  static const String _wifiHostKey = 'wifi_host';
  static const String _wifiPortKey = 'wifi_port';
  static const String _cameraSensKey = 'camera_sensitivity'; // ADD
  static const double _defaultCameraSens = 40.0;

  static const double _defaultSensitivity = 75.0;
  static const double _defaultDeadzone = 12.0;
  static const bool _defaultVibration = true;
  static const double _defaultUserScale = 1.0;
  static const String _defaultWifiHost = '192.168.1.100';
  static const int _defaultWifiPort = 5000;

  late SharedPreferences _prefs;
  late double _sensitivity;
  late double _deadzone;
  late bool _vibration;
  late double _userScale;
  late String _wifiHost;
  late int _wifiPort;
  late double _cameraSensitivity;

  SettingsNotifier(SharedPreferences prefs) {
    _prefs = prefs;
    _loadFromPreferences();
  }

  void _loadFromPreferences() {
    _sensitivity = _prefs.getDouble(_sensitivityKey) ?? _defaultSensitivity;
    _deadzone = _prefs.getDouble(_deadzoneKey) ?? _defaultDeadzone;
    _vibration = _prefs.getBool(_vibrationKey) ?? _defaultVibration;
    _userScale = _prefs.getDouble(_userScaleKey) ?? _defaultUserScale;
    _wifiHost = _prefs.getString(_wifiHostKey) ?? _defaultWifiHost;
    _wifiPort = _prefs.getInt(_wifiPortKey) ?? _defaultWifiPort;
    _cameraSensitivity = _prefs.getDouble(_cameraSensKey) ?? _defaultCameraSens;
  }

  double get sensitivity => _sensitivity;
  double get deadzone => _deadzone;
  bool get vibration => _vibration;
  double get userScale => _userScale;
  String get wifiHost => _wifiHost;
  int get wifiPort => _wifiPort;
  double get cameraSensitivity => _cameraSensitivity;

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

  Future<void> setWifiHost(String val) async {
    _wifiHost = val;
    try {
      await _prefs.setString(_wifiHostKey, val);
    } catch (e) {
      print('Error persisting wifi host: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setWifiPort(int val) async {
    _wifiPort = val;
    try {
      await _prefs.setInt(_wifiPortKey, val);
    } catch (e) {
      print('Error persisting wifi port: $e');
      rethrow;
    }
    notifyListeners();
  }

  Future<void> setCameraSensitivity(double val) async {
    // ADD
    _cameraSensitivity = val; // ADD
    try {
      // ADD
      await _prefs.setDouble(_cameraSensKey, val); // ADD
    } catch (e) {
      // ADD
      print('Error persisting camera sensitivity: $e'); // ADD
      rethrow; // ADD
    } // ADD
    notifyListeners(); // ADD
  }

  Future<void> reset() async {
    _sensitivity = _defaultSensitivity;
    _deadzone = _defaultDeadzone;
    _vibration = _defaultVibration;
    _userScale = _defaultUserScale;
    _wifiHost = _defaultWifiHost;
    _wifiPort = _defaultWifiPort;
    _cameraSensitivity = _defaultCameraSens; // ADD
    await _prefs.setDouble(_cameraSensKey, _defaultCameraSens);

    try {
      await _prefs.setDouble(_sensitivityKey, _defaultSensitivity);
      await _prefs.setDouble(_deadzoneKey, _defaultDeadzone);
      await _prefs.setBool(_vibrationKey, _defaultVibration);
      await _prefs.setDouble(_userScaleKey, _defaultUserScale);
      await _prefs.setString(_wifiHostKey, _defaultWifiHost);
      await _prefs.setInt(_wifiPortKey, _defaultWifiPort);
    } catch (e) {
      print('Error resetting settings: $e');
      rethrow;
    }
    notifyListeners();
  }
}
