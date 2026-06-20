import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class FaceButtonCluster extends StatelessWidget {
  final bool isXbox;
  final double size; // Passed from LayoutBuilder in GamepadScreen
  final void Function(String id, bool pressed) onSignal;

  const FaceButtonCluster({
    super.key,
    required this.isXbox,
    required this.size,
    required this.onSignal,
  });

  @override
  Widget build(BuildContext context) {
    // Proportional sizing based on the total cluster size
    // 0.38 maintains the ratio of h*0.22 per button against h*0.58 total height
    final double buttonSize = size * 0.38;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // TOP BUTTON (Y / Triangle)
          Positioned(
            top: 0,
            left: (size / 2) - (buttonSize / 2),
            child: _FaceButton(
              id: 'BTN_NORTH',
              label: isXbox ? 'Y' : '△',
              color: isXbox ? AppTheme.kY : AppTheme.kPS_Triangle,
              size: buttonSize,
              onSignal: onSignal,
            ),
          ),

          // BOTTOM BUTTON (A / Cross)
          Positioned(
            bottom: 0,
            left: (size / 2) - (buttonSize / 2),
            child: _FaceButton(
              id: 'BTN_SOUTH',
              label: isXbox ? 'A' : '✕',
              color: isXbox ? AppTheme.kA : AppTheme.kPS_Cross,
              size: buttonSize,
              onSignal: onSignal,
            ),
          ),

          // LEFT BUTTON (X / Square)
          Positioned(
            left: 0,
            top: (size / 2) - (buttonSize / 2),
            child: _FaceButton(
              id: 'BTN_WEST',
              label: isXbox ? 'X' : '□',
              color: isXbox ? AppTheme.kX : AppTheme.kPS_Square,
              size: buttonSize,
              onSignal: onSignal,
            ),
          ),

          // RIGHT BUTTON (B / Circle)
          Positioned(
            right: 0,
            top: (size / 2) - (buttonSize / 2),
            child: _FaceButton(
              id: 'BTN_EAST',
              label: isXbox ? 'B' : '◯',
              color: isXbox ? AppTheme.kB : AppTheme.kPS_Circle,
              size: buttonSize,
              onSignal: onSignal,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Interactive Button Shell
// -----------------------------------------------------------------------------

class _FaceButton extends StatefulWidget {
  final String id;
  final String label;
  final Color color;
  final double size;
  final void Function(String id, bool pressed) onSignal;

  const _FaceButton({
    required this.id,
    required this.label,
    required this.color,
    required this.size,
    required this.onSignal,
  });

  @override
  State<_FaceButton> createState() => _FaceButtonState();
}

class _FaceButtonState extends State<_FaceButton> {
  late final ValueNotifier<bool> _isPressed;

  @override
  void initState() {
    super.initState();
    _isPressed = ValueNotifier(false);
  }

  @override
  void dispose() {
    _isPressed.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent e) {
    HapticFeedback.lightImpact();
    _isPressed.value = true;
    widget.onSignal(widget.id, true);
  }

  void _handlePointerUpOrCancel(PointerEvent e) {
    _isPressed.value = false;
    widget.onSignal(widget.id, false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isPressed,
        builder: (context, pressed, child) {
          return AnimatedScale(
            scale: pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 50),
            child: RepaintBoundary(
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _FaceButtonPainter(
                    isPressed: _isPressed,
                    color: widget.color,
                    label: widget.label,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6-Layer Graphics Engine
// -----------------------------------------------------------------------------

class _FaceButtonPainter extends CustomPainter {
  final ValueNotifier<bool> isPressed;
  final Color color;
  final String label;

  _FaceButtonPainter({
    required this.isPressed,
    required this.color,
    required this.label,
  }) : super(repaint: isPressed); // Subscribes the canvas directly to the notifier

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final pressed = isPressed.value;

    // Layer 1: Dark background fill
    final bgPaint = Paint()
      ..color = AppTheme.kHudSurface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Layer 4: Inner subtle gradient (Drawn before border to keep edges crisp)
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withAlpha(pressed ? 100 : 30), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, gradientPaint);

    // Layer 2: Outer glow ring
    final glowPaint = Paint()
      ..color = color.withAlpha(pressed ? 200 : 60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, radius, glowPaint);

    // Layer 3: Border ring
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Layer 6: Press-state overlay (White flash 0 -> 0.15 opacity)
    if (pressed) {
      final overlayPaint = Paint()
        ..color = Colors.white.withAlpha(38) // 38 = ~15% of 255
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, overlayPaint);
    }

    // Layer 5: Label text
    // Adjust font size specifically for the PlayStation symbols vs Xbox letters
    final bool isPS = label == '△' || label == '✕' || label == '□' || label == '◯';
    final fontSize = isPS ? size.width * 0.55 : size.width * 0.45;

    final textSpan = TextSpan(
      text: label,
      style: AppTheme.labelStyle(fontSize, color: color, weight: FontWeight.bold),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - (textPainter.width / 2), center.dy - (textPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceButtonPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.label != label;
  }
}