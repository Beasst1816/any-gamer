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

class XboxLayout extends StatelessWidget {
  final void Function(String id, bool pressed) onSignal;
  final void Function(String id, double value) onAxis;
  final VoidCallback onOpenSettings;
  final double deadzoneNormalized;
  final double sensitivityMultiplier;

  const XboxLayout({
    super.key,
    required this.onSignal,
    required this.onAxis,
    required this.onOpenSettings,
    required this.deadzoneNormalized,
    required this.sensitivityMultiplier,
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

        // Safe array index reading with fallbacks
        final leftTopKey = layout.leftZone.isNotEmpty
            ? layout.leftZone[0]
            : 'l_stick';
        final leftBottomKey = layout.leftZone.length > 1
            ? layout.leftZone[1]
            : 'dpad';
        final rightTopKey = layout.rightZone.isNotEmpty
            ? layout.rightZone[0]
            : 'buttons';
        final rightBottomKey = layout.rightZone.length > 1
            ? layout.rightZone[1]
            : 'r_stick';

        final centerWidth = w * 0.30;
        final centerHeight = h * 0.18 * userScale;
        final triggerW = w * 0.08 * userScale;
        final triggerH = h * 0.18 * userScale;
        final bumperW = w * 0.08 * userScale;
        final bumperH = h * 0.12 * userScale;

        // Dynamic widget factory
        Widget buildComponent(String key) {
          if (!layout.isVisible(key)) return const SizedBox.shrink();

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
                  label: 'LS',
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
                  label: 'RS',
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
                isXbox: true,
                size: faceSize,
                onSignal: onSignal,
              );
            default:
              return const SizedBox.shrink();
          }
        }

        return Stack(
          children: [
            // === TOP STRIP ===
            if (layout.isVisible('lt') || layout.isVisible('lb'))
              Positioned(
                top: h * 0.02,
                left: w * 0.15,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (layout.isVisible('lt'))
                      LTButton(
                        width: triggerW,
                        height: triggerH,
                        onSignal: onSignal,
                        onAxis: onAxis,
                        isXbox: true,
                      ),
                    if (layout.isVisible('lt') && layout.isVisible('lb'))
                      SizedBox(width: w * 0.02),
                    if (layout.isVisible('lb'))
                      LBButton(
                        width: bumperW,
                        height: bumperH,
                        onSignal: onSignal,
                        isXbox: true,
                      ),
                  ],
                ),
              ),
            if (layout.isVisible('rt') || layout.isVisible('rb'))
              Positioned(
                top: h * 0.02,
                right: w * 0.15,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (layout.isVisible('rb'))
                      RBButton(
                        width: bumperW,
                        height: bumperH,
                        onSignal: onSignal,
                        isXbox: true,
                      ),
                    if (layout.isVisible('rt') && layout.isVisible('rb'))
                      SizedBox(width: w * 0.02),
                    if (layout.isVisible('rt'))
                      RTButton(
                        width: triggerW,
                        height: triggerH,
                        onSignal: onSignal,
                        onAxis: onAxis,
                        isXbox: true,
                      ),
                  ],
                ),
              ),

            // === LEFT WING ===
            Positioned(
              top: h * 0.28,
              left: w * 0.05,
              child: buildComponent(leftTopKey),
            ),
            Positioned(
              bottom: h * 0.05,
              left: w * 0.18,
              child: buildComponent(leftBottomKey),
            ),

            // === RIGHT WING ===
            Positioned(
              top: h * 0.28,
              right: w * 0.05,
              child: buildComponent(rightTopKey),
            ),
            Positioned(
              bottom: h * 0.05,
              right: w * 0.18,
              child: buildComponent(rightBottomKey),
            ),

            // === CENTER ===
            Positioned(
              bottom: h * 0.05,
              left: (w / 2) - (centerWidth / 2),
              width: centerWidth,
              height: centerHeight,
              child: CenterCluster(
                width: centerWidth,
                height: centerHeight,
                onSignal: onSignal,
                onOpenSettings: onOpenSettings,
              ),
            ),
          ],
        );
      },
    );
  }
}
