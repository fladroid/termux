// lib/services/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static final AppTheme _instance = AppTheme._internal();
  factory AppTheme() => _instance;
  AppTheme._internal();

  String _size = 'medium';
  String _contrast = 'normal';

  void init(String size, String contrast) {
    _size = size;
    _contrast = contrast;
  }

  void setSize(String size) => _size = size;
  void setContrast(String contrast) => _contrast = contrast;

  // ─── VELIČINE ─────────────────────────────────────────────

  double get symbolSize {
    switch (_size) {
      case 'small':  return 24;
      case 'large':  return 42;
      default:       return 32;
    }
  }

  double get labelSize {
    switch (_size) {
      case 'small':  return 7;
      case 'large':  return 12;
      default:       return 9;
    }
  }

  double get bodySize {
    switch (_size) {
      case 'small':  return 11;
      case 'large':  return 15;
      default:       return 13;
    }
  }

  double get captionSize {
    switch (_size) {
      case 'small':  return 9;
      case 'large':  return 13;
      default:       return 11;
    }
  }

  double get headerSize {
    switch (_size) {
      case 'small':  return 18;
      case 'large':  return 26;
      default:       return 22;
    }
  }

  double get badgeSize {
    switch (_size) {
      case 'small':  return 8;
      case 'large':  return 13;
      default:       return 10;
    }
  }

  // ─── BOJE ─────────────────────────────────────────────────

  bool get isHighContrast => _contrast == 'high';

  Color get background =>
      isHighContrast ? const Color(0xFFF0EBE0) : const Color(0xFFF5F0E8);

  Color get surface =>
      isHighContrast ? const Color(0xFFFFFFFF) : const Color(0xFFFAF7F2);

  Color get ink =>
      isHighContrast ? const Color(0xFF000000) : const Color(0xFF1A1A1A);

  Color get inkMedium =>
      isHighContrast ? const Color(0xFF2A2A2A) : const Color(0xFF4A4540);

  Color get inkLight =>
      isHighContrast ? const Color(0xFF3A3A3A) : const Color(0xFF6B6560);

  Color get inkFaint =>
      isHighContrast ? const Color(0xFF555555) : const Color(0xFFC8C0B4);

  Color get border =>
      isHighContrast ? const Color(0xFF888880) : const Color(0xFFDDD8CE);

  Color get accent => const Color(0xFF2D5A27);

  Color get accentText => Colors.white;

  Color get destructive => const Color(0xFF8B2020);

  String get size => _size;
  String get contrast => _contrast;
}
