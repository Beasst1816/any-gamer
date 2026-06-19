import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class GamepadButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const GamepadButton({
    Key? key,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.onReleased,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: () => onReleased(),
      child: Container(
        width: 60.w, // Scales proportionally
        height: 60.h,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.w),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}