import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;

  // Xbox defaults — (left_fraction, top_fraction) of each widget's top-left corner
  static const Map<String, Offset> _xboxDefaults = {
    'lt': Offset(0.15, 0.02),
    'lb': Offset(0.23, 0.02),
    'rt': Offset(0.61, 0.02),
    'rb': Offset(0.69, 0.02),
    'l_stick': Offset(0.05, 0.28),
    'dpad': Offset(0.18, 0.67),
    'buttons': Offset(0.53, 0.28),
    'r_stick': Offset(0.64, 0.67),
    'center': Offset(0.35, 0.72),
  };

  static const Map<String, Offset> _psDefaults = {
    'lt': Offset(0.15, 0.02),
    'lb': Offset(0.23, 0.02),
    'rt': Offset(0.61, 0.02),
    'rb': Offset(0.69, 0.02),
    'l_stick': Offset(0.18, 0.67), // PS: stick bottom-left
    'dpad': Offset(0.05, 0.28), // PS: dpad top-left
    'buttons': Offset(0.53, 0.28),
    'r_stick': Offset(0.64, 0.67),
    'center': Offset(0.35, 0.72),
  };

  late bool _isXbox;
  late Map<String, Offset> _positions;
  bool _isEditing = false;

  final Map<String, bool> _visibility = {
    'dpad': true,
    'l_stick': true,
    'buttons': true,
    'r_stick': true,
    'lt': true,
    'lb': true,
    'rt': true,
    'rb': true,
    'select': true,
    'start': true,
  };

  LayoutNotifier(this._prefs) {
    _isXbox = _prefs.getBool('isXbox') ?? true;
    _positions = _loadPositions();

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

  bool get isXbox => _isXbox;
  bool get isEditing => _isEditing;
  bool isVisible(String key) => _visibility[key] ?? true;

  Offset getPos(String key) =>
      _positions[key] ?? (_isXbox ? _xboxDefaults[key]! : _psDefaults[key]!);

  void toggleLayout() {
    _isXbox = !_isXbox;
    // Reset positions to canonical defaults for the new layout
    _positions = Map.of(_isXbox ? _xboxDefaults : _psDefaults);
    _savePositions();
    _prefs.setBool('isXbox', _isXbox);
    notifyListeners();
  }

  void updatePosition(String key, Offset fractionOffset) {
    // Clamp to prevent widgets from going off-screen
    _positions[key] = Offset(
      fractionOffset.dx.clamp(0.0, 0.9),
      fractionOffset.dy.clamp(0.0, 0.9),
    );
    _savePositions();
    notifyListeners();
  }

  void toggleEditing() {
    _isEditing = !_isEditing;
    notifyListeners();
  }

  void resetPositions() {
    _positions = Map.of(_isXbox ? _xboxDefaults : _psDefaults);
    _savePositions();
    notifyListeners();
  }

  void toggleVisibility(String key) {
    _visibility[key] = !(_visibility[key] ?? true);
    _prefs.setStringList(
      'visibility',
      _visibility.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
    notifyListeners();
  }

  void setEditing(bool val) {
    _isEditing = val;
    notifyListeners();
  }

  // Persist: store each key as 'pos_KEY_x' and 'pos_KEY_y'
  Map<String, Offset> _loadPositions() {
    final defaults = _isXbox ? _xboxDefaults : _psDefaults;
    final result = <String, Offset>{};
    for (final key in defaults.keys) {
      final x = _prefs.getDouble('pos_${key}_x') ?? defaults[key]!.dx;
      final y = _prefs.getDouble('pos_${key}_y') ?? defaults[key]!.dy;
      result[key] = Offset(x, y);
    }
    return result;
  }

  void _savePositions() {
    for (final entry in _positions.entries) {
      _prefs.setDouble('pos_${entry.key}_x', entry.value.dx);
      _prefs.setDouble('pos_${entry.key}_y', entry.value.dy);
    }
  }
}
