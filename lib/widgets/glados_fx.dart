import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class GladosVisualOverlay extends StatefulWidget {
  const GladosVisualOverlay({super.key});

  @override
  State<GladosVisualOverlay> createState() => _GladosVisualOverlayState();
}

class _GladosVisualOverlayState extends State<GladosVisualOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: 0.22,
            child: CustomPaint(
              painter: _LabOverlayPainter(phase: _controller.value),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _LabOverlayPainter extends CustomPainter {
  final double phase;

  const _LabOverlayPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final scan = Paint()
      ..color = AppColors.accentCyan.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final jitter = (phase * 6).floor() % 6;
    for (double y = jitter.toDouble(); y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }

    final sweepY = (size.height * phase) % size.height;
    final sweep = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x00000000),
          Color.lerp(
            Colors.transparent,
            AppColors.accentCyan,
            0.5,
          )!.withAlpha(136),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, sweepY - 12, size.width, 24));
    canvas.drawRect(Rect.fromLTWH(0, sweepY - 12, size.width, 24), sweep);

    final noise = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 22.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final n = _hash(x, y, phase);
        if (n > 0.72) {
          canvas.drawCircle(
            Offset(x + (n * step * 0.7), y + (((1 - n) * step * 0.7))),
            0.9,
            noise,
          );
        }
      }
    }
  }

  double _hash(double x, double y, double t) {
    final value = math.sin((x * 12.9898) + (y * 78.233) + (t * 437.5453));
    return value - value.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _LabOverlayPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

class GladosBootText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const GladosBootText({super.key, required this.text, this.style});

  @override
  State<GladosBootText> createState() => _GladosBootTextState();
}

class _GladosBootTextState extends State<GladosBootText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        const TextStyle(
          color: AppColors.textLight,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final charCount = (widget.text.length * progress).floor().clamp(
          1,
          widget.text.length,
        );
        final visible = widget.text.substring(0, charCount);
        final flicker = 0.85 + (math.sin(progress * math.pi * 12) * 0.12);

        return Opacity(
          opacity: flicker.clamp(0.65, 1.0),
          child: Text(visible, style: style),
        );
      },
    );
  }
}

class PulsingStatusText extends StatefulWidget {
  final String text;
  final bool online;

  const PulsingStatusText({
    super.key,
    required this.text,
    required this.online,
  });

  @override
  State<PulsingStatusText> createState() => _PulsingStatusTextState();
}

class _PulsingStatusTextState extends State<PulsingStatusText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final intensity = widget.online
            ? _controller.value
            : 1 - _controller.value;
        final color = Color.lerp(
          widget.online ? const Color(0xFF3A6A54) : const Color(0xFF6E4D2A),
          widget.online ? AppColors.accentGreen : AppColors.accentAmber,
          intensity,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (color ?? AppColors.accentGreen).withValues(
                      alpha: 0.55,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              widget.text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.7,
              ),
            ),
          ],
        );
      },
    );
  }
}
