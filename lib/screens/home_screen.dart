import 'package:flutter/material.dart';
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
  bool isConnected = false;
  bool bypassConnection = false; // flip this for testing
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    waitForConnection();
  }

  Future<void> waitForConnection() async {
    if (bypassConnection) {
      setState(() => isConnected = true);
      return;
    }

    while (!isConnected) {
      bool result = await checkConnection();
      if (result) {
        setState(() => isConnected = true);
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<bool> checkConnection() async {
    // TODO: implement bluetooth connection check
    return false;
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
