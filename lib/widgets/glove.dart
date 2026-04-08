import 'package:flutter/material.dart';
// https://pub.dev/packages/hand_detection

class GlovePage extends StatelessWidget {
  const GlovePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6E8FF),
      alignment: Alignment.center,
      child: const Text(
        'Glove Page',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }
}
