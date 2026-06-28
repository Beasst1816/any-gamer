// lib/widgets/camera_scroll_area.dart
//
// Mouse-like camera control zone — maps swipe DELTA (not absolute position)
// to RS_X / RS_Y axis values. This is how PUBG Mobile / COD Mobile implement
// their right-side look control. Unlike ThumbstickWidget, there is:
//   • No center point to find
//   • No radius boundary
//   • No dead zone (any touch movement registers immediately)
//   • No inertia on lift (camera stops dead — precision > feel)
//   • Only ONE pointer can own the zone at a time (multi-touch safe)
//   • Zero new pub.dev dependencies (pure Flutter + dart:math)
//
// Z-order rule: always add this as the FIRST child in the parent Stack so
// buttons/sticks (later children = higher Z) absorb their own touches first.
// The camera zone only receives pointers that land in genuinely empty space.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class CameraScrollArea extends StatefulWidget {
  /// Fires with 'RS_X' or 'RS_Y' — identical signature to ThumbstickWidget.onAxis.
  final void Function(String id, double value) onAxis;

  /// Sensitivity multiplier passed in from SettingsNotifier via parent layout.
  /// 1.0  → swipe 20% of zone width  = full axis deflection (±1.0)
  /// 2.0  → swipe 10% of zone width  = full axis deflection
  /// 0.5  → swipe 40% of zone width  = full axis deflection
  final double cameraSensitivity;

  const CameraScrollArea({
    super.key,
    required this.onAxis,
    this.cameraSensitivity = 1.5,
  });

  @override
  State<CameraScrollArea> createState() => _CameraScrollAreaState();
}

class _CameraScrollAreaState extends State<CameraScrollArea> {
  // ── Pointer ownership ────────────────────────────────────────────────────
  // One pointer owns the camera zone. Any subsequent finger is ignored.
  int? _activePointer;
  double _lastX = 0.0;
  double _lastY = 0.0;

  // ── Visual state (ValueNotifier bypasses setState — same pattern as
  //    ThumbstickWidget._knobOffset) ────────────────────────────────────────
  final ValueNotifier<Offset?> _touchPoint = ValueNotifier(null);
  final ValueNotifier<bool> _isActive = ValueNotifier(false);

  // ── De-duplicate: only send when value changes ────────────────────────────
  double _lastSentX = 0.0;
  double _lastSentY = 0.0;

  // ── Zone dimensions, set in build() so painter can use them ──────────────
  double _zoneWidth = 1.0;

  @override
  void dispose() {
    // Send zeros on unmount so the host doesn't receive a stuck RS value.
    // Safe to call widget.onAxis here because dispose() runs before the
    // parent widget tree tears down its callbacks.
    if (_activePointer != null) {
      if (_lastSentX != 0.0) widget.onAxis('RS_X', 0.0);
      if (_lastSentY != 0.0) widget.onAxis('RS_Y', 0.0);
    }
    _touchPoint.dispose();
    _isActive.dispose();
    super.dispose();
  }

  // ── Input handlers ────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    // Reject if this zone is already owned — second finger is ignored.
    if (_activePointer != null) return;

    _activePointer = e.pointer;
    _lastX = e.localPosition.dx;
    _lastY = e.localPosition.dy;

    _touchPoint.value = e.localPosition;
    _isActive.value = true;

    // Subtle haptic confirms zone activation (same as ThumbstickWidget L3 tap).
    HapticFeedback.selectionClick();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;

    final double deltaX = e.localPosition.dx - _lastX;
    final double deltaY = e.localPosition.dy - _lastY;

    // Update anchor for NEXT frame — this is the key delta-not-absolute step.
    _lastX = e.localPosition.dx;
    _lastY = e.localPosition.dy;

    // ── Sensitivity formula ─────────────────────────────────────────────────
    // pixelsForFull = how many pixels of swipe produces axis value 1.0.
    // Lower pixelsForFull = more sensitive (larger axis output per pixel).
    //
    // At cameraSensitivity = 1.0: need to swipe (zoneWidth * 0.20) px → ±1.0
    // At cameraSensitivity = 2.0: need to swipe (zoneWidth * 0.10) px → ±1.0
    // At cameraSensitivity = 0.5: need to swipe (zoneWidth * 0.40) px → ±1.0
    final double pixelsForFull =
        (_zoneWidth * 0.20) / widget.cameraSensitivity.clamp(0.1, 10.0);

    // Normalize to [-1.0, 1.0]. No deadzone — precision requires zero lag.
    final double normX = (deltaX / pixelsForFull).clamp(-1.0, 1.0);
    final double normY = (deltaY / pixelsForFull).clamp(-1.0, 1.0);

    // Only send if value changed — prevents redundant TCP/BT packets.
    if (normX != _lastSentX) {
      widget.onAxis('RS_X', normX);
      _lastSentX = normX;
    }
    if (normY != _lastSentY) {
      widget.onAxis('RS_Y', normY);
      _lastSentY = normY;
    }

    // Update dot position for painter.
    _touchPoint.value = e.localPosition;
  }

  void _onPointerUp(PointerEvent e) {
    if (e.pointer != _activePointer) return;
    _releaseZone();
  }

  void _releaseZone() {
    _activePointer = null;
    _touchPoint.value = null;
    _isActive.value = false;

    // Explicitly stop camera rotation. Only send if we were actually moving.
    if (_lastSentX != 0.0) {
      widget.onAxis('RS_X', 0.0);
      _lastSentX = 0.0;
    }
    if (_lastSentY != 0.0) {
      widget.onAxis('RS_Y', 0.0);
      _lastSentY = 0.0;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _zoneWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 1.0;

        return Listener(
          // Default HitTestBehavior.deferToChild: only fires if the SizedBox
          // below is actually hit. Widgets later in the parent Stack (higher Z)
          // absorb their own touches first — this zone only gets empty-space taps.
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          child: RepaintBoundary(
            // RepaintBoundary is mandatory: the touch-dot repaints frequently.
            // Without it, the whole HUD would repaint on every pointer move.
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CustomPaint(
                painter: _CameraZonePainter(
                  touchPoint: _touchPoint,
                  isActive: _isActive,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter — visual only, zero game logic
// Repaints ONLY when touchPoint or isActive changes (Listenable.merge pattern,
// identical to ThumbstickWidget._ThumbstickPainter).
// ─────────────────────────────────────────────────────────────────────────────

class _CameraZonePainter extends CustomPainter {
  final ValueNotifier<Offset?> touchPoint;
  final ValueNotifier<bool> isActive;

  _CameraZonePainter({required this.touchPoint, required this.isActive})
    : super(repaint: Listenable.merge([touchPoint, isActive]));

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bool active = isActive.value;
    final Offset? touch = touchPoint.value;

    // 1. Zone border — barely visible, consistent with glassmorphism HUD.
    //    Brightens slightly when active to give feedback the zone is captured.
    final borderPaint = Paint()
      ..color = AppTheme.kHudBorder.withAlpha(active ? 55 : 20)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // 2. Idle hint — shown only when no finger is touching.
    if (!active) {
      _paintIdleHint(canvas, center);
    }

    // 3. Touch indicator dot — shown at current finger position when active.
    if (active && touch != null) {
      _paintTouchDot(canvas, touch);
    }
  }

  /// Draws a minimal "swipe to look" indicator in the zone center.
  void _paintIdleHint(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = AppTheme.kTextSecondary.withAlpha(28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double arrowLen = 16.0;
    const double headLen = 5.0;
    final double y = center.dy;

    // ← left arrow
    final double lStart = center.dx - 10;
    canvas.drawLine(Offset(lStart, y), Offset(lStart - arrowLen, y), paint);
    canvas.drawLine(
      Offset(lStart - arrowLen, y),
      Offset(lStart - arrowLen + headLen, y - headLen),
      paint,
    );
    canvas.drawLine(
      Offset(lStart - arrowLen, y),
      Offset(lStart - arrowLen + headLen, y + headLen),
      paint,
    );

    // → right arrow
    final double rStart = center.dx + 10;
    canvas.drawLine(Offset(rStart, y), Offset(rStart + arrowLen, y), paint);
    canvas.drawLine(
      Offset(rStart + arrowLen, y),
      Offset(rStart + arrowLen - headLen, y - headLen),
      paint,
    );
    canvas.drawLine(
      Offset(rStart + arrowLen, y),
      Offset(rStart + arrowLen - headLen, y + headLen),
      paint,
    );

    // "LOOK" text label below the arrows.
    final tp = TextPainter(
      text: TextSpan(
        text: 'LOOK',
        style: TextStyle(
          color: AppTheme.kTextSecondary.withAlpha(30),
          fontSize: 9.5,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + 16));
  }

  /// Draws a subtle glowing dot at the active touch point.
  /// Gives the user visual confirmation of which finger owns the zone.
  void _paintTouchDot(Canvas canvas, Offset touch) {
    // Soft glow halo
    canvas.drawCircle(
      touch,
      20,
      Paint()
        ..color = AppTheme.kHudBorder.withAlpha(40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill,
    );
    // Solid center dot
    canvas.drawCircle(
      touch,
      4,
      Paint()
        ..color = AppTheme.kTextSecondary.withAlpha(90)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraZonePainter oldDelegate) => false;
  // Repaints are driven by Listenable.merge([touchPoint, isActive]) above.
  // shouldRepaint returning false is CORRECT here — do not change this.
}
