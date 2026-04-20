import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/animation_data.dart';
import '../utils/app_colors.dart';

class AudioTimeline extends StatefulWidget {
  const AudioTimeline({
    super.key,
    required this.audioPath,
    required this.waypoints,
    required this.onWaypointTap,
    required this.onTimelineSeek,
    required this.onAddWaypoint,
    required this.onPositionChanged,
  });

  final String audioPath;
  final List<WaypointDraft> waypoints;
  final Function(WaypointDraft) onWaypointTap;
  final Function(int) onTimelineSeek;
  final Function(int) onAddWaypoint;
  final Function(int) onPositionChanged;

  @override
  State<AudioTimeline> createState() => _AudioTimelineState();
}

class _AudioTimelineState extends State<AudioTimeline> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isSeeking = false;
  Timer? _positionUpdateTimer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioPlayer.setFilePath(widget.audioPath);

      _positionSub = _audioPlayer.positionStream.listen((position) {
        if (!_isSeeking && mounted) {
          setState(() {
            _currentPosition = position;
          });
          widget.onPositionChanged(position.inMilliseconds);
        }
      });

      _durationSub = _audioPlayer.durationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
          if (state.playing) {
            _startPositionUpdateTimer();
          } else {
            _stopPositionUpdateTimer();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('Error loading audio: $e')));
      }
    }
  }

  @override
  void dispose() {
    _stopPositionUpdateTimer();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) {
      if (_isPlaying && !_isSeeking) {
        setState(() {
          _currentPosition = _audioPlayer.position;
        });
        widget.onPositionChanged(_currentPosition.inMilliseconds);
      }
    });
  }

  void _stopPositionUpdateTimer() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _addWaypointAtCurrentTime() {
    final timeMs = _currentPosition.inMilliseconds;
    widget.onAddWaypoint(timeMs);
  }

  void _seekToPosition(double pixels, double maxPixels) {
    if (_duration.inMilliseconds == 0) return;

    final progress = (pixels / maxPixels).clamp(0.0, 1.0);
    final seekMs = (progress * _duration.inMilliseconds).toInt();

    setState(() {
      _isSeeking = true;
    });

    _audioPlayer.seek(Duration(milliseconds: seekMs)).then((_) {
      setState(() {
        _currentPosition = Duration(milliseconds: seekMs);
        _isSeeking = false;
      });
      widget.onTimelineSeek(seekMs);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audio Timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          // Playback controls
          Row(
            children: [
              FilledButton.icon(
                onPressed: _togglePlayPause,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'Pause' : 'Play'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addWaypointAtCurrentTime,
                icon: const Icon(Icons.add),
                label: const Text('Add Waypoint'),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatDuration(_currentPosition)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                  color: AppColors.textSubtleAlt,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timeline scrubber
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox == null) return;

              final timelineWidth =
                  renderBox.size.width - 32; // Account for padding
              final tapPosition =
                  details.globalPosition.dx -
                  renderBox.globalToLocal(Offset.zero).dx -
                  16;

              _seekToPosition(tapPosition, timelineWidth);
            },
            onTapDown: (details) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox == null) return;

              final timelineWidth = renderBox.size.width - 32;
              final tapPosition =
                  details.globalPosition.dx -
                  renderBox.globalToLocal(Offset.zero).dx -
                  16;

              _seekToPosition(tapPosition, timelineWidth);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Column(
                children: [
                  // Main timeline
                  SizedBox(
                    height: 80,
                    child: CustomPaint(
                      painter: TimelinePainter(
                        currentPosition: _currentPosition.inMilliseconds,
                        duration: _duration.inMilliseconds,
                        waypoints: widget.waypoints,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Waypoint list
                  if (widget.waypoints.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Waypoints (${widget.waypoints.length})',
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(
                                widget.waypoints.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () {
                                      _audioPlayer.seek(
                                        Duration(
                                          milliseconds:
                                              widget.waypoints[index].timeMs,
                                        ),
                                      );
                                      widget.onWaypointTap(
                                        widget.waypoints[index],
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF6FE6FF,
                                        ).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              _currentPosition.inMilliseconds >=
                                                      widget
                                                              .waypoints[index]
                                                              .timeMs -
                                                          100 &&
                                                  _currentPosition
                                                          .inMilliseconds <=
                                                      widget
                                                              .waypoints[index]
                                                              .timeMs +
                                                          100
                                              ? AppColors.accentCyan
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: AppColors.accentCyan,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(
                                              Duration(
                                                milliseconds: widget
                                                    .waypoints[index]
                                                    .timeMs,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color: AppColors.textSubtleAlt,
                                              fontSize: 10,
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
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.currentPosition,
    required this.duration,
    required this.waypoints,
  });

  final int currentPosition;
  final int duration;
  final List<WaypointDraft> waypoints;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.surfaceAlt,
    );

    // Timeline track
    const trackHeight = 6.0;
    final trackY = size.height / 2 - trackHeight / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, trackY, size.width, trackHeight),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.panelBorder,
    );

    // Progress bar
    if (duration > 0) {
      final progress = (currentPosition / duration).clamp(0.0, 1.0);
      final progressWidth = progress * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, trackY, progressWidth, trackHeight),
          const Radius.circular(3),
        ),
        Paint()..color = AppColors.accentCyan,
      );
    }

    // Waypoint markers
    for (final waypoint in waypoints) {
      if (duration > 0) {
        final waypointProgress = (waypoint.timeMs / duration).clamp(0.0, 1.0);
        final waypointX = waypointProgress * size.width;

        // Diamond shape marker
        canvas.drawCircle(
          Offset(waypointX, size.height / 2),
          5,
          Paint()..color = AppColors.accentGold,
        );

        // Larger outer circle
        canvas.drawCircle(
          Offset(waypointX, size.height / 2),
          7,
          Paint()
            ..color = AppColors.accentGold.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    // Playhead line
    if (duration > 0) {
      final progress = (currentPosition / duration).clamp(0.0, 1.0);
      final playheadX = progress * size.width;
      canvas.drawLine(
        Offset(playheadX, 0),
        Offset(playheadX, size.height),
        Paint()
          ..color = AppColors.accentCyan
          ..strokeWidth = 2,
      );

      // Playhead circle at top
      canvas.drawCircle(
        Offset(playheadX, 8),
        5,
        Paint()..color = AppColors.accentCyan,
      );
    }

    // Time labels
    const labelStyle = TextStyle(color: AppColors.textSubtleAlt, fontSize: 10);
    var textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Start time label
    textPainter.text = const TextSpan(text: '0:00', style: labelStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, size.height - 16));

    // End time label
    final endTimeMinutes = duration ~/ 60000;
    final endTimeSeconds = (duration % 60000) ~/ 1000;
    final endTimeText =
        '$endTimeMinutes:${endTimeSeconds.toString().padLeft(2, '0')}';
    textPainter.text = TextSpan(text: endTimeText, style: labelStyle);
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - textPainter.width, size.height - 16),
    );
  }

  @override
  bool shouldRepaint(TimelinePainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
        oldDelegate.duration != duration ||
        oldDelegate.waypoints != waypoints;
  }
}
