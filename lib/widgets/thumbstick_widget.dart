import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

class ThumbstickWidget extends StatefulWidget {
  final String axisX;
  final String axisY;
  final String l3ButtonId;
  final String label;
  final void Function(String id, double value) onAxis;
  final void Function(String id, bool pressed) onButton;
  final double deadzoneNormalized;
  final double sensitivityMultiplier;

  const ThumbstickWidget({
    super.key,
    required this.axisX,
    required this.axisY,
    required this.l3ButtonId,
    required this.label,
    required this.onAxis,
    required this.onButton,
    this.deadzoneNormalized = 0.08,
    this.sensitivityMultiplier = 1.0,
  });

  @override
  State<ThumbstickWidget> createState() => _ThumbstickWidgetState();
}

class _ThumbstickWidgetState extends State<ThumbstickWidget> with SingleTickerProviderStateMixin {
  // Ultra-fast state management bypassing setState()
  late final ValueNotifier<Offset> _knobOffset;
  late final ValueNotifier<Offset> _normalizedValues;
  late final ValueNotifier<bool> _isL3Pressed;

  // L3 Timing
  Timer? _l3Timer;

  // Return to center physics
  late final AnimationController _animController;
  Animation<Offset>? _returnAnim;

  // Tracking last sent to prevent network spam
  double _lastSentX = 0.0;
  double _lastSentY = 0.0;

  @override
  void initState() {
    super.initState();
    _knobOffset = ValueNotifier(Offset.zero);
    _normalizedValues = ValueNotifier(Offset.zero);
    _isL3Pressed = ValueNotifier(false);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _animController.addListener(() {
      if (_returnAnim != null) {
        _updateStickPhysics(_returnAnim!.value, 1.0); // maxRadius doesn't matter for 0,0
      }
    });
  }

  @override
  void dispose() {
    _l3Timer?.cancel();
    _animController.dispose();
    _knobOffset.dispose();
    _normalizedValues.dispose();
    _isL3Pressed.dispose();
    super.dispose();
  }

  void _updateStickPhysics(Offset localPosition, double maxRadius) {
    double dx = localPosition.dx;
    double dy = localPosition.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // 1. Clamp to max radius
    if (distance > maxRadius && maxRadius > 0) {
      final ratio = maxRadius / distance;
      dx *= ratio;
      dy *= ratio;
    }

    _knobOffset.value = Offset(dx, dy);

    // 2. Normalize (-1.0 to 1.0)
    double normX = maxRadius > 0 ? dx / maxRadius : 0.0;
    double normY = maxRadius > 0 ? dy / maxRadius : 0.0;

    // 3. Apply Deadzone (8%)
    final magnitude = math.sqrt(normX * normX + normY * normY);
    if (magnitude < widget.deadzoneNormalized) {
      normX = 0.0;
      normY = 0.0;
    } else {
      // Sensitivity: rescale the live range above the deadzone
      final rescale = (magnitude - widget.deadzoneNormalized)
          / (1.0 - widget.deadzoneNormalized);
      final boost = (rescale * widget.sensitivityMultiplier).clamp(0.0, 1.0);
      normX = (normX / magnitude) * boost;
      normY = (normY / magnitude) * boost;
    }

    _normalizedValues.value = Offset(normX, normY);

    // 4. Cancel L3 timer if thumb leaves deadzone
    if (magnitude >= widget.deadzoneNormalized && _l3Timer?.isActive == true) {
      _l3Timer?.cancel();
    }

    // 5. Fire Network Signals (only if changed)
    if (normX != _lastSentX) {
      widget.onAxis(widget.axisX, normX);
      _lastSentX = normX;
    }
    if (normY != _lastSentY) {
      widget.onAxis(widget.axisY, normY);
      _lastSentY = normY;
    }
  }

  void _handlePointerDown(PointerDownEvent e, double center, double maxRadius) {
    _animController.stop();

    // Shift coordinate system so center is (0,0)
    final localPosition = Offset(e.localPosition.dx - center, e.localPosition.dy - center);

    // Ignore touches outside the bounding box
    if (localPosition.distance > center) return;

    _updateStickPhysics(localPosition, maxRadius);

    // L3 Detection: start 180ms timer if inside deadzone
    if (localPosition.distance < (maxRadius * 0.08)) {
      _l3Timer = Timer(const Duration(milliseconds: 180), () {
        _isL3Pressed.value = true;
        widget.onButton(widget.l3ButtonId, true);
        HapticFeedback.lightImpact();
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent e, double center, double maxRadius) {
    final localPosition = Offset(e.localPosition.dx - center, e.localPosition.dy - center);
    _updateStickPhysics(localPosition, maxRadius);
  }

  void _handlePointerUp(PointerEvent e) {
    _l3Timer?.cancel();

    if (_isL3Pressed.value) {
      _isL3Pressed.value = false;
      widget.onButton(widget.l3ButtonId, false);
    }

    // Trigger exponential snap-back animation
    _returnAnim = Tween<Offset>(
      begin: _knobOffset.value,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutExpo));

    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeNotifier>().accentColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate proportional sizing based on available space
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final center = size / 2;
        final maxRadius = size * 0.38;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text Label
            Text(
              widget.label,
              style: AppTheme.labelStyle(size * 0.12, color: AppTheme.kTextSecondary),
            ),
            SizedBox(height: size * 0.02),

            // Stick Area
            Listener(
              onPointerDown: (e) => _handlePointerDown(e, center, maxRadius),
              onPointerMove: (e) => _handlePointerMove(e, center, maxRadius),
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerUp,
              child: RepaintBoundary(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _ThumbstickPainter(
                      knobOffset: _knobOffset,
                      isL3Pressed: _isL3Pressed,
                      accentColor: accent,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: size * 0.02),

            // Real-time HUD readout
            ValueListenableBuilder<Offset>(
              valueListenable: _normalizedValues,
              builder: (context, val, child) {
                return Text(
                  'X:${val.dx.toStringAsFixed(2)} Y:${val.dy.toStringAsFixed(2)}',
                  style: AppTheme.labelStyle(size * 0.10, color: accent.withAlpha(200)),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// High-Performance Painter
// -----------------------------------------------------------------------------

class _ThumbstickPainter extends CustomPainter {
  final ValueNotifier<Offset> knobOffset;
  final ValueNotifier<bool> isL3Pressed;
  final Color accentColor;

  _ThumbstickPainter({
    required this.knobOffset,
    required this.isL3Pressed,
    required this.accentColor,
  }) : super(repaint: Listenable.merge([knobOffset, isL3Pressed]));
  // ^ Listenable.merge automatically repaints only the canvas when values change!

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.45;
    final knobRadius = size.width * 0.18;

    // 1. Draw Subdued Outer Base
    final paintBase = Paint()
      ..color = AppTheme.kBackground.withAlpha(150)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, paintBase);

    // 2. Draw Subtle Crosshairs
    final paintGrid = Paint()
      ..color = AppTheme.kTextSecondary.withAlpha(30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center.dx, center.dy - outerRadius), Offset(center.dx, center.dy + outerRadius), paintGrid);
    canvas.drawLine(Offset(center.dx - outerRadius, center.dy), Offset(center.dx + outerRadius, center.dy), paintGrid);

    // 3. Draw Outer Neon Border
    final paintOuterBorder = Paint()
      ..color = AppTheme.kHudBorder
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, outerRadius, paintOuterBorder);

    // 4. Draw Knob & Shadows
    final currentOffset = center + knobOffset.value;
    final isL3 = isL3Pressed.value;

    final paintKnobShadow = Paint()
      ..color = accentColor.withAlpha(isL3 ? 180 : 80)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isL3 ? 16 : 8);
    canvas.drawCircle(currentOffset, knobRadius, paintKnobShadow);

    final paintKnob = Paint()
      ..color = AppTheme.kHudSurface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(currentOffset, knobRadius * (isL3 ? 0.92 : 1.0), paintKnob);

    final paintKnobBorder = Paint()
      ..color = accentColor
      ..strokeWidth = isL3 ? 3.0 : 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(currentOffset, knobRadius * (isL3 ? 0.92 : 1.0), paintKnobBorder);
  }

  @override
  bool shouldRepaint(covariant _ThumbstickPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}