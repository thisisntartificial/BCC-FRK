import 'dart:math';

import '../utils/constants.dart';

class AudioAnalysis {
  final List<double> waveformData;
  final double rmsLevel;
  final double peakLevel;
  final double dominantFrequency;
  final Map<String, double> frequencyBands;
  final bool voiceDetected;
  final double signalToNoiseRatio;
  final DateTime timestamp;

  const AudioAnalysis({
    required this.waveformData,
    required this.rmsLevel,
    required this.peakLevel,
    required this.dominantFrequency,
    required this.frequencyBands,
    required this.voiceDetected,
    required this.signalToNoiseRatio,
    required this.timestamp,
  });

  factory AudioAnalysis.fromSamples(List<double> samples, int sampleRate) {
    if (samples.isEmpty) {
      return AudioAnalysis(
        waveformData: const [],
        rmsLevel: 0,
        peakLevel: 0,
        dominantFrequency: 0,
        frequencyBands: const {},
        voiceDetected: false,
        signalToNoiseRatio: 0,
        timestamp: DateTime.now(),
      );
    }

    final rms = _calculateRMS(samples);
    final peak = samples.map((s) => s.abs()).reduce(max);
    final dominantFreq = _calculateDominantFrequency(samples, sampleRate);
    final bands = _calculateFrequencyBands(samples, sampleRate);
    final voiceDetected =
        rms > 0.01 && dominantFreq > 80 && dominantFreq < 1000;
    final noiseFloor = _calculateNoiseFloor(samples);
    final snr = noiseFloor > 0 ? 20 * log(rms / noiseFloor) / ln10 : 0.0;

    return AudioAnalysis(
      waveformData: samples.take(200).toList(),
      rmsLevel: rms,
      peakLevel: peak,
      dominantFrequency: dominantFreq,
      frequencyBands: bands,
      voiceDetected: voiceDetected,
      signalToNoiseRatio: snr,
      timestamp: DateTime.now(),
    );
  }

  static double _calculateRMS(List<double> samples) {
    if (samples.isEmpty) return 0;
    final sumSquares = samples.map((s) => s * s).reduce((a, b) => a + b);
    return sqrt(sumSquares / samples.length);
  }

  static double _calculateDominantFrequency(
    List<double> samples,
    int sampleRate,
  ) {
    var zeroCrossings = 0;
    for (var i = 1; i < samples.length; i++) {
      final crossed =
          (samples[i - 1] >= 0 && samples[i] < 0) ||
          (samples[i - 1] < 0 && samples[i] >= 0);
      if (crossed) zeroCrossings++;
    }
    final duration = samples.length / sampleRate;
    if (duration == 0) return 0;
    return zeroCrossings / (2 * duration);
  }

  static Map<String, double> _calculateFrequencyBands(
    List<double> samples,
    int sampleRate,
  ) {
    final bands = <String, double>{};
    final dominantFreq = _calculateDominantFrequency(samples, sampleRate);

    for (final band in FrequencyBands.bands.entries) {
      final low = band.value[0];
      final high = band.value[1];
      bands[band.key] =
          (dominantFreq >= low && dominantFreq <= high) ? 1.0 : 0.0;
    }

    return bands;
  }

  static double _calculateNoiseFloor(List<double> samples) {
    if (samples.length < 10) return 0.001;
    final sorted = List<double>.from(samples.map((s) => s.abs()))..sort();
    final noiseFloor = sorted[sorted.length ~/ 10];
    return noiseFloor > 0 ? noiseFloor : 0.001;
  }
}
