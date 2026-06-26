import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/layout_notifier.dart';
import '../providers/settings_notifier.dart';
import '../providers/theme_notifier.dart';
import '../services/connectivity_service.dart';
import '../services/gamepad_command.dart';
import '../theme/app_theme.dart';
import 'layout_editor_overlay.dart'; // REQUIRED TO OPEN THE EDITOR
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class SettingsOverlay extends StatefulWidget {
  final VoidCallback onOpenLayoutEditor;
  const SettingsOverlay({super.key, required this.onOpenLayoutEditor});

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  // Local state variables for ultra-smooth sliding without disk latency
  double? _localSensitivity;
  double? _localDeadzone;
  double? _localUserScale;

  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsNotifier>();
    _ipController = TextEditingController(text: settings.wifiHost);
    _portController = TextEditingController(text: settings.wifiPort.toString());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Widget _buildWifiInputs(
    BuildContext context,
    SettingsNotifier settings,
    ConnectivityService network,
    Color accent,
  ) {
    final labelStyle = AppTheme.labelStyle(11, color: AppTheme.kTextSecondary);
    final inputTextStyle = TextStyle(
      fontSize: 13,
      color: AppTheme.kTextPrimary,
      fontFamily: 'monospace',
      letterSpacing: 0.4,
    );
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: AppTheme.kHudBorder),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: accent),
    );
    final decoration = InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: Colors.black26,
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: focusedBorder,
    );

    void saveIp() {
      final ip = _ipController.text.trim();
      if (ip.isNotEmpty && ip != settings.wifiHost) settings.setWifiHost(ip);
    }

    void savePort() {
      final port = int.tryParse(_portController.text.trim());
      if (port != null &&
          port > 0 &&
          port <= 65535 &&
          port != settings.wifiPort) {
        settings.setWifiPort(port);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PC IP ADDRESS', style: labelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _ipController,
          style: inputTextStyle,
          decoration: decoration.copyWith(
            hintText: '192.168.43.x  or  192.168.1.x',
            hintStyle: TextStyle(
              fontSize: 12,
              color: AppTheme.kTextSecondary.withAlpha(90),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.wifi, size: 14, color: AppTheme.kTextSecondary),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
          ),
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => saveIp(),
          onEditingComplete: () {
            saveIp();
            FocusScope.of(context).unfocus();
          },
        ),
        const SizedBox(height: 10),
        Text('PORT', style: labelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _portController,
          style: inputTextStyle,
          decoration: decoration.copyWith(
            hintText: '5000',
            hintStyle: TextStyle(
              fontSize: 12,
              color: AppTheme.kTextSecondary.withAlpha(90),
            ),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (_) => savePort(),
          onEditingComplete: () {
            savePort();
            FocusScope.of(context).unfocus();
          },
        ),
        const SizedBox(height: 8),
        // Status line
        Row(
          children: [
            Icon(
              network.isConnected
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              size: 12,
              color: network.isConnected
                  ? Colors.greenAccent
                  : AppTheme.kTextSecondary.withAlpha(150),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                network.isConnected
                    ? 'Connected → ${settings.wifiHost}:${settings.wifiPort}'
                    : 'Enter the IP shown by ipconfig on your PC',
                style: TextStyle(
                  fontSize: 11,
                  color: network.isConnected
                      ? Colors.greenAccent.withAlpha(200)
                      : AppTheme.kTextSecondary.withAlpha(150),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Add this method to _SettingsOverlayState:
  Widget _buildBluetoothPicker(
    BuildContext context,
    ConnectivityService network,
    Color accent,
  ) {
    return FutureBuilder<List<BluetoothDevice>>(
      future: network.getBondedDevices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final devices = snapshot.data ?? [];
        if (devices.isEmpty) {
          return Text(
            'No paired devices found.\nPair your PC in Android Bluetooth Settings first.',
            style: AppTheme.labelStyle(11, color: AppTheme.kTextSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SELECT PAIRED DEVICE',
              style: AppTheme.labelStyle(11, color: AppTheme.kTextSecondary),
            ),
            const SizedBox(height: 6),
            ...devices.map((device) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bluetooth, color: accent, size: 16),
                title: Text(
                  device.name ?? device.address,
                  style: AppTheme.labelStyle(13),
                ),
                subtitle: Text(
                  device.address,
                  style: AppTheme.labelStyle(
                    10,
                    color: AppTheme.kTextSecondary,
                  ),
                ),
                onTap: () async {
              // 1. Store the target
               network.setBluetoothTarget(
               device.address,
                device.name,
                        );
              // 2. Connect immediately — no need to press CONNECT separately
                  Navigator.of(context).maybePop(); // close any dialog if applicable
                  await network.connect();
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final settings = context.watch<SettingsNotifier>();
    final layout = context.watch<LayoutNotifier>();
    final network = context.watch<ConnectivityService>();
    final accent = theme.accentColor;

    // Sync local state with the provider on initial load
    _localSensitivity ??= settings.sensitivity;
    _localDeadzone ??= settings.deadzone;
    _localUserScale ??= settings.userScale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final panelWidth = (w * 0.45 > 420) ? 420.0 : w * 0.45;

        return Material(
          color: Colors.transparent,
          child: Container(
            width: panelWidth,
            height: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.kHudSurface.withAlpha(240),
              border: const Border(
                left: BorderSide(color: AppTheme.kHudBorder),
              ),
            ),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(context, settings, accent),
                      const Divider(color: AppTheme.kHudBorder, height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          children: [
                            _buildSectionTitle('INPUT', accent),
                            _buildSliderRow(
                              'SENSITIVITY',
                              _localSensitivity!,
                              0,
                              100,
                              accent,
                              onLocalChange: (v) => _localSensitivity = v,
                              onSaveToDisk: (v) => settings.setSensitivity(v),
                            ),
                            _buildSliderRow(
                              'DEADZONE',
                              _localDeadzone!,
                              0,
                              30,
                              accent,
                              onLocalChange: (v) => _localDeadzone = v,
                              onSaveToDisk: (v) => settings.setDeadzone(v),
                            ),
                            _buildSwitchRow(
                              'VIBRATION',
                              settings.vibration,
                              accent,
                              (v) => settings.setVibration(v),
                            ),
                            const SizedBox(height: 24),

                            _buildSectionTitle('LAYOUT', accent),
                            _buildSegmentedControl<bool>(
                              value: layout.isXbox,
                              options: const {
                                true: 'XBOX',
                                false: 'PLAYSTATION',
                              },
                              accent: accent,
                              onChanged: (v) {
                                if (v != layout.isXbox) {
                                  layout.toggleLayout();
                                  // isXbox has already flipped, so read the new value
                                  final newProfile = layout.isXbox
                                      ? 'xbox360'
                                      : 'ds4';
                                  context
                                      .read<ConnectivityService>()
                                      .sendCommand(
                                        GamepadCommandFactory.setProfile(
                                          newProfile,
                                        ),
                                      );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildSliderRow(
                              'BUTTON SIZE',
                              _localUserScale!,
                              0.7,
                              1.4,
                              accent,
                              isPercentage: true,
                              onLocalChange: (v) => _localUserScale = v,
                              onSaveToDisk: (v) => settings.setUserScale(v),
                            ),
                            const SizedBox(height: 16),
                            _buildActionButton('EDIT LAYOUT', accent, () {
                              Navigator.of(context).pop();
                              widget.onOpenLayoutEditor(); // Close settings
                            }),
                            const SizedBox(height: 24),

                            _buildSectionTitle('CONNECTION', accent),
                            // REPLACE WITH THIS:
                            if (network.activeMode == ActiveMode.wifi) ...[
                              const SizedBox(height: 4),
                              _buildWifiInputs(
                                context,
                                settings,
                                network,
                                accent,
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (network.activeMode == ActiveMode.bluetooth) ...[
                              const SizedBox(height: 8),
                              _buildBluetoothPicker(context, network, accent),
                              const SizedBox(height: 8),
                            ],

                            _buildSegmentedControl<ActiveMode>(
                              value: network.activeMode,
                              options: const {
                                ActiveMode.bluetooth: 'BT',
                                ActiveMode.wifi: 'WIFI',
                                ActiveMode.usb: 'USB',
                              },
                              accent: accent,
                              onChanged: (v) => network.setMode(v),
                            ),
                            const SizedBox(height: 24),
                            // Connect / Disconnect button
                            // REPLACE the CONNECT button's onPressed:
                            _buildActionButton(
                              network.isConnected ? 'DISCONNECT' : 'CONNECT',
                              network.isConnected ? Colors.redAccent : accent,
                              () async {
                                if (network.isConnected) {
                                  await network.disconnect();
                                } else {
                                  // Flush any un-submitted text field values before connecting.
                                  // (User may have typed an IP without pressing the keyboard's Done key.)
                                  final newIp = _ipController.text.trim();
                                  final newPort = int.tryParse(
                                    _portController.text.trim(),
                                  );
                                  if (newIp.isNotEmpty &&
                                      newIp != settings.wifiHost) {
                                    await settings.setWifiHost(newIp);
                                  }
                                  if (newPort != null &&
                                      newPort > 0 &&
                                      newPort <= 65535 &&
                                      newPort != settings.wifiPort) {
                                    await settings.setWifiPort(newPort);
                                  }
                                  await network.connect();
                                }
                              },
                            ),

                            // Connection status text
                            const SizedBox(height: 8),
                            Text(
                              network.statusMessage,
                              textAlign: TextAlign.center,
                              style: AppTheme.labelStyle(
                                11,
                                color: AppTheme.kTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _buildSectionTitle('APPEARANCE', accent),
                            _buildColorPicker(theme),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      _buildFooter(context, accent),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SettingsNotifier settings,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.flash_on, color: accent),
          const SizedBox(width: 8),
          Text('SETTINGS', style: AppTheme.labelStyle(20)),
          const Spacer(),
          TextButton(
            onPressed: () {
              settings.reset();
              setState(() {
                _localSensitivity = 75.0;
                _localDeadzone = 12.0;
                _localUserScale = 1.0;
              });
            },
            child: Text(
              'RESET',
              style: AppTheme.labelStyle(14, color: AppTheme.kTextSecondary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.kTextSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: AppTheme.labelStyle(14, color: AppTheme.kTextSecondary),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    Color accent, {
    bool isPercentage = false,
    required Function(double) onLocalChange,
    required Function(double) onSaveToDisk,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3, // Safely expands instead of hardcoding 90px
            child: Text(label, style: AppTheme.labelStyle(12)),
          ),
          Expanded(
            flex: 5,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accent,
                inactiveTrackColor: Colors.white12,
                thumbColor: accent,
                overlayColor: accent.withAlpha(50),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (val) {
                  setState(() {
                    onLocalChange(val);
                  });
                },
                onChangeEnd: (val) {
                  onSaveToDisk(val);
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isPercentage
                  ? '${(value * 100).toInt()}%'
                  : value.toInt().toString(),
              textAlign: TextAlign.right,
              style: AppTheme.labelStyle(14, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    Color accent,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.labelStyle(12)),
          CupertinoSwitch(
            value: value,
            activeColor: accent,
            trackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl<T>({
    required T value,
    required Map<T, String> options,
    required Color accent,
    required Function(T) onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.kHudBorder),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final isSelected = value == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? accent.withAlpha(50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: isSelected ? Border.all(color: accent) : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.value,
                  style: AppTheme.labelStyle(
                    14,
                    color: isSelected ? accent : AppTheme.kTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton(String label, Color accent, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withAlpha(100)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppTheme.labelStyle(14, color: accent)),
      ),
    );
  }

  Widget _buildColorPicker(ThemeNotifier theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      children: theme.accentOptions.map((color) {
        final isSelected = theme.accentColor == color;
        return GestureDetector(
          onTap: () => theme.setAccent(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withAlpha(150),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(BuildContext context, Color accent) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent.withAlpha(50),
            foregroundColor: accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: accent),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('DONE', style: AppTheme.labelStyle(16, color: accent)),
        ),
      ),
    );
  }
}
