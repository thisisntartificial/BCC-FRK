import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ultrasonic_hearing/models/audio_analysis.dart';

void main() {
  test('AudioAnalysis.fromSamples returns empty analysis for empty input', () {
    final analysis = AudioAnalysis.fromSamples(const [], 44100);

    expect(analysis.rmsLevel, 0);
    expect(analysis.peakLevel, 0);
    expect(analysis.voiceDetected, isFalse);
    expect(analysis.waveformData, isEmpty);
  });

  test('AudioAnalysis detects energy on a sine wave', () {
    const sampleRate = 44100;
    final samples = List<double>.generate(1024, (i) {
      return sin(2 * pi * 220 * i / sampleRate) * 0.5;
    });

    final analysis = AudioAnalysis.fromSamples(samples, sampleRate);

    expect(analysis.rmsLevel, greaterThan(0.1));
    expect(analysis.peakLevel, greaterThan(0.4));
    expect(analysis.dominantFrequency, greaterThan(0));
    expect(analysis.frequencyBands.isNotEmpty, isTrue);
  });
}
