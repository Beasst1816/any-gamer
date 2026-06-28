import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;

  // --- 800x360 Viewport Bounds Verification (Logical Pixels) ---
  // Base Variables: w=800, h=360, userScale=1.0, baseUnit=360.
  //
  // Component Sizes:
  // LT/RT: 64 x 64.8   | LB/RB: 64 x 43.2
  // L/R_Stick: 144x144 | Dpad: 126x126
  // Buttons: 151.2 sq  | Center: 240x64.8
  //
  // Xbox Layout Bounding Boxes:
  // LT (0.17, 0.05)      => X:136.0 - 200.0, Y: 18.0 - 82.8
  // LB (0.25, 0.05)      => X:200.0 - 264.0, Y: 18.0 - 61.2
  // RT (0.60, 0.05)      => X:480.0 - 544.0, Y: 18.0 - 82.8
  // RB (0.68, 0.05)      => X:544.0 - 608.0, Y: 18.0 - 61.2
  // l_stick (0.05, 0.24) => X: 40.0 - 184.0, Y: 86.4 - 230.4  (Upper-left quadrant)
  // dpad (0.19, 0.65)    => X:152.0 - 278.0, Y:234.0 - 360.0  (Lower-left, below l_stick)
  // center (0.38, 0.75)  => X:304.0 - 544.0, Y:270.0 - 334.8  (Bottom middle, no X overlap)
  // r_stick (0.69, 0.60) => X:552.0 - 696.0, Y:216.0 - 360.0  (Lower-right, below buttons)
  // buttons (0.76, 0.18) => X:608.0 - 759.2, Y: 64.8 - 216.0  (Upper-right, touches edge of r_stick)
  //
  // PS Layout Bounding Boxes:
  // LT/LB/RT/RB          => (Identical mapping as Xbox)
  // dpad (0.05, 0.24)    => X: 40.0 - 166.0, Y: 86.4 - 212.4  (Upper-left quadrant)
  // l_stick (0.18, 0.60) => X:144.0 - 288.0, Y:216.0 - 360.0  (Lower-left, below dpad)
  // center (0.38, 0.75)  => X:304.0 - 544.0, Y:270.0 - 334.8  (Bottom middle)
  // r_stick (0.69, 0.60) => X:552.0 - 696.0, Y:216.0 - 360.0  (Symmetrical to l_stick)
  // buttons (0.76, 0.18) => X:608.0 - 759.2, Y: 64.8 - 216.0  (Symmetrical to dpad)

  static const Map<String, Offset> _xboxDefaults = {
    'lt': Offset(0.17, 0.05),
    'lb': Offset(0.25, 0.05),
    'rt': Offset(0.76, 0.05),
    'rb': Offset(0.68, 0.05),
    'l_stick': Offset(0.05, 0.24),
    'dpad': Offset(0.19, 0.65),
    'buttons': Offset(0.76, 0.18),
    'r_stick': Offset(0.69, 0.60),
    'center': Offset(0.38, 0.75),
  };

  static const Map<String, Offset> _psDefaults = {
    'lt': Offset(0.17, 0.05),
    'lb': Offset(0.25, 0.05),
    'rt': Offset(0.76, 0.05),
    'rb': Offset(0.68, 0.05),
    'l_stick': Offset(0.18, 0.60),
    'dpad': Offset(0.05, 0.24),
    'buttons': Offset(0.76, 0.18),
    'r_stick': Offset(0.69, 0.60),
    'center': Offset(0.38, 0.75),
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
    'camera_zone': false,
  };

  LayoutNotifier(this._prefs) {
    _isXbox = _prefs.getBool('isXbox') ?? true;
    _positions = _loadPositions();

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
    _prefs.setBool('isXbox', _isXbox);

    // Switch to the other layout's saved positions without erasing edits
    _positions = _loadPositions();
    notifyListeners();
  }

  void updatePosition(String key, Offset fractionOffset) {
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

  /// Restores the provided layout type to its exact factory defaults.
  void resetToDefault(bool isXboxLayout) {
    if (_isXbox == isXboxLayout) {
      // If the target layout is currently active, update memory and save immediately.
      _positions = Map.of(isXboxLayout ? _xboxDefaults : _psDefaults);
      _savePositions();
      notifyListeners();
    } else {
      // If the target layout is inactive, overwrite its disk records directly.
      final defaults = isXboxLayout ? _xboxDefaults : _psDefaults;
      final prefix = isXboxLayout ? 'xbox' : 'ps';
      for (final entry in defaults.entries) {
        _prefs.setDouble('pos_${prefix}_${entry.key}_x', entry.value.dx);
        _prefs.setDouble('pos_${prefix}_${entry.key}_y', entry.value.dy);
      }
    }
  }

  void toggleVisibility(String key) {
    _visibility[key] = !(_visibility[key] ?? true);
    _prefs.setStringList(
      'visibility',
      _visibility.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
    notifyListeners();
  }

  bool get isCameraMode => _visibility['camera_zone'] == true;
  void toggleCameraMode() {
  final bool turningOn = !isCameraMode;

  _visibility['camera_zone'] = turningOn;
  _visibility['r_stick'] = !turningOn; // exactly the opposite, always

  // Persist via existing serialisation path (same format as toggleVisibility).
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

  // Uses a layout-specific prefix to prevent Xbox edits from ruining the PS layout
  Map<String, Offset> _loadPositions() {
    final defaults = _isXbox ? _xboxDefaults : _psDefaults;
    final prefix = _isXbox ? 'xbox' : 'ps';
    final result = <String, Offset>{};

    for (final key in defaults.keys) {
      final x = _prefs.getDouble('pos_${prefix}_${key}_x') ?? defaults[key]!.dx;
      final y = _prefs.getDouble('pos_${prefix}_${key}_y') ?? defaults[key]!.dy;
      result[key] = Offset(x, y);
    }
    return result;
  }

  void _savePositions() {
    final prefix = _isXbox ? 'xbox' : 'ps';

    for (final entry in _positions.entries) {
      _prefs.setDouble('pos_${prefix}_${entry.key}_x', entry.value.dx);
      _prefs.setDouble('pos_${prefix}_${entry.key}_y', entry.value.dy);
    }
  }
}
