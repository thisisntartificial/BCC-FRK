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

Requires Flutter 3.x (verified against 3.24.5) and a physical device for
microphone access.

### Previewing without a microphone

The idle screen has a "No microphone? Run demo" action that drives the analyzer
from synthesized audio, so the full interface can be exercised on machines with
no capture device (CI, VMs, the web build):

```bash
flutter build web --release
python3 -m http.server 8088 --directory build/web
```

### Checks

```bash
flutter analyze
flutter test
```

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

Only the `web` platform is committed. Scaffold the mobile targets with:

```bash
flutter create . --project-name ultrasonic_hearing --platforms=android,ios
```

## Notes

- Audio analysis currently runs on a synthesized signal once capture starts.
  Replace the generator in `AudioService` with live PCM samples from `record`
  for production capture; the analysis and rendering path is already wired.
- `AudioService.startListening` returns a `StartListeningResult` so the UI can
  distinguish a denied permission from a missing capture device.
- Only record audio you have a lawful right to capture. Follow local consent and
  privacy rules for any shared or archived recordings.
