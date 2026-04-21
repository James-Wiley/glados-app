import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// GATT UUIDs — must match bt_node.py on the Pi
class RobotUuids {
  static const service = '12345678-1234-5678-1234-56789abcdef0';
  static const servoCmd = '12345678-1234-5678-1234-56789abcdef1';
  static const rgbLed = '12345678-1234-5678-1234-56789abcdef2';
  static const status = '12345678-1234-5678-1234-56789abcdef3';
}

// Result wrapper — avoids throwing across async boundaries
class RobotResult<T> {
  final T? value;
  final String? error;
  bool get ok => error == null;

  const RobotResult.success(this.value) : error = null;
  const RobotResult.failure(this.error) : value = null;
}

// RobotArmService
/// Singleton service that manages the BLE connection to the robot arm.
///
/// Usage:
///   final robot = RobotArmService.instance;
///   await robot.connect(device);          // connect once
///   await robot.setServoAngles([90, 45, 120, 10]);
///   await robot.setLed(r: 255, g: 0, b: 128);
///   print(robot.isConnected);
class RobotArmService {
  RobotArmService._();
  static final instance = RobotArmService._();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _servoChar;
  BluetoothCharacteristic? _ledChar;
  BluetoothCharacteristic? _statusChar;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  // Publicly observable connection state
  final _connectedController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;
  bool _connected = false;
  bool _bypassMode = false;
  String _lastScanDebugSummary = 'No scan results captured yet.';

  // ── 1. Connectivity ────────────────────────────────────────────────────────

  String _normalizeUuid(String uuid) {
    return uuid.toLowerCase().replaceAll('-', '');
  }

  Future<String> _permissionDiagnostics() async {
    if (!Platform.isAndroid) {
      return 'platform=non-android';
    }

    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final location = await Permission.locationWhenInUse.status;
    final locationGeneral = await Permission.location.status;
    final locationService = await Permission.locationWhenInUse.serviceStatus;
    final adapterState = await FlutterBluePlus.adapterState.first;

    return 'adapter=$adapterState, '
        'bluetoothScan=$scan, '
        'bluetoothConnect=$connect, '
        'locationWhenInUse=$location, '
        'location=$locationGeneral, '
        'locationService=$locationService';
  }

  /// Returns true if the BLE link is currently up and characteristics
  /// are resolved.
  bool get isConnected => _connected && _device != null;

  /// Returns true if robot connection was bypassed (all commands do nothing).
  bool get isConnectionBypassed => _bypassMode;

  /// Request required Bluetooth permissions (Android 12+).
  Future<RobotResult<void>> _requestBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return const RobotResult.success(null);
    }

    final requiredPermissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];
    final optionalPermissions = [
      // Helpful for BLE scan visibility on some Android versions/devices.
      Permission.locationWhenInUse,
      Permission.location,
    ];

    final requiredResults = await requiredPermissions.request();
    for (final permission in requiredPermissions) {
      if (requiredResults[permission] != PermissionStatus.granted) {
        final diag = await _permissionDiagnostics();
        return RobotResult.failure(
          'Bluetooth permission denied: ${permission.toString()}. '
          'Permission diagnostics: $diag',
        );
      }
    }

    // Request optional permissions too, but do not block connection on denial.
    await optionalPermissions.request();

    return const RobotResult.success(null);
  }

  /// Request all app permissions needed for BLE workflow.
  /// Call this at app startup to prompt the user immediately.
  Future<RobotResult<void>> ensurePermissions() async {
    return _requestBluetoothPermissions();
  }

  Future<String> permissionDebugStatus() async {
    return _permissionDiagnostics();
  }

  /// Scans for a device advertising [RobotUuids.service], connects, and
  /// discovers characteristics.  Call this once from your connection screen.
  ///
  /// [timeout] – how long to scan before giving up (default 10 s).
  Future<RobotResult<void>> connect({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Request Bluetooth permissions
      final permResult = await _requestBluetoothPermissions();
      if (!permResult.ok) {
        return permResult;
      }

      // Make sure BT adapter is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return const RobotResult.failure('Bluetooth is off');
      }

      // Scan with service filtering first, then fallback to unfiltered scan.
      // Some Android stacks report no results when service filtering is used.
      BluetoothDevice? found;
      final targetUuids = <String>{
        _normalizeUuid(RobotUuids.service),
        _normalizeUuid(RobotUuids.servoCmd),
        _normalizeUuid(RobotUuids.rgbLed),
        _normalizeUuid(RobotUuids.status),
      };
      final debugLines = <String>[];

      Future<void> runScan({required bool filtered}) async {
        final scanSub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final deviceName = r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : (r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : 'unknown');
            final rawUuids = r.advertisementData.serviceUuids
                .map((u) => u.toString())
                .toList();
            final uuids = r.advertisementData.serviceUuids
                .map((u) => _normalizeUuid(u.toString()))
                .toList();

            final debugLine =
                'scan(${filtered ? 'filtered' : 'unfiltered'}) '
                'device=$deviceName id=${r.device.remoteId} services=$rawUuids';
            debugLines.add(debugLine);
            print(debugLine);

            // Match if any of the target UUIDs are found
            if (uuids.any((uuid) => targetUuids.contains(uuid))) {
              found = r.device;
              FlutterBluePlus.stopScan();
              break;
            }
          }
        });

        if (filtered) {
          await FlutterBluePlus.startScan(
            withServices: [Guid(RobotUuids.service)],
            timeout: timeout,
          );
        } else {
          await FlutterBluePlus.startScan(timeout: timeout);
        }
        await scanSub.cancel();
      }

      await runScan(filtered: true);
      if (found == null) {
        await runScan(filtered: false);
      }
      _lastScanDebugSummary = debugLines.isEmpty
          ? 'No scan results were reported during the scan window.'
          : debugLines.join('\n');

      if (found == null) {
        return RobotResult.failure(
          'Robot arm not found nearby. '
          'Expected service: ${RobotUuids.service}. '
          'If this is Android, verify Location is turned ON in system settings. '
          'Observed scan results:\n$_lastScanDebugSummary',
        );
      }

      _device = found;
      await _device!.connect(license: License.free, autoConnect: false);

      // Watch for disconnects
      _connSub = _device!.connectionState.listen((state) {
        final up = state == BluetoothConnectionState.connected;
        _connected = up;
        _connectedController.add(up);
        if (!up) _clearCharacteristics();
      });

      // Discover services
      final services = await _device!.discoverServices();
      final robotService = services.firstWhere(
        (s) =>
            s.serviceUuid.toString().toLowerCase() ==
            RobotUuids.service.toLowerCase(),
        orElse: () => throw Exception('Robot service not found on device'),
      );

      for (final c in robotService.characteristics) {
        final uuid = c.characteristicUuid.toString().toLowerCase();
        if (uuid == RobotUuids.servoCmd.toLowerCase()) _servoChar = c;
        if (uuid == RobotUuids.rgbLed.toLowerCase()) _ledChar = c;
        if (uuid == RobotUuids.status.toLowerCase()) _statusChar = c;
      }

      if (_servoChar == null || _ledChar == null) {
        return const RobotResult.failure('Required characteristics missing');
      }

      // Subscribe to status notifications
      if (_statusChar != null) {
        await _statusChar!.setNotifyValue(true);
      }

      _connected = true;
      _connectedController.add(true);
      return const RobotResult.success(null);
    } catch (e) {
      return RobotResult.failure(e.toString());
    }
  }

  /// Gracefully disconnects and cleans up.
  Future<void> disconnect() async {
    await _connSub?.cancel();
    _clearCharacteristics();
    await _device?.disconnect();
    _device = null;
    _connected = false;
    _bypassMode = false;
    _connectedController.add(false);
  }

  /// Bypass the robot connection. All commands will succeed but do nothing.
  /// Useful for testing the UI without a physical robot.
  void bypassConnection() {
    _bypassMode = true;
    _connected = true;
    _connectedController.add(true);
  }

  /// Stream of status JSON maps pushed by the robot at 1 Hz.
  /// e.g. {"connected": true, "servos": [90.0, 45.0, 120.0, 10.0]}
  Stream<Map<String, dynamic>> get statusStream {
    if (_statusChar == null) return const Stream.empty();
    return _statusChar!.onValueReceived.map((bytes) {
      final json = utf8.decode(bytes);
      return jsonDecode(json) as Map<String, dynamic>;
    });
  }

  // ── 2. Servo angles ────────────────────────────────────────────────────────

  /// Sends target angles for all 4 servos.
  ///
  /// [angles] – list of exactly 4 values in degrees (0 to 180).
  /// [speeds] – optional list of 4 speed scalars (0.0–1.0, default 1.0).
  ///
  /// Example:
  ///   await robot.setServoAngles([90, 45, 120, 10]);
  ///   await robot.setServoAngles([45, 90, 135, 180]);
  Future<RobotResult<void>> setServoAngles(
    List<double> angles, {
    List<double> speeds = const [1.0, 1.0, 1.0, 1.0],
  }) async {
    assert(angles.length == 4, 'angles must have exactly 4 elements');
    assert(speeds.length == 4, 'speeds must have exactly 4 elements');

    // In bypass mode, succeed silently
    if (_bypassMode) {
      print(
        '[RobotArm] BYPASS MODE: Would send angles=$angles, speeds=$speeds',
      );
      return const RobotResult.success(null);
    }

    if (!isConnected || _servoChar == null) {
      print('[RobotArm] NOT CONNECTED: angles=$angles');
      return const RobotResult.failure('Not connected');
    }

    // Clamp angles to the supported range.
    final clamped = angles.map((a) => a.clamp(0.0, 180.0)).toList();
    final clampedSpeeds = speeds.map((s) => s.clamp(0.0, 1.0)).toList();

    final payload = jsonEncode({'angles': clamped, 'speeds': clampedSpeeds});
    print('[RobotArm] Sending servo command: $payload');

    try {
      await _servoChar!.write(
        utf8.encode(payload),
        withoutResponse: _servoChar!.properties.writeWithoutResponse,
      );
      print('[RobotArm] Servo command sent successfully');
      return const RobotResult.success(null);
    } catch (e) {
      print('[RobotArm] Servo write failed: $e');
      return RobotResult.failure('Servo write failed: $e');
    }
  }

  // ── 3. LED colour ──────────────────────────────────────────────────────────

  /// Sets the WS2812B NeoPixel colour.
  ///
  /// [r], [g], [b] – channel values 0–255.
  ///
  /// Example:
  ///   await robot.setLed(r: 255, g: 0, b: 0);   // red
  ///   await robot.setLed(r: 0, g: 0, b: 0);     // off
  Future<RobotResult<void>> setLed({
    required int r,
    required int g,
    required int b,
  }) async {
    // In bypass mode, succeed silently
    if (_bypassMode) {
      return const RobotResult.success(null);
    }

    if (!isConnected || _ledChar == null) {
      return const RobotResult.failure('Not connected');
    }

    final payload = jsonEncode({
      'r': r.clamp(0, 255),
      'g': g.clamp(0, 255),
      'b': b.clamp(0, 255),
    });

    try {
      await _ledChar!.write(
        utf8.encode(payload),
        withoutResponse: _ledChar!.properties.writeWithoutResponse,
      );
      return const RobotResult.success(null);
    } catch (e) {
      return RobotResult.failure('LED write failed: $e');
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _clearCharacteristics() {
    _servoChar = null;
    _ledChar = null;
    _statusChar = null;
  }

  void dispose() {
    _connSub?.cancel();
    _connectedController.close();
  }
}
