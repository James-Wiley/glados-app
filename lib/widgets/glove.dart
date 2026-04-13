import 'package:flutter/material.dart';
// https://pub.dev/packages/hand_detection

class GlovePage extends StatefulWidget {
  const GlovePage({super.key});

  @override
  State<GlovePage> createState() => _GlovePageState();
}

class _GlovePageState extends State<GlovePage> {
  double _thumbCurl = 1.0;
  double _indexCurl = 1.0;
  double _middleCurl = 1.0;
  double _ringCurl = 1.0;

  String _robotCommand = 'Idle';

  /// Call this from the hand_detection callback.
  /// Expected curl values: 0.0 = straight, 1.0 = fully curled.
  void updateFingerCurls({
    required double thumb,
    required double index,
    required double middle,
    required double ring,
  }) {
    final t = thumb.clamp(0.0, 1.0).toDouble();
    final i = index.clamp(0.0, 1.0).toDouble();
    final m = middle.clamp(0.0, 1.0).toDouble();
    final r = ring.clamp(0.0, 1.0).toDouble();

    setState(() {
      _thumbCurl = t;
      _indexCurl = i;
      _middleCurl = m;
      _ringCurl = r;
      _robotCommand = _buildRobotCommand();
    });
  }

  String _buildRobotCommand() {
    // More straight = more movement.
    final forward = 1.0 - _indexCurl;
    final reverse = 1.0 - _middleCurl;
    final left = 1.0 - _thumbCurl;
    final right = 1.0 - _ringCurl;

    final throttle = forward - reverse;
    final steering = right - left;

    if ((_thumbCurl + _indexCurl + _middleCurl + _ringCurl) / 4.0 > 0.92) {
      return 'STOP';
    }

    if (throttle.abs() < 0.15 && steering.abs() < 0.15) {
      return 'HOLD';
    }

    final direction = throttle > 0.15
        ? 'FORWARD'
        : throttle < -0.15
        ? 'REVERSE'
        : 'NEUTRAL';

    final turn = steering > 0.15
        ? 'RIGHT'
        : steering < -0.15
        ? 'LEFT'
        : 'STRAIGHT';

    return '$direction / $turn';
  }

  Widget _fingerTile(String label, double curl) {
    final percent = (curl * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$percent% curled'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6E8FF),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Glove Control',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wire hand_detection output into updateFingerCurls(...)',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _fingerTile('Thumb', _thumbCurl),
              _fingerTile('Index', _indexCurl),
              _fingerTile('Middle', _middleCurl),
              _fingerTile('Ring', _ringCurl),
              const SizedBox(height: 16),
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Robot command',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _robotCommand,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
