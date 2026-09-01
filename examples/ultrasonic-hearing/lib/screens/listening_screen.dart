import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../models/audio_analysis.dart';
import '../services/audio_service.dart';
import '../services/session_recorder.dart';
import '../utils/constants.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/event_log.dart';
import '../widgets/frequency_analyzer.dart';
import '../widgets/signal_meter.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final AudioService _audioService = AudioService();
  final SessionRecorder _sessionRecorder = SessionRecorder();

  StreamSubscription<AudioAnalysis>? _analysisSubscription;
  AudioAnalysis? _currentAnalysis;
  bool _isListening = false;
  bool _isDemoMode = false;
  bool _isRecording = false;
  double _amplification = AudioSettings.defaultAmplification;
  bool _noiseGateEnabled = true;
  final List<String> _eventLog = [];
  double _clarityScore = 0;
  bool _voiceActive = false;
  DateTime? _lastVoiceLog;

  static const Duration _voiceLogInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _analysisSubscription = _audioService.analysisStream.listen(_onAudioAnalysis);
  }

  void _onAudioAnalysis(AudioAnalysis analysis) {
    if (!mounted) return;
    setState(() {
      _currentAnalysis = analysis;
      // Map a useful SNR span (0-40 dB) onto the 0-100 clarity scale so the
      // readout does not saturate as soon as any signal is present.
      _clarityScore = (analysis.signalToNoiseRatio / 40 * 100).clamp(0, 100);
    });

    if (_isListening) {
      _logVoiceActivity(analysis);
    }
  }

  /// Records speech transitions only, so 20 frames per second of analysis do
  /// not bury the log in duplicate entries.
  void _logVoiceActivity(AudioAnalysis analysis) {
    final now = DateTime.now();

    if (!analysis.voiceDetected) {
      if (_voiceActive) {
        _voiceActive = false;
        _addToLog('Speech-like energy ended');
      }
      return;
    }

    if (!_voiceActive) {
      _voiceActive = true;
      _lastVoiceLog = now;
      _addToLog(
        'Speech-like energy — ${analysis.dominantFrequency.toStringAsFixed(0)} Hz',
      );
      return;
    }

    final since = _lastVoiceLog == null
        ? _voiceLogInterval
        : now.difference(_lastVoiceLog!);
    if (since >= _voiceLogInterval) {
      _lastVoiceLog = now;
      _addToLog(
        'Speech-like energy — ${analysis.dominantFrequency.toStringAsFixed(0)} Hz',
      );
    }
  }

  void _addToLog(String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _eventLog.insert(0, '[$timeStr] $message');
      if (_eventLog.length > 50) _eventLog.removeLast();
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _audioService.stopListening();
      setState(() {
        _isListening = false;
        _isDemoMode = false;
        _currentAnalysis = null;
        _voiceActive = false;
        _lastVoiceLog = null;
      });
      _addToLog('Listening stopped');
      return;
    }

    final result = await _audioService.startListening();
    if (!mounted) return;

    switch (result) {
      case StartListeningResult.permissionDenied:
        _showMessage('Microphone permission is required to listen.');
        _addToLog('Microphone permission denied');
        return;
      case StartListeningResult.unavailable:
        _showMessage(
          'No microphone available. Use Demo to preview the analyzer.',
        );
        _addToLog('No capture device available');
        return;
      case StartListeningResult.started:
        break;
    }

    setState(() {
      _isListening = true;
      _isDemoMode = false;
    });
    _addToLog('Listening started');
    await _pulse();
  }

  void _startDemo() {
    if (_isListening) return;
    _audioService.startDemo();
    setState(() {
      _isListening = true;
      _isDemoMode = true;
    });
    _addToLog('Demo mode started (synthesized audio)');
  }

  Future<void> _pulse() async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (canVibrate) {
        await Vibration.vibrate(duration: 100);
      }
    } on Exception {
      // Haptics are optional; ignore unsupported platforms.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _sessionRecorder.stopRecording();
      setState(() => _isRecording = false);
      _addToLog('Recording saved');
      return;
    }

    await _sessionRecorder.startRecording();
    setState(() => _isRecording = true);
    _addToLog('Recording started');
  }

  void _adjustAmplification(double value) {
    setState(() => _amplification = value);
    _audioService.setAmplification(value);
  }

  void _toggleNoiseGate(bool value) {
    setState(() => _noiseGateEnabled = value);
    _audioService.toggleNoiseGate(value);
    _addToLog(value ? 'Noise gate enabled' : 'Noise gate disabled');
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    _audioService.dispose();
    _sessionRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'ULTRASONIC HEARING',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isListening
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isListening
                              ? (_isDemoMode ? 'DEMO' : 'LISTENING')
                              : 'STANDBY',
                          style: TextStyle(
                            color: _isListening
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.danger),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REC',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _currentAnalysis != null && _isListening
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SignalMeter(
                            signalLevel:
                                _currentAnalysis!.rmsLevel.clamp(0.0, 1.0),
                            clarityScore: _clarityScore,
                            isActive: _isListening,
                          ),
                          const SizedBox(height: 20),
                          AudioVisualizer(
                            waveformData: _currentAnalysis!.waveformData,
                            isActive: _isListening,
                          ),
                          const SizedBox(height: 20),
                          FrequencyAnalyzer(
                            frequencyBands: _currentAnalysis!.frequencyBands,
                            dominantFrequency:
                                _currentAnalysis!.dominantFrequency,
                          ),
                          const SizedBox(height: 20),
                          _buildDetailsCard(),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hearing_disabled,
                            size: 80,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tap LISTEN to begin',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _startDemo,
                            child: const Text(
                              'No microphone? Run demo',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_isListening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EventLog(events: _eventLog),
              ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final analysis = _currentAnalysis!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.surface),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildDetailItem(
                'Peak Level',
                '${(analysis.peakLevel * 100).toStringAsFixed(1)}%',
              ),
              _buildDetailItem(
                'RMS',
                '${(analysis.rmsLevel * 100).toStringAsFixed(1)}%',
              ),
              _buildDetailItem(
                'SNR',
                '${analysis.signalToNoiseRatio.toStringAsFixed(1)} dB',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDetailItem(
                'Dominant Freq',
                '${analysis.dominantFrequency.toStringAsFixed(0)} Hz',
              ),
              _buildDetailItem(
                'Speech',
                analysis.voiceDetected ? 'LIKELY' : 'NONE',
              ),
              _buildDetailItem(
                'Clarity',
                '${_clarityScore.toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.surface)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.volume_down,
                color: AppColors.textSecondary,
                size: 20,
              ),
              Expanded(
                child: Slider(
                  value: _amplification,
                  min: 1.0,
                  max: AudioSettings.amplificationMax,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surface,
                  onChanged: _adjustAmplification,
                ),
              ),
              const Icon(
                Icons.volume_up,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 38,
                child: Text(
                  '${_amplification.toStringAsFixed(1)}x',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(
                child: Text(
                  'Noise Gate',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Switch(
                value: _noiseGateEnabled,
                onChanged: _toggleNoiseGate,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  icon: _isRecording ? Icons.stop : Icons.fiber_manual_record,
                  label: _isRecording ? 'STOP REC' : 'RECORD',
                  color: _isRecording ? AppColors.danger : AppColors.warning,
                  onPressed: _toggleRecording,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildControlButton(
                  icon: _isListening ? Icons.stop : Icons.hearing,
                  label: _isListening ? 'STOP' : 'LISTEN',
                  color: _isListening ? AppColors.danger : AppColors.primary,
                  onPressed: _toggleListening,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
