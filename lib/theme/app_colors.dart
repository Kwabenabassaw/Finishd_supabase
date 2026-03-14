import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand Colors
  static const primary = Color(0xFF00E676); // Brighter, more vibrant green
  static const primaryDark = Color(0xFF00C853);
  static const primaryLight = Color(0xFF69F0AE);

  // Status & Accents
  static const progressGreen = Color(0xFF1DB954);
  static const error = Color(0xFFFF4B4B);
  static const warning = Color(0xFFFFB74D);
  static const info = Color(0xFF4FC3F7);
  static const success = Color(0xFF81C784);

  // Backgrounds
  static const backgroundLight = Colors.white;
  static const backgroundDark = Color(0xFF121212); // True dark mode base
  static const surfaceLight = Color(0xFFF8F9FA);
  static const surfaceDark = Color(0xFF1E1E1E); // Elevated surfaces in dark mode

  // Typography - Light Theme
  static const textDark = Color(0xFF0F172A); // Slate-900 for better contrast
  static const textGray = Color(0xFF475569); // Slate-600
  static const textLightGray = Color(0xFF94A3B8); // Slate-400

  // Typography - Dark Theme
  static const textWhite = Color(0xFFF8FAFC); // Slate-50
  static const textDarkGray = Color(0xFFCBD5E1); // Slate-300
  static const textDarkMuted = Color(0xFF64748B); // Slate-500

  // UI Elements
  static const cardGrayLight = Color(0xFFF1F5F9); // Slate-100
  static const cardGrayDark = Color(0xFF1E293B); // Slate-800
  static const borderGrayLight = Color(0xFFE2E8F0); // Slate-200
  static const borderGrayDark = Color(0xFF334155); // Slate-700
  
  // Specific Use Cases
  static const messageBubbleSent = Color(0xFF00E676);
  static const messageBubbleReceivedLight = Color(0xFFF1F5F9);
  static const messageBubbleReceivedDark = Color(0xFF1E293B);
  static const unreadBadge = Color(0xFFFF4B4B); // Vibrant red for attention
}
