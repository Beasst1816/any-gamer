import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../theme/app_theme.dart';

class CenterCluster extends StatelessWidget {
  final double width;
  final double height;
  final void Function(String id, bool pressed) onSignal;
  final VoidCallback onOpenSettings;

  const CenterCluster({
    super.key,
    required this.width,
    required this.height,
    required this.onSignal,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final double pillWidth = width * 0.32;
    final double pillHeight = height * 0.35;
    final double guideSize = height * 0.70;

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MenuButton(id: 'BTN_SELECT', label: 'SELECT', width: pillWidth, height: pillHeight, onSignal: onSignal),
          _GuideButton(id: 'BTN_MODE', size: guideSize, onSignal: onSignal, onLongPress: onOpenSettings),
          _MenuButton(id: 'BTN_START', label: 'START', width: pillWidth, height: pillHeight, onSignal: onSignal),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pill-Shaped Menu Button (Start / Select)
// -----------------------------------------------------------------------------

class _MenuButton extends StatefulWidget {
  final String id;
  final String label;
  final double width;
  final double height;
  final void Function(String id, bool pressed) onSignal;

  const _MenuButton({required this.id, required this.label, required this.width, required this.height, required this.onSignal});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
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
    final accent = context.watch<ThemeNotifier>().accentColor;
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
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(color: pressed ? accent : AppTheme.kHudBorder, width: 1.5),
                  boxShadow: pressed ? [BoxShadow(color: accent.withAlpha(120), blurRadius: 10, spreadRadius: 1)] : [],
                ),
                alignment: Alignment.center,
                child: Text(widget.label, style: AppTheme.labelStyle(widget.height * 0.45, color: pressed ? accent : AppTheme.kTextSecondary)),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Circular Guide Button (Home / Logo) WITH LONG PRESS
// -----------------------------------------------------------------------------

class _GuideButton extends StatefulWidget {
  final String id;
  final double size;
  final void Function(String id, bool pressed) onSignal;
  final VoidCallback onLongPress;

  const _GuideButton({required this.id, required this.size, required this.onSignal, required this.onLongPress});

  @override
  State<_GuideButton> createState() => _GuideButtonState();
}

class _GuideButtonState extends State<_GuideButton> {
  late final ValueNotifier<bool> _isPressed;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _isPressed = ValueNotifier(false);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _isPressed.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent e) {
    HapticFeedback.lightImpact();
    _isPressed.value = true;
    widget.onSignal(widget.id, true);

    // Fire settings overlay if held for 600ms
    _longPressTimer = Timer(const Duration(milliseconds: 600), () {
      if (_isPressed.value) {
        HapticFeedback.heavyImpact();
        widget.onLongPress();
      }
    });
  }

  void _handlePointerUpOrCancel(PointerEvent e) {
    _longPressTimer?.cancel();
    _isPressed.value = false;
    widget.onSignal(widget.id, false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<ThemeNotifier>().accentColor;
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
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: AppTheme.kBackground.withAlpha(200),
                  shape: BoxShape.circle,
                  border: Border.all(color: pressed ? accent : accent.withAlpha(150), width: 2.0),
                  boxShadow: [BoxShadow(color: accent.withAlpha(pressed ? 200 : 60), blurRadius: pressed ? 20 : 12, spreadRadius: pressed ? 4 : 1)],
                ),
                alignment: Alignment.center,
                child: Icon(Icons.flash_on, color: pressed ? Colors.white : accent, size: widget.size * 0.55),
              ),
            ),
          );
        },
      ),
    );
  }
}