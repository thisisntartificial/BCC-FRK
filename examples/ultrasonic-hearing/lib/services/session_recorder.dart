import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tracks session recording state and writes a placeholder WAV path.
///
/// Wire this to the live recorder output when PCM capture is available.
class SessionRecorder {
  Timer? _recordingTimer;
  DateTime? _recordingStart;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Duration? get recordingDuration {
    if (_recordingStart == null) return null;
    return DateTime.now().difference(_recordingStart!);
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    _isRecording = true;
    _recordingStart = DateTime.now();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(const []);

    _recordingStart = null;
    return file;
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
  }
}
