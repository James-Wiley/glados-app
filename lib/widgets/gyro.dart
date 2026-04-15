import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../utils/robot_comm.dart';

class GyroPage extends StatefulWidget {
  const GyroPage({super.key});

  @override
  State<GyroPage> createState() => _GyroPageState();
}

class _GyroPageState extends State<GyroPage> {
  final _robot = RobotArmService.instance;

  final List<double> _servoValues = [90, 90, 90, 90];
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  bool _isArmed = false;
  bool _hasAccelerometer = true;
  String? _sensorStatus;
  int _lastServoSendMs = 0;

  // These are shared by sensor callbacks and merged into one 4-servo payload.
  double _movementInput = 0.0;
  double _secondaryMovementInput = 0.0;

  @override
  void initState() {
    super.initState();
    _subscribeSensors();
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    super.dispose();
  }

  void _subscribeSensors() {
    try {
      _accelerometerSub = accelerometerEventStream().listen(
        (event) {
          // Two accelerometer axes drive Servo 1 and Servo 2.
          _movementInput = _normalizeSigned(event.x, maxAbs: 10.0);
          _secondaryMovementInput = _normalizeSigned(event.y, maxAbs: 10.0);
          _updateFromInputs();
        },
        onError: (Object error, StackTrace stackTrace) {
          _hasAccelerometer = false;
          _setSensorStatus(
            'Accelerometer not available on this device. Servos 1/2 stay centered.',
          );
          _updateFromInputs();
          _accelerometerSub?.cancel();
          _accelerometerSub = null;
        },
      );
    } on PlatformException {
      _hasAccelerometer = false;
      _setSensorStatus(
        'Accelerometer not available on this device. Servos 1/2 stay centered.',
      );
    }

    _updateFromInputs();
  }

  void _setSensorStatus(String message) {
    if (!mounted) return;
    setState(() {
      _sensorStatus = message;
    });
  }

  void _armIfNeeded() {
    if (_isArmed) return;
    setState(() {
      _isArmed = true;
    });
  }

  void _updateTouchServos(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _armIfNeeded();

    final nx = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final ny = (localPosition.dy / size.height).clamp(0.0, 1.0);

    // Servo 3 follows horizontal finger position; Servo 4 follows vertical.
    _servoValues[2] = nx * 180.0;
    _servoValues[3] = ny * 180.0;

    _sendServos();
    if (mounted) setState(() {});
  }

  void _updateFromInputs() {
    if (!_isArmed) return;

    // Servo 1: accel X, Servo 2: accel Y.
    _servoValues[0] = _hasAccelerometer ? (_movementInput + 1.0) * 90.0 : 90.0;
    _servoValues[1] = _hasAccelerometer
        ? (_secondaryMovementInput + 1.0) * 90.0
        : 90.0;

    _sendServos();
    if (mounted) setState(() {});
  }

  double _normalizeSigned(double value, {required double maxAbs}) {
    if (maxAbs <= 0) return 0;
    return (value / maxAbs).clamp(-1.0, 1.0);
  }

  Future<void> _sendServos() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastServoSendMs < 50) return;
    _lastServoSendMs = nowMs;

    await _robot.setServoAngles(_servoValues);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              _updateTouchServos(details.localPosition, size),
          onPanUpdate: (details) =>
              _updateTouchServos(details.localPosition, size),
          onTapDown: (details) =>
              _updateTouchServos(details.localPosition, size),
          child: Container(
            color: const Color(0xFFE8F0FE),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Gyro Control',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isArmed
                      ? 'Touch: Servo 3/4 | Accelerometer: Servo 1/2'
                      : 'Touch anywhere to start control',
                  style: TextStyle(
                    color: _isArmed ? Colors.green[700] : Colors.blueGrey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inputs on this device: '
                  'Accelerometer ${_hasAccelerometer ? 'available' : 'missing'}',
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_sensorStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _sensorStatus!,
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < 4; i++) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Servo ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text('${_servoValues[i].round()}°'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _servoValues[i] / 180.0,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
