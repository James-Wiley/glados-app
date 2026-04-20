import 'package:flutter/material.dart';

/// Centralized color constants for the GLaDOS Controller application.
/// All colors used across the app are defined here for consistency.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ── Background Colors ──────────────────────────────────────────────────────
  static const Color backgroundDarkTop = Color(0xFF0B0F16);
  static const Color backgroundDarkBottom = Color(0xFF111B28);
  static const Color backgroundAlt = Color(0xFF0B111A);

  // ── Panel & Surface Colors ─────────────────────────────────────────────────
  static const Color panelDark = Color(0xFF121923);
  static const Color panelMedium = Color(0xFF131D2B);
  static const Color panelBorder = Color(0xFF223247);
  static const Color panelBorderAlt = Color(0xFF26364A);
  static const Color surfaceDark = Color(0xFF0E1622);
  static const Color surfaceAlt = Color(0xFF0A0F1A);
  static const Color surfaceDeep = Color(0xFF0F1723);

  // ── Primary Accent - Cyan ──────────────────────────────────────────────────
  static const Color accentCyan = Color(0xFF6FE6FF);
  static const Color accentCyanDim = Color(0xFF4A9FB5);

  // ── Secondary Accent - Amber/Gold ─────────────────────────────────────────
  static const Color accentAmber = Color(0xFFE5A93D);
  static const Color accentGold = Color(0xFFFFD700);

  // ── Tertiary Accent - Green ────────────────────────────────────────────────
  static const Color accentGreen = Color(0xFF67E4A8);

  // ── Text Colors ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE7EDF6);
  static const Color textSecondary = Color(0xFFD9E2F0);
  static const Color textTertiary = Color(0xFFB2C0D2);
  static const Color textSubtle = Color(0xFF9FB1C8);
  static const Color textSubtleAlt = Color(0xFFB5C6DA);
  static const Color textDim = Color(0xFF8CA1BA);
  static const Color textLight = Color(0xFFC0D0E4);
  static const Color textLighter = Color(0xFFD6E1F0);
  static const Color textLightest = Color(0xFFD5E3F5);

  // ── Interactive Element Colors ────────────────────────────────────────────
  static const Color buttonBackground = Color(0xFF1C2A3A);
  static const Color buttonBorder = Color(0xFF2E445D);
  static const Color sliderTrackInactive = Color(0xFF233041);
  static const Color sliderTrackActive = accentCyan;
  static const Color sliderThumb = accentAmber;

  // ── Status & State Colors ──────────────────────────────────────────────────
  static const Color errorRed = Color(0xFFE53935);
  static const Color successGreen = accentGreen;
  static const Color warningYellow = accentGold;

  // ── Timeline & UI Specific ────────────────────────────────────────────────
  static const Color timelineBackground = surfaceAlt;
  static const Color timelineTrack = panelBorder;
  static const Color timelinePlayhead = accentCyan;
  static const Color timelineWaypoint = accentGold;
}
