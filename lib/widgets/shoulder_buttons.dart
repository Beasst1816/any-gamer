import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

/// Base class to handle strict Multitouch and properly dispose ValueNotifiers
class _BaseShoulderButton extends StatefulWidget {
  final String id;
  final String label;
  final double width;
  final double height;
  final void Function(String id, bool isPressed) onSignal;

  const _BaseShoulderButton({
    super.key,
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.onSignal,
  });

  @override
  State<_BaseShoulderButton> createState() => _BaseShoulderButtonState();
}

class _BaseShoulderButtonState extends State<_BaseShoulderButton> {
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

  void _handlePointerDown(PointerDownEvent event) {
    HapticFeedback.lightImpact();
    _isPressed.value = true;
    widget.onSignal(widget.id, true);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _isPressed.value = false;
    widget.onSignal(widget.id, false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final accent = theme.accentColor;

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
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppTheme.kHudSurface,
                  borderRadius: BorderRadius.circular(widget.width * 0.5),
                  border: Border.all(
                    color: pressed ? accent : AppTheme.kHudBorder,
                    width: 2,
                  ),
                  boxShadow: pressed
                      ? [
                    BoxShadow(
                      color: accent.withAlpha(140),
                      blurRadius: 14,
                      spreadRadius: 2,
                    )
                  ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: AppTheme.labelStyle(
                    // Scales text relative to the button's height
                    widget.height * 0.35,
                    color: pressed ? accent : AppTheme.kTextSecondary,
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
// Specific Implementations
// -----------------------------------------------------------------------------

class LTButton extends StatefulWidget {
  final double width;
  final double height;
  final void Function(String id, bool isPressed) onSignal;
  final void Function(String id, double value)? onAxis;

  const LTButton({super.key, required this.width, required this.height, required this.onSignal, this.onAxis});

  @override
  State<LTButton> createState() => _LTButtonState();
}

class _LTButtonState extends State<LTButton> {
  late final ValueNotifier<bool> _isPressed;
  double _lastSent = 0.0;
  final String _id = 'ABS_Z';

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

  void _updatePressureFromEvent(PointerEvent e) {
    final localY = e.localPosition.dy.clamp(0.0, widget.height);
    final pressure = (localY / widget.height).clamp(0.0, 1.0);
    if ((pressure - _lastSent).abs() >= 0.01) {
      widget.onAxis?.call(_id, pressure);
      _lastSent = pressure;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    HapticFeedback.lightImpact();
    _isPressed.value = true;
    widget.onSignal(_id, true);
    _updatePressureFromEvent(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _updatePressureFromEvent(event);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _isPressed.value = false;
    widget.onSignal(_id, false);
    widget.onAxis?.call(_id, 0.0);
    _lastSent = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final accent = theme.accentColor;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isPressed,
        builder: (context, pressed, child) {
          return AnimatedScale(
            scale: pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 50),
            child: RepaintBoundary(
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppTheme.kHudSurface,
                  borderRadius: BorderRadius.circular(widget.width * 0.5),
                  border: Border.all(
                    color: pressed ? accent : AppTheme.kHudBorder,
                    width: 2,
                  ),
                  boxShadow: pressed
                      ? [
                          BoxShadow(
                            color: accent.withAlpha(140),
                            blurRadius: 14,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'LT',
                  style: AppTheme.labelStyle(
                    widget.height * 0.35,
                    color: pressed ? accent : AppTheme.kTextSecondary,
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


class RTButton extends StatefulWidget {
  final double width;
  final double height;
  final void Function(String id, bool isPressed) onSignal;
  final void Function(String id, double value)? onAxis;

  const RTButton({super.key, required this.width, required this.height, required this.onSignal, this.onAxis});

  @override
  State<RTButton> createState() => _RTButtonState();
}

class _RTButtonState extends State<RTButton> {
  late final ValueNotifier<bool> _isPressed;
  double _lastSent = 0.0;
  final String _id = 'ABS_RZ';

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

  void _updatePressureFromEvent(PointerEvent e) {
    final localY = e.localPosition.dy.clamp(0.0, widget.height);
    final pressure = (localY / widget.height).clamp(0.0, 1.0);
    if ((pressure - _lastSent).abs() >= 0.01) {
      widget.onAxis?.call(_id, pressure);
      _lastSent = pressure;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    HapticFeedback.lightImpact();
    _isPressed.value = true;
    widget.onSignal(_id, true);
    _updatePressureFromEvent(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    _updatePressureFromEvent(event);
  }

  void _handlePointerUpOrCancel(PointerEvent event) {
    _isPressed.value = false;
    widget.onSignal(_id, false);
    widget.onAxis?.call(_id, 0.0);
    _lastSent = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final accent = theme.accentColor;

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUpOrCancel,
      onPointerCancel: _handlePointerUpOrCancel,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isPressed,
        builder: (context, pressed, child) {
          return AnimatedScale(
            scale: pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 50),
            child: RepaintBoundary(
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppTheme.kHudSurface,
                  borderRadius: BorderRadius.circular(widget.width * 0.5),
                  border: Border.all(
                    color: pressed ? accent : AppTheme.kHudBorder,
                    width: 2,
                  ),
                  boxShadow: pressed
                      ? [
                          BoxShadow(
                            color: accent.withAlpha(140),
                            blurRadius: 14,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'RT',
                  style: AppTheme.labelStyle(
                    widget.height * 0.35,
                    color: pressed ? accent : AppTheme.kTextSecondary,
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

class LBButton extends StatelessWidget {
  final double width;
  final double height;
  final void Function(String id, bool isPressed) onSignal;

  const LBButton({super.key, required this.width, required this.height, required this.onSignal});

  @override
  Widget build(BuildContext context) {
    return _BaseShoulderButton(
        key: key,
        id: 'BTN_TL',
        label: 'LB',
        width: width,
        height: height,
        onSignal: onSignal
    );
  }
}

class RBButton extends StatelessWidget {
  final double width;
  final double height;
  final void Function(String id, bool isPressed) onSignal;

  const RBButton({super.key, required this.width, required this.height, required this.onSignal});

  @override
  Widget build(BuildContext context) {
    return _BaseShoulderButton(
        key: key,
        id: 'BTN_TR',
        label: 'RB',
        width: width,
        height: height,
        onSignal: onSignal
    );
  }
}