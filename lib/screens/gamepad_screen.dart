import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/layout_notifier.dart';
import '../services/connectivity_service.dart';
import '../services/gamepad_command.dart';
import '../widgets/xbox_layout.dart';
import '../widgets/ps_layout.dart';

class GamepadScreen extends StatelessWidget {
  const GamepadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isXbox = context.watch<LayoutNotifier>().isXbox;
    final networkService = context.watch<ConnectivityService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The Active Controller Layout
          Center(
            child: isXbox
                ? XboxLayout(onSignal: (s) => networkService.sendCommand(GamepadCommandFactory.buttonDown(s)))
                : PSLayout(onSignal: (s) => networkService.sendCommand(GamepadCommandFactory.buttonDown(s))),
          ),

          // Network Status & Layout Toggle Bar
    // Network Status & Layout Toggle Bar
    Positioned(
    top: 20,
    left: 20,
    right: 20,
    child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    // Network Controls Row
    Row(
    children: [
    // Mode Selector Dropdown
    Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
    color: Colors.grey[900],
    borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButton<ActiveMode>(
    value: networkService.activeMode,
    dropdownColor: Colors.grey[900],
    underline: const SizedBox(),
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    items: ActiveMode.values.map((mode) {
    return DropdownMenuItem(
    value: mode,
    child: Text(mode.name.toUpperCase()),
    );
    }).toList(),
    onChanged: (mode) {
    if (mode != null) networkService.setMode(mode);
    },
    ),
    ),

    const SizedBox(width: 10),

    // Connect/Disconnect Button
    ElevatedButton.icon(
    onPressed: () {
    if (networkService.isConnected) {
    networkService.disconnect();
    } else {
    networkService.connect();
    }
    },
    icon: Icon(
    networkService.isConnected ? Icons.link_off : Icons.link,
    color: networkService.isConnected ? Colors.red : Colors.green,
    ),
    label: Text(
    networkService.isConnected ? "Disconnect" : "Connect",
    style: const TextStyle(color: Colors.white),
    ),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[900]),
    ),
    ],
    ),

    // Layout Switcher
    ElevatedButton(
    onPressed: () => context.read<LayoutNotifier>().toggleLayout(),
    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
    child: Text(
    isXbox ? "Switch to PS" : "Switch to Xbox",
    style: const TextStyle(color: Colors.white),
    ),
    ),
    ],
    ),
    ),
        ],
      ),
    );
  }
}