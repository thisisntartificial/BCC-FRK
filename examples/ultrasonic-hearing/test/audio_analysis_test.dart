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

  test('dominant frequency tracks the tone that produced the samples', () {
    const sampleRate = 44100;
    const toneHz = 220.0;
    final samples = List<double>.generate(4096, (i) {
      return sin(2 * pi * toneHz * i / sampleRate) * 0.5;
    });

    final analysis = AudioAnalysis.fromSamples(samples, sampleRate);

    expect(analysis.dominantFrequency, closeTo(toneHz, toneHz * 0.1));
  });

  test('a speech-range tone is reported within audible band limits', () {
    const sampleRate = 44100;
    final samples = List<double>.generate(4096, (i) {
      return sin(2 * pi * 200 * i / sampleRate) * 0.5;
    });

    final analysis = AudioAnalysis.fromSamples(samples, sampleRate);

    expect(analysis.voiceDetected, isTrue);
    expect(analysis.rmsLevel, lessThanOrEqualTo(1.0));

    final activeBands = analysis.frequencyBands.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();
    expect(activeBands, contains('Bass'));
  });
}
