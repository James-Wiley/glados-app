import 'package:flutter/material.dart';

class GyroPage extends StatelessWidget {
  const GyroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F0FE),
      alignment: Alignment.center,
      child: const Text(
        'Gyro Page',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }
}
