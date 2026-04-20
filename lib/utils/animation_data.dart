import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AnimationLibrary {
  static const _storageFileName = 'saved_animations.json';

  Future<File> _storageFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_storageFileName');
  }

  Future<List<SavedAnimation>> load() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        return [];
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['animations'] is List) {
        final list = decoded['animations'] as List<dynamic>;
        return list
            .map(
              (entry) => SavedAnimation.fromJson(entry as Map<String, dynamic>),
            )
            .toList();
      }

      if (decoded is List) {
        return decoded
            .map(
              (entry) => SavedAnimation.fromJson(entry as Map<String, dynamic>),
            )
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<SavedAnimation> animations) async {
    final file = await _storageFile();
    await file.create(recursive: true);
    final payload = {
      'version': 1,
      'animations': animations.map((animation) => animation.toJson()).toList(),
    };
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(payload));
  }

  static List<SavedAnimation> seedAnimations() {
    return [
      SavedAnimation(
        id: 'intro-wave',
        name: 'Intro Wave',
        audioPath: null,
        waypoints: const [
          AnimationWaypoint(timeMs: 0, angles: [90.0, 90.0, 90.0, 90.0]),
          AnimationWaypoint(timeMs: 800, angles: [110.0, 70.0, 110.0, 70.0]),
          AnimationWaypoint(timeMs: 1600, angles: [70.0, 110.0, 70.0, 110.0]),
          AnimationWaypoint(timeMs: 2400, angles: [90.0, 90.0, 90.0, 90.0]),
        ],
      ),
    ];
  }
}

class SavedAnimation {
  const SavedAnimation({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.waypoints,
  });

  final String id;
  final String name;
  final String? audioPath;
  final List<AnimationWaypoint> waypoints;

  List<AnimationWaypoint> get sortedWaypoints {
    final sorted = [...waypoints]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return sorted;
  }

  int get durationMs {
    if (waypoints.isEmpty) {
      return 0;
    }

    return sortedWaypoints.last.timeMs;
  }

  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  String get audioDescription {
    if (!hasAudio) {
      return 'Audio track: none';
    }

    return 'Audio track: ${audioPath!.split('/').last}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'audioPath': audioPath,
      'waypoints': waypoints.map((waypoint) => waypoint.toJson()).toList(),
    };
  }

  factory SavedAnimation.fromJson(Map<String, dynamic> json) {
    return SavedAnimation(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Untitled animation',
      audioPath: json['audioPath'] as String?,
      waypoints: (json['waypoints'] as List<dynamic>? ?? const [])
          .map(
            (entry) =>
                AnimationWaypoint.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AnimationWaypoint {
  const AnimationWaypoint({required this.timeMs, required this.angles});

  final int timeMs;
  final List<double> angles;

  Map<String, dynamic> toJson() {
    return {'timeMs': timeMs, 'angles': angles};
  }

  factory AnimationWaypoint.fromJson(Map<String, dynamic> json) {
    return AnimationWaypoint(
      timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
      angles:
          (json['angles'] as List<dynamic>? ?? const [90.0, 90.0, 90.0, 90.0])
              .map((angle) => (angle as num).toDouble())
              .toList(),
    );
  }
}

class WaypointDraft {
  WaypointDraft({required this.id, required this.timeMs, required this.angles});

  final String id;
  final int timeMs;
  final List<double> angles;

  factory WaypointDraft.fromWaypoint(AnimationWaypoint waypoint) {
    return WaypointDraft(
      id: '${waypoint.timeMs}-${waypoint.angles.hashCode}',
      timeMs: waypoint.timeMs,
      angles: List<double>.from(waypoint.angles),
    );
  }
}
