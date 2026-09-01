# Ambient Ears (iOS)

Native Swift app for leaving a phone somewhere and catching sounds you would
otherwise miss, then reviewing hours of recording in minutes.

Three parts:

- **Capture** — long unattended recording, building a loudness index as it goes.
- **Review** — playback that skims silence and drops to normal speed for
  anything audible, with manual speed control on top.
- **Live** — real-time amplification of the room into headphones.

## Why the playback is not just "skip the quiet bits"

The obvious implementation reacts to the audio as it plays: notice sound, slow
down. That always clips the beginning of every event, because by the time the
sound is detected the player is still racing through it at 8x or 12x.

Instead the loudness index is built during recording, so the whole timeline is
known before playback starts. `PlaybackPlan` widens every audible stretch by a
lookahead before and a tail after, then ramps the rate so playback is **already
back at normal speed when the sound begins**. That property is asserted
directly in `testPlaybackIsAtNormalRateBeforeEachSoundStarts`.

There is no machine learning here. It is a threshold with hysteresis over an
energy envelope, and it is deterministic and testable because of that.

## Layout

```
Sources/HearingCore/    Platform-independent engine. Builds and tests anywhere.
  LevelTrack.swift        Loudness envelope, built incrementally while recording
  ActivityDetector.swift  Segments sound from silence
  PlaybackPlanner.swift   Chooses a playback rate for every instant

App/                    iOS app. Requires Xcode.
  Audio/                  AVAudioEngine capture, live monitoring, player
  Views/                  SwiftUI interface
  Model/                  Recording metadata and formatting
```

## Building

The core package builds and tests on any platform with a Swift toolchain,
including Linux:

```bash
cd ios/AmbientEars
swift build
swift test          # 40 tests
```

The iOS app needs a Mac. The Xcode project is generated rather than committed,
so it never drifts from the file list:

```bash
brew install xcodegen
cd ios/AmbientEars
xcodegen generate
open AmbientEars.xcodeproj
```

Then set your own signing team and bundle identifier, and run on a device.
The simulator has no real microphone input worth testing against.

## Platform constraints worth knowing

**Background recording** needs the `audio` background mode, which is set in
`Info.plist`. Recording survives the screen locking. Apple reviews this
entitlement, and an app whose primary purpose is recording is the accepted
justification for it.

**The orange microphone indicator is always visible** while recording, and
cannot be suppressed by any app. Plan around it rather than against it.

**Live amplification requires headphones.** Amplifying the room and playing it
back through the speaker is a feedback loop. `LiveMonitor` checks the output
route and refuses to start otherwise.

**True ultrasound is not reachable** with the built-in microphones. iOS captures
at up to 48 kHz, so the usable ceiling is around 24 kHz — barely above human
hearing, and nowhere near the 40–80 kHz range of bat calls. High gain on audible
frequencies is achievable; genuine ultrasonic capture needs external hardware.

## Recording other people

Consent rules for recording conversations vary by jurisdiction and are stricter
than most people expect. Recording your own space is normally fine; leaving a
device to capture others' conversations often is not.

## Verification status

| Component | Status |
|---|---|
| `HearingCore` | Compiled and tested — 40 tests under Swift 6.0.3 |
| `App/` | Written but not compiled; needs Xcode on a Mac |

The AVFoundation and SwiftUI layers have not been through a compiler. Expect to
fix small API details on first build.
