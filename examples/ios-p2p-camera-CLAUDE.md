# Lookout / iOS P2P Camera — project CLAUDE.md

Drop this at the root of the Xcode app repo (or merge the rules into an existing CLAUDE.md). Pair it with the `ios-p2p-camera` skill.

## Project Overview

Single stock-iOS app, two roles: Camera Node and Viewer. Devices discover each other with Bonjour on the same Wi-Fi and stream H.264 over Network.framework. No vendor cloud, no subscription, no jailbreak.

Product name: **Lookout**. Bonjour type: `_lookout._tcp`. Do not use Sentinel or SentinalCam. A trap face may split later — do not build it in Phase 1.

## Critical Rules

### 1. Architecture

- One binary, role switch. Do not split into two apps.
- Network.framework + Bonjour for discovery and TCP. Do not use MultipeerConnectivity as the media path.
- VideoToolbox for encode/decode. Do not use `AVAssetWriter` for the live view.
- Wrap capture, encode, transport, and clock behind small protocols so Swift Testing can run without a device.
- Phase 1 is discovery + live feed under 1 s. Do not start motion work until that works on two physical phones.
- Launch is free. The Node shows a large local address block when it is live.
- Wi-Fi / AWDL = live video. Bluetooth = pair, control, snapshots — not full live video.
- Do not paywall Phase 1. A pretty web address (`room.lookout.app`) is a later paid tier only.

### 2. Platform honesty

- Camera Node stays in the foreground, plugged in, `isIdleTimerDisabled = true`.
- Do not promise background capture or lock-screen push without APNs.
- Do not use silent-audio or VoIP background modes to fake an always-on camera.
- VPN / Private Relay / AP-isolation must surface as explicit errors. Tailscale used as the away tunnel is a known exception.

### 3. Security

- Pair with an on-screen PIN or QR. Never put the PIN in Bonjour TXT.
- LAN membership is not authentication.
- Encrypt before any use off the home LAN.
- Validate and size-cap every framed message. Siren/strobe only from a paired Viewer.
- No analytics SDK. No stealth / hidden-camera / LED-disable features.
- Do not hide alarm or detection features to pass App Store review.

### 4. Performance

- Start at 720p15 (or 480p15). Watch `ProcessInfo.thermalState`.
- Restart `AVCaptureSession` on interrupt/runtime error.
- Measure capture, encode, network, and display separately.

### 5. Code style

- Swift, SwiftUI, iOS 17+ unless the repo says otherwise
- `@Observable` (not `ObservableObject`) for new view models
- Immutability at the model layer; no emoji in code or comments
- Conventional commits: `feat:`, `fix:`, `test:`, `docs:`

## File sketch

```
App/
  LookoutApp.swift
  RolePickerView.swift
Node/
  CameraListener.swift
  NodeCapturePipeline.swift
  NodeStatusView.swift
Viewer/
  CameraBrowser.swift
  ViewerDisplay.swift
  LiveFeedView.swift
Shared/
  Framing.swift
  Advertisement.swift
  PairingStore.swift
```

## First-run demo

1. Install on two iPhones on the same 5 GHz LAN (VPN off).
2. Spare phone: Camera Node → allow Camera + Local Network.
3. Daily phone: Viewer → allow Local Network → enter the PIN.
4. Confirm live video and a latency badge under 1 second.

## Related ECC skills

`ios-p2p-camera`, `swiftui-patterns`, `swift-protocol-di-testing`, `swift-concurrency-6-2`, `security-review`, `latency-critical-systems`, `ios-icon-gen`
