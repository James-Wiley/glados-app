import 'package:flutter/material.dart';
import 'utils/app_colors.dart';
import 'widgets/glados_fx.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentCyan,
      brightness: Brightness.dark,
      primary: AppColors.accentCyan,
      secondary: AppColors.accentAmber,
      surface: AppColors.panelDark,
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
        scaffoldBackgroundColor: AppColors.backgroundDarkTop,
        cardTheme: CardThemeData(
          color: AppColors.panelDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: AppColors.panelBorderAlt),
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
            fontFamily: 'monospace',
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
            color: AppColors.textSecondary,
            fontFamily: 'monospace',
          ),
          bodyMedium: TextStyle(
            color: AppColors.textTertiary,
            letterSpacing: 0.2,
            fontFamily: 'monospace',
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.backgroundDarkTop,
          foregroundColor: colorScheme.primary,
          elevation: 0,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: colorScheme.primary,
          inactiveTrackColor: AppColors.sliderTrackInactive,
          thumbColor: colorScheme.secondary,
          overlayColor: colorScheme.secondary.withValues(alpha: 0.15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.buttonBackground,
            foregroundColor: AppColors.textLighter,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.buttonBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.buttonBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.panelDark,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: AppColors.textDim,
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
