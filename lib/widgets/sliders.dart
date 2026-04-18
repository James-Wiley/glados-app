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
    final titleStyle = Theme.of(context).textTheme.headlineSmall;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1018), Color(0xFF101927), Color(0xFF0E1521)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('GLaDOS JOINT COMMAND', style: titleStyle),
          const SizedBox(height: 6),
          const Text(
            'Direct motor control for chassis articulation and test posture.',
            style: TextStyle(color: Color(0xFF8FA1B7)),
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
                          style: const TextStyle(
                            color: Color(0xFFD6E1F0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2738),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2A415D)),
                          ),
                          child: Text(
                            '${_servoValues[i].round()}°',
                            style: const TextStyle(
                              color: Color(0xFF6FE6FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
              label: const Text('Reset Servos To 90 deg'),
            ),
          ),
        ],
      ),
    );
  }
}
