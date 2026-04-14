import 'package:flutter/material.dart';

import '../utils/robot_comm.dart';

class SlidersPage extends StatefulWidget {
  const SlidersPage({super.key});

  @override
  State<SlidersPage> createState() => _SlidersPageState();
}

class _SlidersPageState extends State<SlidersPage> {
  final List<double> _servoValues = [90, 90, 90, 90];
  final robot = RobotArmService.instance;

  void _onServoChanged(int index, double value) {
    setState(() {
      _servoValues[index] = value;
    });

    // Send all servo angles via RobotArmService
    robot.setServoAngles(_servoValues);
  }

  void _resetAllServos() {
    setState(() {
      for (int i = 0; i < _servoValues.length; i++) {
        _servoValues[i] = 90;
      }
    });

    robot.setServoAngles(_servoValues);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE6F4F1),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Servo Controls',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 4; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Servo ${i + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text('${_servoValues[i].round()}°'),
                      ],
                    ),
                    Slider(
                      value: _servoValues[i],
                      min: 0,
                      max: 180,
                      divisions: 180,
                      label: _servoValues[i].round().toString(),
                      onChanged: (value) => _onServoChanged(i, value),
                    ),
                  ],
                ),
              ),
            ),
            if (i < 3) const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _resetAllServos,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset All To 90°'),
            ),
          ),
        ],
      ),
    );
  }
}
