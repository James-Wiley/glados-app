import 'package:flutter/material.dart';

class AnimationPage extends StatelessWidget {
  const AnimationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1119), Color(0xFF121B29)],
        ),
      ),
      alignment: Alignment.center,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.science_outlined,
                color: Color(0xFF6FE6FF),
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                'TEST CHAMBER SEQUENCER',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Queue scripted procedures and compliance cycles for subject trials.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9FB1C8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
