import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../utils/animation_data.dart';
import '../utils/app_colors.dart';
import '../utils/robot_comm.dart';
import 'audio_timeline.dart';

class AnimationEditorDialog extends StatefulWidget {
  const AnimationEditorDialog({
    super.key,
    required this.title,
    required this.initialAnimation,
  });

  final String title;
  final SavedAnimation? initialAnimation;

  @override
  State<AnimationEditorDialog> createState() => _AnimationEditorDialogState();
}

class _AnimationEditorDialogState extends State<AnimationEditorDialog> {
  final _nameController = TextEditingController();
  final _timeController = TextEditingController();

  final List<double> _servoValues = List<double>.filled(4, 90.0);
  final List<WaypointDraft> _waypoints = [];
  String? _audioPath;
  int? _editingWaypointIndex;
  final _robot = RobotArmService.instance;
  bool _isSendingServo = false;

  @override
  void initState() {
    super.initState();
    final initialAnimation = widget.initialAnimation;
    _nameController.text = initialAnimation?.name ?? '';
    _audioPath = initialAnimation?.audioPath;
    _timeController.text = '0';

    if (initialAnimation != null) {
      for (final waypoint in initialAnimation.sortedWaypoints) {
        _waypoints.add(WaypointDraft.fromWaypoint(waypoint));
      }

      if (_waypoints.isNotEmpty) {
        _editingWaypointIndex = 0;
        _populateEditorFromWaypoint(_waypoints.first);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _populateEditorFromWaypoint(WaypointDraft waypoint) {
    _timeController.text = waypoint.timeMs.toString();
    for (var index = 0; index < 4; index++) {
      _servoValues[index] = waypoint.angles[index];
    }
  }

  void _loadWaypoint(int index) {
    setState(() {
      _editingWaypointIndex = index;
      _populateEditorFromWaypoint(_waypoints[index]);
    });
  }

  void _resetWaypointEditor() {
    setState(() {
      _editingWaypointIndex = null;
      _timeController.text = '0';
      for (var index = 0; index < 4; index++) {
        _servoValues[index] = 90.0;
      }
    });
  }

  void _addOrUpdateWaypoint() {
    final parsedTime = int.tryParse(_timeController.text.trim());
    if (parsedTime == null || parsedTime < 0) {
      _showMessage('Enter a valid waypoint time in milliseconds.');
      return;
    }

    final draft = WaypointDraft(
      id: _editingWaypointIndex != null
          ? _waypoints[_editingWaypointIndex!].id
          : DateTime.now().microsecondsSinceEpoch.toString(),
      timeMs: parsedTime,
      angles: List<double>.from(_servoValues),
    );

    setState(() {
      if (_editingWaypointIndex != null) {
        _waypoints[_editingWaypointIndex!] = draft;
      } else {
        _waypoints.add(draft);
      }

      _waypoints.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      _editingWaypointIndex = null;
    });

    _showMessage('Waypoint saved. Tap a row to edit it later.');
  }

  void _removeWaypoint(int index) {
    final removed = _waypoints.removeAt(index);
    setState(() {
      if (_editingWaypointIndex == index) {
        _editingWaypointIndex = null;
        _timeController.text = '0';
        for (var servoIndex = 0; servoIndex < 4; servoIndex++) {
          _servoValues[servoIndex] = 90.0;
        }
      } else if (_editingWaypointIndex != null &&
          _editingWaypointIndex! > index) {
        _editingWaypointIndex = _editingWaypointIndex! - 1;
      }
    });

    _showMessage('Removed waypoint at ${removed.timeMs}ms.');
  }

  Future<void> _pickAudioTrack() async {
    final result = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      _showMessage(
        'The selected audio file does not expose a local path on this platform.',
      );
      return;
    }

    setState(() {
      _audioPath = selectedPath;
    });
  }

  void _clearAudioTrack() {
    setState(() {
      _audioPath = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  List<double> _getInterpolatedAnglesAtTime(int timeMs) {
    // If no waypoints, default to 90 degrees
    if (_waypoints.isEmpty) {
      return List<double>.filled(4, 90.0);
    }

    // Sort waypoints by time to find surrounding ones
    final sorted = List<WaypointDraft>.from(_waypoints)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    // If requested time is before first waypoint, use first waypoint's angles
    if (timeMs <= sorted.first.timeMs) {
      return List<double>.from(sorted.first.angles);
    }

    // If requested time is after last waypoint, use last waypoint's angles
    if (timeMs >= sorted.last.timeMs) {
      return List<double>.from(sorted.last.angles);
    }

    // Find the two waypoints that bracket this time
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];

      if (timeMs >= start.timeMs && timeMs <= end.timeMs) {
        // Linear interpolation between start and end
        final durationMs = end.timeMs - start.timeMs;
        final t = (timeMs - start.timeMs) / durationMs;

        return List<double>.generate(
          4,
          (servoIndex) =>
              start.angles[servoIndex] +
              ((end.angles[servoIndex] - start.angles[servoIndex]) * t),
        );
      }
    }

    // Fallback to 90 degrees
    return List<double>.filled(4, 90.0);
  }

  Future<void> _sendServoValues() async {
    setState(() {
      _isSendingServo = true;
    });
    try {
      final result = await _robot.setServoAngles(_servoValues);
      if (result.ok) {
        _showMessage('Servo values sent to robot!');
      } else {
        _showMessage('Error sending to robot: ${result.error}');
      }
    } catch (e) {
      _showMessage('Exception sending servo values: $e');
    } finally {
      setState(() {
        _isSendingServo = false;
      });
    }
  }

  void _saveAnimation() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Give the animation a name.');
      return;
    }

    if (_waypoints.isEmpty) {
      _showMessage('Add at least one waypoint before saving.');
      return;
    }

    final savedAnimation = SavedAnimation(
      id:
          widget.initialAnimation?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      audioPath: _audioPath,
      waypoints: [
        for (final waypoint in _waypoints)
          AnimationWaypoint(timeMs: waypoint.timeMs, angles: waypoint.angles),
      ],
    );

    Navigator.of(context).pop(savedAnimation);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelDark,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: AppColors.accentCyan.withOpacity(0.12),
                    ),
                    child: const Icon(Icons.tune, color: AppColors.accentCyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _EditorSection(
                title: 'Animation details',
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Animation name',
                        hintText: 'Enter a label for this sequence',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _audioPath == null
                              ? 'No audio track selected'
                              : 'Audio track: ${_displayNameForPath(_audioPath!)}',
                          style: const TextStyle(
                            color: AppColors.textSubtleAlt,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _pickAudioTrack,
                              icon: const Icon(Icons.library_music_outlined),
                              label: const Text('Choose audio'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _audioPath == null
                                  ? null
                                  : _clearAudioTrack,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_audioPath != null)
                AudioTimeline(
                  audioPath: _audioPath!,
                  waypoints: _waypoints,
                  onWaypointTap: (waypoint) {
                    _loadWaypoint(_waypoints.indexOf(waypoint));
                  },
                  onTimelineSeek: (timeMs) {
                    _timeController.text = timeMs.toString();
                  },
                  onAddWaypoint: (timeMs) {
                    final interpolatedAngles = _getInterpolatedAnglesAtTime(
                      timeMs,
                    );
                    final draft = WaypointDraft(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      timeMs: timeMs,
                      angles: interpolatedAngles,
                    );
                    setState(() {
                      _waypoints.add(draft);
                      _waypoints.sort((a, b) => a.timeMs.compareTo(b.timeMs));
                    });
                    _showMessage(
                      'Waypoint added at ${timeMs}ms with interpolated servo angles: ${interpolatedAngles.map((a) => a.toStringAsFixed(1)).join(", ")}°.',
                    );
                  },
                  onPositionChanged: (timeMs) {
                    if (_editingWaypointIndex == null) {
                      _timeController.text = timeMs.toString();
                    }
                  },
                ),
              if (_audioPath != null) const SizedBox(height: 16),
              _EditorSection(
                title: 'Waypoint editor',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _timeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Waypoint time (ms)',
                              hintText: '0',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: _addOrUpdateWaypoint,
                              icon: Icon(
                                _editingWaypointIndex == null
                                    ? Icons.add
                                    : Icons.save,
                              ),
                              label: Text(
                                _editingWaypointIndex == null
                                    ? 'Add waypoint'
                                    : 'Update waypoint',
                              ),
                            ),
                            if (_editingWaypointIndex != null) ...[
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () {
                                  _removeWaypoint(_editingWaypointIndex!);
                                  _resetWaypointEditor();
                                },
                                icon: const Icon(Icons.delete),
                                label: const Text('Delete'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (_editingWaypointIndex != null) ...[
                      const SizedBox(height: 18),
                      ...List.generate(4, (servoIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Servo ${servoIndex + 1}: ${_servoValues[servoIndex].round()}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Slider(
                                value: _servoValues[servoIndex],
                                min: 0,
                                max: 180,
                                divisions: 180,
                                onChanged: (value) {
                                  setState(() {
                                    _servoValues[servoIndex] = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSendingServo ? null : _sendServoValues,
                        icon: const Icon(Icons.send),
                        label: const Text('Send to robot'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _EditorSection(
                title: 'Saved waypoints',
                child: _waypoints.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No waypoints yet. Add one from the editor above.',
                          style: TextStyle(color: AppColors.textSubtleAlt),
                        ),
                      )
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < _waypoints.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () => _loadWaypoint(index),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceDark,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.panelBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: const Color(
                                            0xFF6FE6FF,
                                          ).withOpacity(0.12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: AppColors.accentCyan,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_waypoints[index].timeMs} ms',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _waypoints[index].angles
                                                  .map(
                                                    (angle) => angle
                                                        .round()
                                                        .toString(),
                                                  )
                                                  .join(' · '),
                                              style: const TextStyle(
                                                color: AppColors.textSubtleAlt,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeWaypoint(index),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_editingWaypointIndex != null) ...[
                    TextButton(
                      onPressed: _resetWaypointEditor,
                      child: const Text('Reset waypoint inputs'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _saveAnimation,
                        icon: const Icon(Icons.save),
                        label: const Text('Save animation'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayNameForPath(String path) {
    return path.split('/').last;
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
