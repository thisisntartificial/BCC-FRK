import 'dart:async';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/audio_analysis.dart';
import '../utils/constants.dart';

/// Captures microphone permission and streams analyzed audio frames.
///
/// Live PCM sample piping is not wired yet; after permission is granted the
/// service emits realistic simulated frames so the UI can be developed end to
/// end. Replace [_startProcessingSimulation] with recorder amplitude/sample
/// callbacks for production capture.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<AudioAnalysis> _analysisController =
      StreamController<AudioAnalysis>.broadcast();

  Timer? _simulationTimer;
  bool _isListening = false;
  double _amplification = AudioSettings.defaultAmplification;
  bool _noiseGateEnabled = true;
  double _noiseGateThreshold = AudioSettings.noiseGateThreshold;

  bool get isListening => _isListening;
  double get amplification => _amplification;
  Stream<AudioAnalysis> get analysisStream => _analysisController.stream;

  Future<bool> startListening() async {
    if (_isListening) return true;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      return false;
    }

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/ultrasonic_live_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AudioSettings.sampleRate,
        numChannels: 1,
      ),
      path: path,
    );

    _isListening = true;
    _startProcessingSimulation();
    return true;
  }

  void _startProcessingSimulation() {
    _simulationTimer?.cancel();
    final random = Random();

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isListening) {
        _simulationTimer?.cancel();
        return;
      }

      final samples = List<double>.generate(512, (i) {
        var sample = (random.nextDouble() - 0.5) * 0.02;
        final voiceFreq = 150 + random.nextDouble() * 350;
        sample +=
            sin(2 * pi * voiceFreq * i / AudioSettings.sampleRate) *
            0.3 *
            _amplification;

        if (_noiseGateEnabled && sample.abs() < _noiseGateThreshold) {
          sample = 0;
        }
        return sample;
      });

      _analysisController.add(
        AudioAnalysis.fromSamples(samples, AudioSettings.sampleRate),
      );
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    await _recorder.stop();
    _isListening = false;
  }

  void setAmplification(double value) {
    _amplification = value.clamp(1.0, AudioSettings.amplificationMax);
  }

  void toggleNoiseGate(bool enabled) {
    _noiseGateEnabled = enabled;
  }

  void setNoiseGateThreshold(double threshold) {
    _noiseGateThreshold = threshold.clamp(0.001, 0.1);
  }

  Future<void> dispose() async {
    await stopListening();
    await _analysisController.close();
    _recorder.dispose();
  }
}
