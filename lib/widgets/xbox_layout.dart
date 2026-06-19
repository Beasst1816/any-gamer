import 'package:flutter/material.dart';
import 'gamepad_buttons.dart';

class XboxLayout extends StatelessWidget {
  final void Function(String id, bool isPressed) onSignal;

  const XboxLayout({Key? key, required this.onSignal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Standard diamond layout for action buttons
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: GamepadButton(label: 'A', color: Colors.green,
            onPressed: () => onSignal('BTN_SOUTH', true),
            onReleased: () => onSignal('BTN_SOUTH', false),
          )),
          Positioned(right: 0, child: GamepadButton(label: 'B', color: Colors.red,
              onPressed: () => onSignal('BTN_EAST', true),
              onReleased: () => onSignal('BTN_EAST', false),
          )),
          Positioned(left: 0, child: GamepadButton(label: 'X', color: Colors.blue,
              onPressed: () => onSignal('BTN_WEST', true),
              onReleased: () => onSignal('BTN_WEST', false),
          )),
          Positioned(top: 0, child: GamepadButton(label: 'Y', color: Colors.yellow,
              onPressed: () => onSignal('BTN_NORTH', true),
              onReleased: () => onSignal('BTN_NORTH', false),
          )),
        ],
      ),
    );
  }
}