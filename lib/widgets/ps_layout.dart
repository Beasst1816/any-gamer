import 'package:flutter/material.dart';
import 'gamepad_buttons.dart';

class PSLayout extends StatelessWidget {
  final void Function(String id, bool isPressed) onSignal;

  const PSLayout({Key? key, required this.onSignal}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(bottom: 0, child: GamepadButton(label: '✕', color: Colors.blue,
              onPressed: () => onSignal('BTN_SOUTH', true),
              onReleased: () => onSignal('BTN_SOUTH', false),
          )),
          Positioned(right: 0, child: GamepadButton(label: '◯', color: Colors.red,
              onPressed: () => onSignal('BTN_EAST', true),
              onReleased: () => onSignal('BTN_EAST', false),
          )),
          Positioned(left: 0, child: GamepadButton(label: '□', color: Colors.pinkAccent,
              onPressed: () => onSignal('BTN_WEST', true),
              onReleased: () => onSignal('BTN_WEST', false),
          )),
          Positioned(top: 0, child: GamepadButton(label: '△', color: Colors.green,
              onPressed: () => onSignal('BTN_NORTH', true),
              onReleased: () => onSignal('BTN_NORTH', false),
          )),
        ],
      ),
    );
  }
}