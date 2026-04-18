import 'package:flutter/material.dart';
import 'widgets/glados_fx.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    const labBg = Color(0xFF0B0F16);
    const panel = Color(0xFF121923);
    const cyan = Color(0xFF6FE6FF);
    const amber = Color(0xFFE5A93D);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
      primary: cyan,
      secondary: amber,
      surface: panel,
    );

    return MaterialApp(
      title: 'GLaDOS Control Interface',
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned.fill(child: GladosVisualOverlay()),
          ],
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: labBg,
        cardTheme: const CardThemeData(
          color: panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFF2A3646)),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFFE7EDF6),
            fontFamily: 'monospace',
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: Color(0xFFD9E2F0),
            fontFamily: 'monospace',
          ),
          bodyMedium: TextStyle(
            color: Color(0xFFB2C0D2),
            letterSpacing: 0.2,
            fontFamily: 'monospace',
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: labBg,
          foregroundColor: colorScheme.primary,
          elevation: 0,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: colorScheme.primary,
          inactiveTrackColor: const Color(0xFF233041),
          thumbColor: colorScheme.secondary,
          overlayColor: colorScheme.secondary.withValues(alpha: 0.15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C2A3A),
            foregroundColor: const Color(0xFFEAF3FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF2E445D)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFC9D8EA),
            side: const BorderSide(color: Color(0xFF33475E)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF121923),
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: const Color(0xFF7C8FA7),
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          unselectedLabelStyle: const TextStyle(letterSpacing: 0.4),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
