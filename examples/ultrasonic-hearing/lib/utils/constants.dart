import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0F0A);
  static const primary = Color(0xFF00E676);
  static const secondary = Color(0xFF00B0FF);
  static const warning = Color(0xFFFFB300);
  static const danger = Color(0xFFFF1744);
  static const surface = Color(0xFF12181A);
  static const cardBg = Color(0xFF0F1415);
  static const textPrimary = Color(0xFFE0E0E0);
  static const textSecondary = Color(0xFF888888);
  static const waveformColor = Color(0xFF00E676);
}

class AudioSettings {
  static const int sampleRate = 44100;
  static const int bufferSize = 2048;
  static const double noiseGateThreshold = 0.01;
  static const double amplificationMax = 10.0;
  static const double defaultAmplification = 3.0;
}

class FrequencyBands {
  static const Map<String, List<double>> bands = {
    'Sub Bass': [20, 60],
    'Bass': [60, 250],
    'Low Mid': [250, 500],
    'Mid': [500, 2000],
    'High Mid': [2000, 4000],
    'Presence': [4000, 6000],
    'Brilliance': [6000, 20000],
  };
}
