import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;

  LayoutNotifier(this._prefs) {
    _isXbox = _prefs.getBool('isXbox') ?? true;
    _leftZone = _prefs.getStringList('leftZone') ?? ['l_stick', 'dpad'];
    _rightZone = _prefs.getStringList('rightZone') ?? ['buttons', 'r_stick'];

    // Parse visibility settings
    final visList = _prefs.getStringList('visibility') ?? [];
    if (visList.isNotEmpty) {
      for (var item in visList) {
        final parts = item.split(':');
        if (parts.length == 2) {
          _visibility[parts[0]] = parts[1] == 'true';
        }
      }
    }
  }

  late bool _isXbox;
  late List<String> _leftZone;
  late List<String> _rightZone;
  final Map<String, bool> _visibility = {
    'dpad': true, 'l_stick': true, 'buttons': true, 'r_stick': true,
    'lt': true, 'lb': true, 'rt': true, 'rb': true,
    'select': true, 'start': true
  };

  bool get isXbox => _isXbox;
  List<String> get leftZone => _leftZone;
  List<String> get rightZone => _rightZone;
  bool isVisible(String key) => _visibility[key] ?? true;

  void toggleLayout() {
    _isXbox = !_isXbox;
    _prefs.setBool('isXbox', _isXbox);
    notifyListeners();
  }

  void updateLeftZone(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _leftZone.removeAt(oldIndex);
    _leftZone.insert(newIndex, item);
    _prefs.setStringList('leftZone', _leftZone);
    notifyListeners();
  }

  void updateRightZone(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _rightZone.removeAt(oldIndex);
    _rightZone.insert(newIndex, item);
    _prefs.setStringList('rightZone', _rightZone);
    notifyListeners();
  }

  void toggleVisibility(String key) {
    _visibility[key] = !(_visibility[key] ?? true);
    _prefs.setStringList(
        'visibility',
        _visibility.entries.map((e) => '${e.key}:${e.value}').toList()
    );
    notifyListeners();
  }
}