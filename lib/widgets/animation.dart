import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../utils/animation_data.dart';
import '../utils/app_colors.dart';
import 'animation_editor.dart';
import '../utils/robot_comm.dart';

class AnimationPage extends StatefulWidget {
  const AnimationPage({super.key});

  @override
  State<AnimationPage> createState() => _AnimationPageState();
}

class _AnimationPageState extends State<AnimationPage> {
  final RobotArmService _robot = RobotArmService.instance;
  final AnimationLibrary _library = AnimationLibrary();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SavedAnimation> _animations = [];
  bool _loading = true;
  bool _saving = false;
  bool _isPlaying = false;
  String? _activeAnimationId;
  String _statusText = 'Loading saved animations...';
  int _playbackToken = 0;
  List<double> _currentPlayingAngles = [90, 90, 90, 90];

  @override
  void initState() {
    super.initState();
    _loadAnimations();
  }

  @override
  void dispose() {
    _playbackToken++;
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAnimations() async {
    try {
      final animations = await _library.load();
      if (!mounted) {
        return;
      }

      setState(() {
        _animations = animations.isEmpty
            ? AnimationLibrary.seedAnimations()
            : animations;
        _loading = false;
        _statusText = _animations.isEmpty
            ? 'No saved animations yet.'
            : 'Loaded ${_animations.length} saved animation${_animations.length == 1 ? '' : 's'}.';
      });

      if (animations.isEmpty) {
        await _persistAnimations();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _statusText = 'Failed to load animations: $error';
        _animations = AnimationLibrary.seedAnimations();
      });
    }
  }

  Future<void> _persistAnimations() async {
    setState(() {
      _saving = true;
    });

    try {
      await _library.save(_animations);
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText =
            'Saved ${_animations.length} animation${_animations.length == 1 ? '' : 's'}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusText = 'Could not save animations: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _createAnimation() async {
    final created = await showDialog<SavedAnimation>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const AnimationEditorDialog(
              title: 'Create animation',
              initialAnimation: null,
            ),
          ),
        );
      },
    );

    if (created == null || !mounted) {
      return;
    }

    setState(() {
      _animations = [..._animations, created];
      _statusText = 'Created ${created.name}.';
    });
    await _persistAnimations();
  }

  Future<void> _editAnimation(int index) async {
    final edited = await showDialog<SavedAnimation>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: AnimationEditorDialog(
              title: 'Edit animation',
              initialAnimation: _animations[index],
            ),
          ),
        );
      },
    );

    if (edited == null || !mounted) {
      return;
    }

    setState(() {
      _animations = [
        for (
          var animationIndex = 0;
          animationIndex < _animations.length;
          animationIndex++
        )
          if (animationIndex == index) edited else _animations[animationIndex],
      ];
      _statusText = 'Updated ${edited.name}.';
    });
    await _persistAnimations();
  }

  Future<void> _deleteAnimation(int index) async {
    final animation = _animations[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete animation?'),
          content: Text('Remove "${animation.name}" from saved animations?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _animations = [
        for (
          var animationIndex = 0;
          animationIndex < _animations.length;
          animationIndex++
        )
          if (animationIndex != index) _animations[animationIndex],
      ];
      _statusText = 'Deleted ${animation.name}.';
    });
    await _persistAnimations();
  }

  Future<void> _playAnimation(SavedAnimation animation) async {
    if (_isPlaying) {
      await _stopPlayback(silent: true);
    }

    final playbackToken = ++_playbackToken;
    setState(() {
      _isPlaying = true;
      _activeAnimationId = animation.id;
      _statusText = 'Playing ${animation.name}...';
    });

    try {
      await _runAnimation(animation, playbackToken);
      await _audioPlayer.stop();
      if (!mounted || playbackToken != _playbackToken) {
        return;
      }

      setState(() {
        _isPlaying = false;
        _activeAnimationId = null;
        _statusText = 'Finished ${animation.name}.';
      });
    } catch (error) {
      await _audioPlayer.stop();
      if (!mounted || playbackToken != _playbackToken) {
        return;
      }

      setState(() {
        _isPlaying = false;
        _activeAnimationId = null;
        _statusText = 'Playback failed: $error';
      });
    }
  }

  Future<void> _stopPlayback({bool silent = false}) async {
    _playbackToken++;
    await _audioPlayer.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
      _activeAnimationId = null;
      _currentPlayingAngles = [90, 90, 90, 90];
      if (!silent) {
        _statusText = 'Playback stopped.';
      }
    });
  }

  Future<void> _runAnimation(
    SavedAnimation animation,
    int playbackToken,
  ) async {
    final waypoints = animation.sortedWaypoints;
    if (waypoints.isEmpty) {
      return;
    }

    final audioPath = animation.audioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        try {
          await _audioPlayer.stop();
          await _audioPlayer.setFilePath(audioPath);
          await _audioPlayer.play();
        } catch (error) {
          if (mounted && playbackToken == _playbackToken) {
            setState(() {
              _statusText =
                  'Audio track could not be loaded. Servo playback continues.';
            });
          }
        }
      }
    }

    await _applyServoAngles(waypoints.first.angles);
    setState(() {
      _currentPlayingAngles = waypoints.first.angles;
    });
    for (var index = 0; index < waypoints.length - 1; index++) {
      if (!_isPlaybackTokenActive(playbackToken)) {
        return;
      }

      final start = waypoints[index];
      final end = waypoints[index + 1];
      final durationMs = max(1, end.timeMs - start.timeMs);
      final frameCount = max(1, (durationMs / 50).ceil());
      final frameDelay = Duration(
        milliseconds: max(1, (durationMs / frameCount).round()),
      );

      for (var step = 1; step <= frameCount; step++) {
        if (!_isPlaybackTokenActive(playbackToken)) {
          return;
        }

        final t = step / frameCount;
        final interpolatedAngles = List<double>.generate(
          4,
          (servoIndex) =>
              _lerp(start.angles[servoIndex], end.angles[servoIndex], t),
        );

        setState(() {
          _currentPlayingAngles = interpolatedAngles;
        });
        await _applyServoAngles(interpolatedAngles);
        if (step < frameCount) {
          await Future.delayed(frameDelay);
        }
      }
    }
  }

  bool _isPlaybackTokenActive(int playbackToken) {
    return mounted && playbackToken == _playbackToken;
  }

  Future<void> _applyServoAngles(List<double> angles) async {
    final result = await _robot.setServoAngles(angles);
    if (!result.ok) {
      throw StateError(result.error ?? 'Servo command failed');
    }
  }

  double _lerp(double start, double end, double t) {
    return start + ((end - start) * t);
  }

  String _formatDurationMs(int durationMs) {
    if (durationMs < 1000) {
      return '${durationMs}ms';
    }

    final seconds = durationMs ~/ 1000;
    final remainingMs = durationMs % 1000;
    if (remainingMs == 0) {
      return '${seconds}s';
    }

    return '${seconds}.${(remainingMs / 100).round()}s';
  }

  String _formatAngles(List<double> angles) {
    return angles.map((angle) => angle.toStringAsFixed(1)).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.backgroundAlt, AppColors.backgroundDarkBottom],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundAlt, AppColors.backgroundDarkBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -40,
            child: _GlowBlob(
              color: AppColors.accentCyan.withOpacity(0.12),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _GlowBlob(
              color: const Color(0xFF7A5CFF).withOpacity(0.09),
              size: 260,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildStatusStrip(context),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _animations.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            itemCount: _animations.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final animation = _animations[index];
                              return _buildAnimationCard(
                                context,
                                animation,
                                index,
                              );
                            },
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelMedium.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.panelBorderAlt),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2636), Color(0xFF173B52)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.accentCyan.withOpacity(0.35)),
            ),
            child: const Icon(
              Icons.movie_filter_outlined,
              color: AppColors.accentCyan,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Animation studio',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Saved timelines drive all four servos and can trigger an audio track from the phone speakers.',
                  style: TextStyle(color: AppColors.textSubtle, height: 1.35),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _createAnimation,
                  icon: const Icon(Icons.add),
                  label: const Text('New animation'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.panelMedium.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorderAlt),
      ),
      child: Row(
        children: [
          const Icon(Icons.graphic_eq, color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusText,
              style: const TextStyle(color: AppColors.textSubtle),
            ),
          ),
          if (_saving) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.panelMedium.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.panelBorderAlt),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.queue_music_outlined,
                size: 52,
                color: AppColors.accentCyan,
              ),
              const SizedBox(height: 14),
              Text(
                'No animations saved yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a sequence of waypoints, attach an audio track, then press play to send the servo timeline.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSubtle, height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _createAnimation,
                icon: const Icon(Icons.add),
                label: const Text('Create first animation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimationCard(
    BuildContext context,
    SavedAnimation animation,
    int index,
  ) {
    final isActive = _activeAnimationId == animation.id && _isPlaying;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelMedium.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.accentCyan.withOpacity(0.55)
              : AppColors.panelBorderAlt,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.accentCyan.withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: AppColors.accentCyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animation.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${animation.waypoints.length} waypoint${animation.waypoints.length == 1 ? '' : 's'} · ${_formatDurationMs(animation.durationMs)}',
                        style: const TextStyle(color: AppColors.textSubtle),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        animation.audioDescription,
                        style: const TextStyle(color: AppColors.textSubtle),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isActive)
              FilledButton.icon(
                onPressed: () => _stopPlayback(),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              )
            else
              FilledButton.icon(
                onPressed: _isPlaying ? null : () => _playAnimation(animation),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  label: 'Angles',
                  value: animation.waypoints.isEmpty
                      ? 'No waypoints'
                      : (isActive
                            ? _formatAngles(_currentPlayingAngles)
                            : _formatAngles(animation.waypoints.first.angles)),
                ),
                _InfoChip(
                  label: 'Audio',
                  value: animation.hasAudio ? 'Attached' : 'None',
                ),
                _InfoChip(
                  label: 'Duration',
                  value: _formatDurationMs(animation.durationMs),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isPlaying ? null : () => _editAnimation(index),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isPlaying ? null : () => _deleteAnimation(index),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
                const Spacer(),
                Text(
                  'Servo timeline',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSubtle,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceDeep,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.textLightest,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
