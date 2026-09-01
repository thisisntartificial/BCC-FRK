# UltraSonic Hearing

Personal audio amplifier and spectrum analyzer (Tweaked Series — App #2).

Amplify ambient sound through your phone’s microphone, visualize the waveform,
inspect frequency bands, and optionally record sessions for your own use.

## Features

- Real-time waveform visualization
- Frequency-band display and dominant-frequency estimate
- Voice-activity heuristic with event log
- Signal strength and clarity meters
- Noise gate and amplification control (1×–10×)
- Session recording (placeholder file until live PCM capture is wired)

## Setup

```bash
cd examples/ultrasonic-hearing
flutter pub get
flutter run
```

Requires Flutter 3.x and a physical device for microphone access.

### Platform permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.VIBRATE" />
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>UltraSonic Hearing needs the microphone to amplify and analyze ambient audio.</string>
```

Scaffold platforms if missing:

```bash
flutter create . --project-name ultrasonic_hearing
```

## Notes

- Current audio analysis uses a processing simulation after permission is granted.
  Replace `AudioService` simulation with live PCM samples from `record` for production.
- Only record audio you have a lawful right to capture. Follow local consent and
  privacy rules for any shared or archived recordings.
