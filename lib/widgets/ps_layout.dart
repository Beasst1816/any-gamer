import 'package:flutter/material.dart';
import 'gamepad_buttons.dart';

class PSLayout extends StatelessWidget {
  final Function(String) onSignal;

  const PSLayout({Key? key, required this.onSignal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: GamepadButton(label: '✕', color: Colors.blue, onPressed: () => onSignal('BTN_SOUTH'))),
          Positioned(right: 0, child: GamepadButton(label: '◯', color: Colors.red, onPressed: () => onSignal('BTN_EAST'))),
          Positioned(left: 0, child: GamepadButton(label: '□', color: Colors.pinkAccent, onPressed: () => onSignal('BTN_WEST'))),
          Positioned(top: 0, child: GamepadButton(label: '△', color: Colors.green, onPressed: () => onSignal('BTN_NORTH'))),
        ],
      ),
    );
  }
}