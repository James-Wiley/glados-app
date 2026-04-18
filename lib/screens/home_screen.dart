import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/robot_comm.dart';
import '../widgets/sliders.dart';
import '../widgets/gyro.dart';
import '../widgets/animation.dart';
import '../widgets/glove.dart';
import '../widgets/glados_fx.dart';

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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F16), Color(0xFF141B26), Color(0xFF0E1320)],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 56,
                            color: Color(0xFFE5A93D),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'GLaDOS UPLINK ERROR',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            connectionError!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _retryConnection,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reinitialize Link'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () {
                              openAppSettings();
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Open System Permissions'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _bypassConnection,
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Bypass (Maintenance Mode)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0A0F15), Color(0xFF121A25)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6FE6FF)),
                const SizedBox(height: 16),
                GladosBootText(
                  text: 'Booting GLaDOS Interface...',
                  style: const TextStyle(
                    color: Color(0xFFC0D0E4),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B3E57)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory, color: Color(0xFF6FE6FF), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GENETIC LIFEFORM & DISK OPERATING SYSTEM',
                      style: TextStyle(
                        color: Color(0xFFCFDCEE),
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  PulsingStatusText(
                    text: isConnected ? 'ONLINE' : 'OFFLINE',
                    online: isConnected,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: pages[currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Manual'),
          BottomNavigationBarItem(
            icon: Icon(Icons.screen_rotation),
            label: 'Inertial',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Chamber'),
          BottomNavigationBarItem(icon: Icon(Icons.back_hand), label: 'Vision'),
        ],
      ),
    );
  }
}
