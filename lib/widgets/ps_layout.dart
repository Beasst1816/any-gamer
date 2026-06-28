import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/layout_notifier.dart';
import '../providers/settings_notifier.dart';
import 'shoulder_buttons.dart';
import 'dpad_widget.dart';
import 'thumbstick_widget.dart';
import 'face_button_cluster.dart';
import 'center_cluster.dart';
import 'camera_scroll_area.dart';

class PSLayout extends StatelessWidget {
  final void Function(String id, bool pressed) onSignal;
  final void Function(String id, double value) onAxis;
  final VoidCallback onOpenSettings;
  final double deadzoneNormalized;
  final double sensitivityMultiplier;
  final double cameraSensitivity;

  const PSLayout({
    super.key,
    required this.onSignal,
    required this.onAxis,
    required this.onOpenSettings,
    required this.deadzoneNormalized,
    required this.sensitivityMultiplier,
    this.cameraSensitivity = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final baseUnit = math.min(w, h);
        final double userScale = context.watch<SettingsNotifier>().userScale;
        final layout = context.watch<LayoutNotifier>();
        final accent = Theme.of(context).colorScheme.secondary;

        final centerWidth = w * 0.30;
        final centerHeight = h * 0.18 * userScale;
        final triggerW = w * 0.08 * userScale;
        final triggerH = h * 0.18 * userScale;
        final bumperW = w * 0.08 * userScale;
        final bumperH = h * 0.12 * userScale;

        Widget buildComponent(String key) {
          final stickSize = baseUnit * 0.40 * userScale;
          final dpadSize = baseUnit * 0.35 * userScale;
          final faceSize = baseUnit * 0.42 * userScale;

          switch (key) {
            case 'l_stick':
              return SizedBox(
                width: stickSize,
                child: ThumbstickWidget(
                  axisX: 'LS_X',
                  axisY: 'LS_Y',
                  l3ButtonId: 'BTN_THUMBL',
                  label: 'L3',
                  onAxis: onAxis,
                  onButton: onSignal,
                  deadzoneNormalized: deadzoneNormalized,
                  sensitivityMultiplier: sensitivityMultiplier,
                ),
              );
            case 'r_stick':
              return SizedBox(
                width: stickSize,
                child: ThumbstickWidget(
                  axisX: 'RS_X',
                  axisY: 'RS_Y',
                  l3ButtonId: 'BTN_THUMBR',
                  label: 'R3',
                  onAxis: onAxis,
                  onButton: onSignal,
                  deadzoneNormalized: deadzoneNormalized,
                  sensitivityMultiplier: sensitivityMultiplier,
                ),
              );
            case 'dpad':
              return DPadWidget(size: dpadSize, onSignal: onSignal);
            case 'buttons':
              return FaceButtonCluster(
                isXbox: false,
                size: faceSize,
                onSignal: onSignal,
              );
            default:
              return const SizedBox.shrink();
          }
        }

        // Helper to wrap any component as a draggable Positioned
        Widget buildPositioned(String key, Widget child) {
          final pos = layout.getPos(key);

          final bool effectivelyVisible =
              layout.isVisible(key) || (layout.isEditing && key == 'r_stick');
          if (!effectivelyVisible) return const SizedBox.shrink();

          final posChild = Positioned(
            left: pos.dx * w,
            top: pos.dy * h,
            child: child,
          );

          if (!layout.isEditing) return posChild;

          // Edit mode: wrap in GestureDetector
          return Positioned(
            left: pos.dx * w,
            top: pos.dy * h,
            child: GestureDetector(
              onPanUpdate: (details) {
                final newDx = pos.dx + details.delta.dx / w;
                final newDy = pos.dy + details.delta.dy / h;
                context.read<LayoutNotifier>().updatePosition(
                  key,
                  Offset(newDx, newDy),
                );
              },
              child: Stack(
                children: [
                  child,
                  // Drag handle indicator overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: accent.withAlpha(180),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            if (layout.isVisible('camera_zone') && !layout.isEditing)
              Positioned(
                left: w * 0.35,
                top: 0,
                right: 0,
                bottom: 0,
                child: CameraScrollArea(
                  onAxis: onAxis,
                  cameraSensitivity: cameraSensitivity,
                ),
              ),
            buildPositioned(
              'lt',
              LTButton(
                width: triggerW,
                height: triggerH,
                onSignal: onSignal,
                onAxis: onAxis,
                isXbox: false,
              ),
            ),
            buildPositioned(
              'lb',
              LBButton(
                width: bumperW,
                height: bumperH,
                onSignal: onSignal,
                isXbox: false,
              ),
            ),
            buildPositioned(
              'rt',
              RTButton(
                width: triggerW,
                height: triggerH,
                onSignal: onSignal,
                onAxis: onAxis,
                isXbox: false,
              ),
            ),
            buildPositioned(
              'rb',
              RBButton(
                width: bumperW,
                height: bumperH,
                onSignal: onSignal,
                isXbox: false,
              ),
            ),
            buildPositioned('l_stick', buildComponent('l_stick')),
            buildPositioned('dpad', buildComponent('dpad')),
            buildPositioned('buttons', buildComponent('buttons')),
            buildPositioned('r_stick', buildComponent('r_stick')),
            buildPositioned(
              'center',
              SizedBox(
                width: centerWidth,
                height: centerHeight,
                child: CenterCluster(
                  width: centerWidth,
                  height: centerHeight,
                  onSignal: onSignal,
                  onOpenSettings: onOpenSettings,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
