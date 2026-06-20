import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

class DPadWidget extends StatefulWidget {
  final double size;
  final void Function(String id, bool isPressed) onSignal;

  const DPadWidget({
    super.key,
    required this.size,
    required this.onSignal,
  });

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  // We use a ValueNotifier to isolate repaints to just the D-Pad graphics
  late final ValueNotifier<Set<String>> _activeDirections;

  // Tracks touches by pointer ID to support strict multitouch
  final Map<int, Set<String>> _pointers = {};

  @override
  void initState() {
    super.initState();
    _activeDirections = ValueNotifier<Set<String>>({});
  }

  @override
  void dispose() {
    _activeDirections.dispose();
    super.dispose();
  }

  void _updatePointers(int pointerId, Offset localPosition, bool isDown) {
    if (isDown) {
      _pointers[pointerId] = DPadHitTester.evaluate(localPosition, widget.size);
    } else {
      _pointers.remove(pointerId);
    }
    _recalculateOverallState();
  }

  void _recalculateOverallState() {
    final Set<String> newActive = {};
    for (final dirs in _pointers.values) {
      newActive.addAll(dirs);
    }

    final oldActive = _activeDirections.value;
    final added = newActive.difference(oldActive);
    final removed = oldActive.difference(newActive);

    // If new directions were triggered, fire haptics
    if (added.isNotEmpty) {
      HapticFeedback.lightImpact();
    }

    // Fire network signals
    for (final dir in added) {
      widget.onSignal(dir, true);
    }
    for (final dir in removed) {
      widget.onSignal(dir, false);
    }

    _activeDirections.value = newActive;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final accent = theme.accentColor;

    return Listener(
      onPointerDown: (e) => _updatePointers(e.pointer, e.localPosition, true),
      onPointerMove: (e) => _updatePointers(e.pointer, e.localPosition, true),
      onPointerUp: (e) => _updatePointers(e.pointer, e.localPosition, false),
      onPointerCancel: (e) => _updatePointers(e.pointer, e.localPosition, false),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: _activeDirections,
          builder: (context, activeDirs, child) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: _DPadPainter(
                  activeDirections: activeDirs,
                  accentColor: accent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Hit Testing Math
// -----------------------------------------------------------------------------

class DPadHitTester {
  static const String up = 'BTN_DPAD_UP';
  static const String down = 'BTN_DPAD_DOWN';
  static const String left = 'BTN_DPAD_LEFT';
  static const String right = 'BTN_DPAD_RIGHT';

  static Set<String> evaluate(Offset localPosition, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Deadzone in the exact center (15% of radius)
    final deadzone = (size / 2) * 0.15;
    if (distance < deadzone) return {};

    // Calculate angle from -pi to pi
    final angle = math.atan2(dy, dx);
    final degree = angle * 180 / math.pi;

    // Shift by 22.5 degrees to cleanly align 45-degree sectors
    double adjusted = degree + 22.5;
    if (adjusted < 0) adjusted += 360;

    // 0 = Right, 1 = Down-Right, 2 = Down, 3 = Down-Left, etc.
    final sector = (adjusted / 45).floor() % 8;

    switch (sector) {
      case 0: return {right};
      case 1: return {right, down};
      case 2: return {down};
      case 3: return {down, left};
      case 4: return {left};
      case 5: return {left, up};
      case 6: return {up};
      case 7: return {up, right};
      default: return {};
    }
  }
}

// -----------------------------------------------------------------------------
// Custom Painter Graphics
// -----------------------------------------------------------------------------

class _DPadPainter extends CustomPainter {
  final Set<String> activeDirections;
  final Color accentColor;

  _DPadPainter({
    required this.activeDirections,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double thirdW = w / 3;
    final double thirdH = h / 3;
    final double radius = w * 0.04; // Rounded corners

    // 1. Construct the Cross Shape
    final Path verticalRect = Path()..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(thirdW, 0, thirdW, h), Radius.circular(radius)),
    );
    final Path horizontalRect = Path()..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, thirdH, w, thirdH), Radius.circular(radius)),
    );
    final Path dpadShape = Path.combine(PathOperation.union, verticalRect, horizontalRect);

    // 2. Draw Base Fill
    final paintFill = Paint()
      ..color = AppTheme.kHudSurface
      ..style = PaintingStyle.fill;
    canvas.drawPath(dpadShape, paintFill);

    // 3. Draw Active Glows (Per Arm)
    final paintGlow = Paint()
      ..color = accentColor.withAlpha(100)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    if (activeDirections.contains(DPadHitTester.up)) {
      canvas.drawRect(Rect.fromLTWH(thirdW, 0, thirdW, thirdH), paintGlow);
    }
    if (activeDirections.contains(DPadHitTester.down)) {
      canvas.drawRect(Rect.fromLTWH(thirdW, 2 * thirdH, thirdW, thirdH), paintGlow);
    }
    if (activeDirections.contains(DPadHitTester.left)) {
      canvas.drawRect(Rect.fromLTWH(0, thirdH, thirdW, thirdH), paintGlow);
    }
    if (activeDirections.contains(DPadHitTester.right)) {
      canvas.drawRect(Rect.fromLTWH(2 * thirdW, thirdH, thirdW, thirdH), paintGlow);
    }

    // 4. Draw Border
    final bool isAnyActive = activeDirections.isNotEmpty;
    final paintBorder = Paint()
      ..color = isAnyActive ? accentColor : AppTheme.kHudBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(dpadShape, paintBorder);

    // 5. Draw Directional Arrows (Triangles)
    _drawArrow(canvas, Offset(w / 2, h * 0.12), 0, activeDirections.contains(DPadHitTester.up), w * 0.08); // Up
    _drawArrow(canvas, Offset(w / 2, h * 0.88), math.pi, activeDirections.contains(DPadHitTester.down), w * 0.08); // Down
    _drawArrow(canvas, Offset(w * 0.12, h / 2), -math.pi / 2, activeDirections.contains(DPadHitTester.left), w * 0.08); // Left
    _drawArrow(canvas, Offset(w * 0.88, h / 2), math.pi / 2, activeDirections.contains(DPadHitTester.right), w * 0.08); // Right
  }

  void _drawArrow(Canvas canvas, Offset center, double angle, bool isActive, double size) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final Path arrowPath = Path()
      ..moveTo(0, -size / 2)
      ..lineTo(-size / 2, size / 2)
      ..lineTo(size / 2, size / 2)
      ..close();

    final paint = Paint()
      ..color = isActive ? accentColor : AppTheme.kTextSecondary.withAlpha(80)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DPadPainter oldDelegate) {
    return oldDelegate.activeDirections != activeDirections ||
        oldDelegate.accentColor != accentColor;
  }
}