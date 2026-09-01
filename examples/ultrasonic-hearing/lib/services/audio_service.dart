import 'dart:async';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/audio_analysis.dart';
import '../utils/constants.dart';

/// Outcome of a request to begin an analysis session.
enum StartListeningResult {
  started,
  permissionDenied,
  unavailable,
}

/// Captures microphone permission and streams analyzed audio frames.
///
/// Live PCM sample piping is not wired yet; after capture starts the service
/// emits realistic simulated frames so the UI can be developed end to end.
/// Replace [_startProcessingSimulation] with recorder sample callbacks for
/// production capture.
class AudioService {
  AudioService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final StreamController<AudioAnalysis> _analysisController =
      StreamController<AudioAnalysis>.broadcast();

  static const int _frameSize = 512;

  Timer? _simulationTimer;
  bool _isListening = false;
  bool _isDemoMode = false;
  double _amplification = AudioSettings.defaultAmplification;
  bool _noiseGateEnabled = true;
  double _noiseGateThreshold = AudioSettings.noiseGateThreshold;

  bool get isListening => _isListening;
  bool get isDemoMode => _isDemoMode;
  double get amplification => _amplification;
  Stream<AudioAnalysis> get analysisStream => _analysisController.stream;

  Future<StartListeningResult> startListening() async {
    if (_isListening) return StartListeningResult.started;

    try {
      if (!await _recorder.hasPermission()) {
        return StartListeningResult.permissionDenied;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/ultrasonic_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioSettings.sampleRate,
          numChannels: 1,
        ),
        path: path,
      );
    } on Exception {
      // No usable capture device, or the platform rejected the request.
      return StartListeningResult.unavailable;
    }

    _isListening = true;
    _isDemoMode = false;
    _startProcessingSimulation();
    return StartListeningResult.started;
  }

  /// Runs the analyzer against synthesized audio, with no capture device.
  ///
  /// Useful for previewing the interface on machines without a microphone.
  void startDemo() {
    if (_isListening) return;
    _isListening = true;
    _isDemoMode = true;
    _startProcessingSimulation();
  }

  void _startProcessingSimulation() {
    _simulationTimer?.cancel();
    final random = Random();

    // Phase is carried across frames so the synthesized tone stays continuous
    // instead of restarting each frame, which would read as broadband noise.
    var phase = 0.0;
    var fundamental = 180.0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_isListening) {
        _simulationTimer?.cancel();
        return;
      }

      // Drift the fundamental slowly through a speech-like range.
      fundamental += (random.nextDouble() - 0.5) * 30;
      fundamental = fundamental.clamp(110.0, 320.0);

      final phaseStep = 2 * pi * fundamental / AudioSettings.sampleRate;

      final samples = List<double>.generate(_frameSize, (_) {
        phase = (phase + phaseStep) % (2 * pi);

        // Fundamental plus two harmonics approximates a voiced sound.
        var sample = sin(phase) * 0.45;
        sample += sin(2 * phase) * 0.15;
        sample += sin(3 * phase) * 0.07;
        sample += (random.nextDouble() - 0.5) * 0.02;

        sample *= _amplification / AudioSettings.defaultAmplification;

        if (_noiseGateEnabled && sample.abs() < _noiseGateThreshold) {
          sample = 0;
        }

        // Clip like a real capture chain rather than exceeding full scale.
        return sample.clamp(-1.0, 1.0);
      });

      if (_analysisController.isClosed) return;
      _analysisController.add(
        AudioAnalysis.fromSamples(samples, AudioSettings.sampleRate),
      );
    });
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _isListening = false;

    if (_isDemoMode) {
      _isDemoMode = false;
      return;
    }

    try {
      await _recorder.stop();
    } on Exception {
      // Already stopped or the device disappeared; nothing to recover.
    }
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
