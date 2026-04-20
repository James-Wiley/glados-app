import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_detection/hand_detection.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../utils/app_colors.dart';
import '../utils/robot_comm.dart';

class GlovePage extends StatefulWidget {
  const GlovePage({super.key});

  @override
  State<GlovePage> createState() => _GlovePageState();
}

class _GlovePageState extends State<GlovePage> {
  final _robot = RobotArmService.instance;
  CameraController? _cameraController;
  HandDetectorIsolate? _detector;
  bool _busy = false;
  bool _ready = false;
  String? _error;
  int _quarterTurns = 0;
  bool _mirrorPreview = false;
  int _handQuarterTurns = 0;
  bool _mirrorHand = false;

  Size? _imageSize;
  Hand? _hand;
  Map<String, double> _curls = const {};

  int _frameCounter = 0;
  int _lastServoSentMs = 0;
  static const int _frameSkip = 2; // process every 2nd frame

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    try {
      _detector = await HandDetectorIsolate.spawn(
        mode: HandMode.boxesAndLandmarks,
        landmarkModel: HandLandmarkModel.full,
        maxDetections: 1,
        detectorConf: 0.6,
        minLandmarkScore: 0.5,
        performanceConfig: const PerformanceConfig.xnnpack(),
      );

      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'No camera found');
        return;
      }

      final cam = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      _quarterTurns = ((cam.sensorOrientation / 90).round() + 3) % 4;
      _mirrorPreview = cam.lensDirection == CameraLensDirection.front;

      _cameraController = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onFrame);

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Init failed: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    _frameCounter++;
    if (_frameCounter % _frameSkip != 0) return;
    if (_busy || !_ready || _detector == null) return;

    _busy = true;
    try {
      cv.Mat? mat = await _cameraImageToBgrMat(image);
      if (mat == null) return;

      // Reduce bandwidth/cost.
      const maxDim = 640;
      if (mat.cols > maxDim || mat.rows > maxDim) {
        final s = maxDim / math.max(mat.cols, mat.rows);
        final resized = cv.resize(mat, (
          (mat.cols * s).toInt(),
          (mat.rows * s).toInt(),
        ), interpolation: cv.INTER_LINEAR);
        mat.dispose();
        mat = resized;
      }

      final hands = await _detector!.detectHandsFromMat(mat);
      final imgSize = Size(mat.cols.toDouble(), mat.rows.toDouble());
      mat.dispose();

      if (!mounted) return;
      if (hands.isNotEmpty) {
        final first = hands.first;
        final curls = _computeFingerCurls(first);
        setState(() {
          _hand = first;
          _imageSize = imgSize;
          _curls = curls;
        });
        _sendFingerCurlsToServos(curls);
      } else {
        setState(() {
          _hand = null;
          _curls = const {};
          _imageSize = imgSize;
        });
      }
    } catch (_) {
      // no-op
    } finally {
      _busy = false;
    }
  }

  Future<cv.Mat?> _cameraImageToBgrMat(CameraImage image) async {
    try {
      final width = image.width;
      final height = image.height;

      // Desktop packed 4-channel (Linux/macOS camera plugins).
      if (image.planes.length == 1 &&
          (image.planes[0].bytesPerPixel ?? 1) >= 4) {
        final bytes = image.planes[0].bytes;
        final stride = image.planes[0].bytesPerRow;
        final cols = stride ~/ 4;

        final src = cv.Mat.fromList(height, cols, cv.MatType.CV_8UC4, bytes);
        final crop = cols != width
            ? src.region(cv.Rect(0, 0, width, height))
            : src;

        final code = Platform.isMacOS ? cv.COLOR_BGRA2BGR : cv.COLOR_RGBA2BGR;
        final bgr = cv.cvtColor(crop, code);

        if (!identical(crop, src)) crop.dispose();
        src.dispose();
        return bgr;
      }

      // Mobile YUV420 -> BGR
      final yRowStride = image.planes[0].bytesPerRow;
      final yPixelStride = image.planes[0].bytesPerPixel ?? 1;
      final out = Uint8List(width * height * 3);

      void writePixel(int x, int y, int yp, int up, int vp) {
        final r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        final g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        final b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        final i = (y * width + x) * 3;
        out[i] = b;
        out[i + 1] = g;
        out[i + 2] = r;
      }

      if (image.planes.length == 2) {
        // NV12
        final uvRowStride = image.planes[1].bytesPerRow;
        final uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final yIndex = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[yIndex],
              image.planes[1].bytes[uvIndex],
              image.planes[1].bytes[uvIndex + 1],
            );
          }
        }
      } else if (image.planes.length >= 3) {
        // I420
        final uvRowStride = image.planes[1].bytesPerRow;
        final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
            final yIndex = y * yRowStride + x * yPixelStride;
            writePixel(
              x,
              y,
              image.planes[0].bytes[yIndex],
              image.planes[1].bytes[uvIndex],
              image.planes[2].bytes[uvIndex],
            );
          }
        }
      } else {
        return null;
      }

      return cv.Mat.fromList(height, width, cv.MatType.CV_8UC3, out);
    } catch (_) {
      return null;
    }
  }

  Map<String, double> _computeFingerCurls(Hand hand) {
    HandLandmark? lm(int idx) {
      for (final l in hand.landmarks) {
        if (l.type.index == idx) return l;
      }
      return null;
    }

    double curlFrom(int a, int b, int c) {
      final p1 = lm(a), p2 = lm(b), p3 = lm(c);
      if (p1 == null || p2 == null || p3 == null) return 0;
      if (p1.visibility < 0.5 || p2.visibility < 0.5 || p3.visibility < 0.5) {
        return 0;
      }

      final angle = _angleDeg(
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        Offset(p3.x, p3.y),
      );

      // 180° = straight, ~60° = curled.
      return ((180 - angle) / 120).clamp(0.0, 1.0);
    }

    return {
      'thumb': curlFrom(1, 2, 4),
      'index': curlFrom(5, 6, 8),
      'middle': curlFrom(9, 10, 12),
      'ring': curlFrom(13, 14, 16),
      'pinky': curlFrom(17, 18, 20),
    };
  }

  double _angleDeg(Offset a, Offset b, Offset c) {
    final ab = a - b;
    final cb = c - b;
    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final mag =
        (math.sqrt(ab.dx * ab.dx + ab.dy * ab.dy) *
                math.sqrt(cb.dx * cb.dx + cb.dy * cb.dy))
            .clamp(1e-6, double.infinity);
    final cosv = (dot / mag).clamp(-1.0, 1.0);
    return math.acos(cosv) * 180 / math.pi;
  }

  double _curlToServoAngle(double curl) {
    final normalized = curl.clamp(0.0, 1.0);
    return normalized * 180.0;
  }

  Future<void> _sendFingerCurlsToServos(Map<String, double> curls) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastServoSentMs < 80) return;
    _lastServoSentMs = nowMs;

    final angles = <double>[
      _curlToServoAngle(curls['index'] ?? 0),
      _curlToServoAngle(curls['middle'] ?? 0),
      _curlToServoAngle(curls['ring'] ?? 0),
      _curlToServoAngle(curls['pinky'] ?? 0),
    ];

    await _robot.setServoAngles(angles);
  }

  void _rotateLeft() {
    setState(() => _quarterTurns = (_quarterTurns + 3) % 4);
  }

  void _rotateRight() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _toggleMirror() {
    setState(() => _mirrorPreview = !_mirrorPreview);
  }

  void _resetView() {
    final cam = _cameraController?.description;
    if (cam == null) return;
    setState(() {
      _quarterTurns = ((cam.sensorOrientation / 90).round() + 3) % 4;
      _mirrorPreview = cam.lensDirection == CameraLensDirection.front;
    });
  }

  void _rotateHandLeft() {
    setState(() => _handQuarterTurns = (_handQuarterTurns + 3) % 4);
  }

  void _rotateHandRight() {
    setState(() => _handQuarterTurns = (_handQuarterTurns + 1) % 4);
  }

  void _toggleHandMirror() {
    setState(() => _mirrorHand = !_mirrorHand);
  }

  void _resetHandView() {
    setState(() {
      _handQuarterTurns = 0;
      _mirrorHand = false;
    });
  }

  @override
  void dispose() {
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _cameraController?.dispose();
    _detector?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (!_ready ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _cameraController!.value.previewSize?.width ?? 1000,
                height:
                    _cameraController!.value.previewSize?.height ??
                    1000 / _cameraController!.value.aspectRatio,
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: Transform.scale(
                    scaleX: _mirrorPreview ? -1 : 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        if (_hand != null && _imageSize != null)
                          Transform.scale(
                            alignment: Alignment.center,
                            scaleX: _mirrorHand ? -1 : 1,
                            child: Transform.rotate(
                              alignment: Alignment.center,
                              angle: _handQuarterTurns * math.pi / 2,
                              child: CustomPaint(
                                painter: _OneHandPainter(
                                  hand: _hand!,
                                  imageSize: _imageSize!,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _ControlTag(label: 'Optics'),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.rotate_left,
                      tooltip: 'Rotate camera left',
                      onPressed: _rotateLeft,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.rotate_right,
                      tooltip: 'Rotate camera right',
                      onPressed: _rotateRight,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.flip,
                      tooltip: 'Mirror camera',
                      onPressed: _toggleMirror,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.restart_alt,
                      tooltip: 'Reset camera',
                      onPressed: _resetView,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _ControlTag(label: 'Manipulator'),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.rotate_left,
                      tooltip: 'Rotate hand left',
                      onPressed: _rotateHandLeft,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.rotate_right,
                      tooltip: 'Rotate hand right',
                      onPressed: _rotateHandRight,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.flip,
                      tooltip: 'Mirror hand',
                      onPressed: _toggleHandMirror,
                    ),
                    const SizedBox(width: 8),
                    _ViewControlButton(
                      icon: Icons.restart_alt,
                      tooltip: 'Reset hand',
                      onPressed: _resetHandView,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _curls.isEmpty
                    ? 'No test subject tracked'
                    : 'Thumb actuator ${(100 * _curls['thumb']!).toStringAsFixed(0)}%  |  '
                          'Index actuator ${(100 * _curls['index']!).toStringAsFixed(0)}%  |  '
                          'Middle actuator ${(100 * _curls['middle']!).toStringAsFixed(0)}%  |  '
                          'Ring actuator ${(100 * _curls['ring']!).toStringAsFixed(0)}%  |  '
                          'Pinky actuator ${(100 * _curls['pinky']!).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.textLightest,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ViewControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelDark.withOpacity(0.8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.accentCyan),
          ),
        ),
      ),
    );
  }
}

class _ControlTag extends StatelessWidget {
  final String label;

  const _ControlTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.panelMedium.withOpacity(0.8),
        border: Border.all(color: AppColors.panelBorderAlt),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textLightest,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OneHandPainter extends CustomPainter {
  final Hand hand;
  final Size imageSize;

  _OneHandPainter({required this.hand, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;

    final line = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final dot = Paint()..color = Colors.redAccent;

    for (final c in handLandmarkConnections) {
      final a = hand.getLandmark(c[0]);
      final b = hand.getLandmark(c[1]);
      if (a == null || b == null) continue;
      if (a.visibility < 0.5 || b.visibility < 0.5) continue;
      canvas.drawLine(
        Offset(a.x * sx, a.y * sy),
        Offset(b.x * sx, b.y * sy),
        line,
      );
    }

    for (final l in hand.landmarks) {
      if (l.visibility < 0.5) continue;
      canvas.drawCircle(Offset(l.x * sx, l.y * sy), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _OneHandPainter oldDelegate) => true;
}
