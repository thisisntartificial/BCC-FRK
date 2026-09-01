import 'dart:math';

/// Lightweight voice-band emphasis helpers for clarity scoring.
class VoiceIsolationService {
  List<double> isolateVoice(List<double> samples, int sampleRate) {
    if (samples.isEmpty) return samples;

    final isolated = List<double>.from(samples);
    const windowSize = 5;

    for (var i = 0; i < isolated.length; i++) {
      var sum = 0.0;
      var count = 0;
      final start = max(0, i - windowSize ~/ 2);
      final end = min(isolated.length, i + windowSize ~/ 2);
      for (var j = start; j < end; j++) {
        sum += isolated[j];
        count++;
      }
      isolated[i] = count > 0 ? sum / count : isolated[i];
    }

    return isolated;
  }

  double calculateClarityScore(List<double> samples, int sampleRate) {
    if (samples.isEmpty) return 0;

    final rms = sqrt(
      samples.map((s) => s * s).reduce((a, b) => a + b) / samples.length,
    );

    return (rms * 100).clamp(0, 100);
  }
}
