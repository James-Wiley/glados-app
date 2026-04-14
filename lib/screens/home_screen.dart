import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/robot_comm.dart';
import '../widgets/sliders.dart';
import '../widgets/gyro.dart';
import '../widgets/animation.dart';
import '../widgets/glove.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final robot = RobotArmService.instance;
  bool isConnected = false;
  String? connectionError;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    // Listen to connection state from RobotArmService
    robot.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
        if (connected) connectionError = null;
      });
    });

    // Ask for all required permissions immediately at startup.
    final permissionResult = await robot.ensurePermissions();
    if (!permissionResult.ok) {
      if (mounted) {
        setState(() => connectionError = permissionResult.error);
      }
      return;
    }

    // Attempt initial connection
    final result = await robot.connect();
    if (!result.ok) {
      if (mounted) {
        setState(() => connectionError = result.error);
      }
    } else {
      if (mounted) {
        setState(() => connectionError = null);
      }
    }
  }

  Future<void> _retryConnection() async {
    setState(() => connectionError = null);

    final permissionResult = await robot.ensurePermissions();
    if (!permissionResult.ok) {
      if (mounted) {
        setState(() => connectionError = permissionResult.error);
      }
      return;
    }

    final result = await robot.connect();
    if (!result.ok) {
      if (mounted) {
        setState(() => connectionError = result.error);
      }
    }
  }

  void _bypassConnection() {
    robot.bypassConnection();
    setState(() {
      isConnected = true;
      connectionError = null;
    });
  }

  @override
  void dispose() {
    robot.dispose();
    super.dispose();
  }

  final List<Widget> pages = const [
    SlidersPage(),
    GyroPage(),
    AnimationPage(),
    GlovePage(),
  ];

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
      if (connectionError != null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Connection Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    connectionError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _retryConnection,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      openAppSettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open App Settings'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _bypassConnection,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Bypass (Test Mode)'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return const Scaffold(
        body: Center(child: Text('Waiting for robot connection...')),
      );
    }

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Sliders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.screen_rotation),
            label: 'Gyro',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Animation'),
          BottomNavigationBarItem(icon: Icon(Icons.back_hand), label: 'Glove'),
        ],
      ),
    );
  }
}
