import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/layout_notifier.dart';
import '../providers/settings_notifier.dart';
import '../services/connectivity_service.dart';
import '../services/gamepad_command.dart';
import '../theme/app_theme.dart';
import '../widgets/xbox_layout.dart';
import '../widgets/ps_layout.dart';
import '../widgets/settings_overlay.dart';

class GamepadScreen extends StatefulWidget {
  const GamepadScreen({super.key});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('>>> AppLifecycle: $state');
    final network = context.read<ConnectivityService>();

    switch (state) {
      case AppLifecycleState.resumed:
        network.resumeInput();
        break;
      case AppLifecycleState.inactive:
        // App is visible but obscured by a system overlay (e.g., notification shade).
        // Do NOT disconnect. Keep the connection fully alive.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // App is backgrounded. Prevent rogue axis drift and maintain TCP alive state.
        network.pauseInput();
        break;
      case AppLifecycleState.detached:
        // App is being killed by the OS. Clean up the socket.
        break;
    }
  }

  void _openSettings() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SettingsDismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Align(
          alignment: Alignment.centerRight,
          child: SettingsOverlay(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final networkService = context.watch<ConnectivityService>();
    final isXbox = context.watch<LayoutNotifier>().isXbox;
    final settings = context.watch<SettingsNotifier>();
    // SettingsNotifier.deadzone is 0–30 (UI units), convert to 0.0–0.30 float
    final deadzone = (settings.deadzone / 100.0).clamp(0.0, 0.3);
    // sensitivity is 0–100 UI → 0.5–2.0 multiplier
    final sensitivity = (0.5 + (settings.sensitivity / 100.0) * 1.5).clamp(
      0.5,
      2.0,
    );

    void handleSignal(String id, bool isPressed) {
      final cmd = isPressed
          ? GamepadCommandFactory.buttonDown(id)
          : GamepadCommandFactory.buttonUp(id);
      networkService.sendCommand(cmd);
    }

    void handleAxis(String id, double value) {
      networkService.sendCommand(GamepadCommandFactory.axisUpdate(id, value));
    }

    return Scaffold(
      backgroundColor: AppTheme.kBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          if (w == 0 || h == 0) return const SizedBox.shrink();

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.04,
              vertical: h * 0.05,
            ),
            child: Stack(
              children: [
                // 1. Main HUD card
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.kHudSurface,
                          border: Border.all(color: AppTheme.kHudBorder),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Active Controller Layout
                Positioned.fill(
                  child: isXbox
                      ? XboxLayout(
                          onSignal: handleSignal,
                          onAxis: handleAxis,
                          onOpenSettings: _openSettings,
                          deadzoneNormalized: deadzone,
                          sensitivityMultiplier: sensitivity,
                        )
                      : PSLayout(
                          onSignal: handleSignal,
                          onAxis: handleAxis,
                          onOpenSettings: _openSettings,
                          deadzoneNormalized: deadzone,
                          sensitivityMultiplier: sensitivity,
                        ),
                ),

                // 3. Status bar (Minimized to a tiny LED dot)
                Positioned(
                  top: h * 0.06,
                  left: w * 0.04,
                  child: _buildStatusBar(networkService, h),
                ),

                // The old Settings Gear has been completely deleted!
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(ConnectivityService network, double h) {
    Color statusColor;
    switch (network.connectionState) {
      case ServiceConnectionState.connected:
        statusColor = AppTheme.kA; // Green
        break;
      case ServiceConnectionState.connecting:
      case ServiceConnectionState.scanning:
      case ServiceConnectionState.reconnecting:
        statusColor = AppTheme.kY; // Orange/Yellow
        break;
      default:
        statusColor = AppTheme.kB; // Red (Disconnected)
    }

    // Minimized UI - Just a glowing dot
    return Container(
      width: h * 0.06,
      height: h * 0.06,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(128),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
