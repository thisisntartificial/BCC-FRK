---
name: ios-p2p-camera
description: Build Lookout, a stock-iOS peer-to-peer camera app — Bonjour discovery, Network.framework transport, VideoToolbox H.264, viewer/node roles, local alerts, no cloud. Use for spare-phone security cameras, baby/pet monitors, LAN streaming, or Multipeer alternatives.
origin: ECC
---

# iOS Peer-to-Peer Camera

Turn spare iPhones into local camera nodes. One app, two roles (Camera Node and Viewer). Devices find each other with Bonjour on the same Wi-Fi, stream H.264 over Network.framework, and keep media on-device. Stock iOS only — no jailbreak. Launch is free; a pretty web address can go paid later.

This skill is the build playbook. Product name: **Lookout**. Bonjour type `_lookout._tcp`. A louder trap face (Boobytrap) may split later on the same system — do not build it in Phase 1. Do not use Sentinel or SentinalCam.

## When to Use

- Implementing a local iPhone-to-iPhone camera, baby/pet monitor, or spare-phone security node
- Choosing Bonjour + Network.framework vs MultipeerConnectivity vs WebRTC
- Encoding camera frames with VideoToolbox for sub-second LAN latency
- Adding motion/audio alerts that must work without a vendor cloud
- Planning multi-node grid view, local recording, or on-device Core ML detection
- Writing Info.plist local-network / Bonjour / camera permissions for this class of app
- Exposing a local camera URL and reaching it from LTE through Tailscale or another user-owned tunnel

## How It Works

```text
Camera Node                         Viewer
AVCaptureSession                    NWBrowser (_lookout._tcp)
        │                                    │
        ▼                                    ▼
VTCompressionSession ── NWConnection ── VTDecompressionSession
   H.264 NALs            TCP (+ TLS)      AVSampleBufferDisplayLayer
        │                                    │
Detection Engine                        Alert Manager
(pixel-diff, later Core ML)             (in-app; APNs is optional later)
```

1. Both phones run the same app and pick a role.
2. Camera Node advertises `_lookout._tcp` with TXT (`role`, `name`, `proto`, `battery`).
3. Viewer browses, pairs with a PIN/QR, and opens a TCP `NWConnection`.
4. Node encodes frames with VideoToolbox (realtime, 15 fps, frequent IDR).
5. Viewer decodes and displays. Control messages (arm, siren, talk) share the same framing.

Phase 1 success: point an old iPhone at a room, see a live feed on the primary phone in under one second.

## Name and Positioning

**Lookout** is the main product. Full extras and hardware notes: [references/naming-and-extras.md](references/naming-and-extras.md).

Do **not** hide alarm, recording, or detection features to sneak past App Store review. Local camera apps (Manything, Alfred-class) are a legitimate category. Frame honestly: "use a spare iPhone as a local camera." Put covert-surveillance language and face-recognition-of-strangers behind TestFlight / sideload if needed.

## Phase Map

Each phase is independently useful. Do not start Phase N+1 until Phase N streams or alerts on two physical devices.

| Phase | Ships | Stock-iOS constraint |
|-------|-------|----------------------|
| 1 Foundation | Discovery + H.264 stream + role UI | Camera Node must stay in foreground, plugged in, idle timer off |
| 2 Motion | Pixel-diff, zones, sensitivity, local clips | Viewer alerts are in-app (and local notification only while the app is alive) |
| 3 Audio/alarm | Mic threshold, siren, strobe, talkback, auto-arm | Two-way audio needs a play-and-record session; siren is just a loud local file |
| 4 Multi-node | 3+ nodes, grid, per-node settings, panic | One TCP stream per node; grid should request a low-res preview track |
| 5 Detection | Person / tripwire / faces / low-light | Core ML on the Node; never send frames off-device |
| 6 Review | Rolling buffer, timeline, Photos export | Storage lives on the Node (or Viewer if you copy clips over LAN) |

Local IP + user-owned tunnel (away viewing) is Phase 1.5, after the LAN feed works. See [references/reachability.md](references/reachability.md).

Capability contract: [references/capability.md](references/capability.md). Platform limits: [references/platform-constraints.md](references/platform-constraints.md).

## Architecture Choices

| Need | Use | Do not use |
|------|-----|------------|
| Discovery on same Wi-Fi | `NWListener` + `NWBrowser` + Bonjour | A cloud signaling server |
| Video transport | Network.framework TCP first, UDP later | MultipeerConnectivity as the media path (8-peer cap, higher latency) |
| Encode / decode | VideoToolbox `VTCompressionSession` / `VTDecompressionSession` | ReplayKit, `AVAssetWriter` for live view |
| Pairing | On-screen PIN + QR, then pinned keys | Trust every `_lookout._tcp` advertiser |
| Encrypt the stream | TLS with pairing-pinned identity (Phase 1.5) | Raw H.264 on open guest Wi-Fi |
| Nearby, no Wi-Fi | BLE pair/control + snapshots; AWDL (`includePeerToPeer`) for real video | Bluetooth as a full H.264 pipe |
| Web / away | Free at launch if shipped (LAN URL). Later: paid pretty address | Paywall on LAN viewing; open unauthenticated URL |
| WebRTC | Only if you already have a stack and can signal over Bonjour | Google WebRTC + a hosted signaling room as the default |

Phase 1 ships TCP. UDP/RTP is a latency optimization after the happy path works.

## Phase 1 Implementation

### Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>Lookout uses the camera to stream this phone as a local camera node.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Lookout uses the microphone for audio detection and two-way talk.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Lookout finds nearby camera nodes and viewers on your Wi-Fi.</string>
<key>NSBonjourServices</key>
<array>
  <string>_lookout._tcp</string>
</array>
```

Add microphone usage in Phase 1 even if talkback ships later, so you do not re-prompt.

### Role model

```swift
enum NodeRole: String, Codable, Sendable {
    case camera
    case viewer
}

struct Advertisement: Codable, Sendable {
    var role: NodeRole
    var displayName: String
    var proto: Int
    var batteryPercent: Int?
}
```

Persist the last role. Camera Node UI is status-only (name, battery, thermal, "streaming to …", pairing PIN). Viewer UI is the feed.

### Bonjour + connection

See [examples/bonjour-session.swift](examples/bonjour-session.swift).

- Service type: `_lookout._tcp`
- Listener on the Camera Node; browser on the Viewer
- Reject connections until a 6-digit PIN matches (or a remembered pairing exists)
- Heartbeat every 2 seconds; drop after 6 seconds of silence

### Video pipeline

See [examples/video-pipeline.swift](examples/video-pipeline.swift).

Start conservative to beat heat and hit the 1-second latency budget:

| Setting | Phase 1 value |
|---------|---------------|
| Capture | `hd1280x720` or `vga640x480` if thermal |
| Frame rate | 15 fps |
| Codec | H.264, realtime, no B-frames |
| Bitrate | 1.0–1.5 Mbps |
| Keyframe | every 15 frames (1 s) |
| Display | `AVSampleBufferDisplayLayer` |

Frame the bytes yourself. Do not invent a new media container in Phase 1.

```text
[u32 big-endian length][u8 type][u64 pts_ms][payload]
type: 1 = video (Annex-B or AVCC NALs), 2 = control JSON, 3 = heartbeat
```

### Keep the Node alive

```swift
UIApplication.shared.isIdleTimerDisabled = true
```

Observe `ProcessInfo.thermalStateDidChangeNotification` and drop to 10 fps / 480p on `.serious`. Show a "keep this phone plugged in and this screen open" setup card. iOS will suspend capture in the background; do not pretend otherwise.

### Latency budget (under 1 s)

| Segment | Target |
|---------|--------|
| Capture + encode | 80–150 ms |
| Wi-Fi + TCP | 20–80 ms |
| Jitter buffer | 80–120 ms |
| Decode + display | 30–50 ms |
| **Total** | **~200–400 ms typical** |

If you exceed 1 s: shrink GOP, cut resolution, disable the preview on the Node, and check you are not writing every frame through `AVAssetWriter`.

### Local IP (show in Phase 1, serve in 1.5)

When the Node is live, the status screen shows a large **address block** (`192.168.1.42:8787`). Bonjour TXT may include `http=8787`. Video routes require the pairing token.

Launch is free: Wi-Fi (and AWDL) for live video, Bluetooth for nearby pair/control/snapshots. Web can exist as that same LAN URL. Users can **route it themselves** (Tailscale, Pi, VPS) by pasting a Custom URL — always free. Later, Lookout-hosted pretty addresses can go paid. Do not paywall Phase 1. Details: [references/reachability.md](references/reachability.md). Example listener: [examples/local-http.swift](examples/local-http.swift).

## Phase 2+ Hooks (do not build yet)

- **Motion:** downsample to 160-wide gray, absdiff, count pixels over threshold inside polygons. Sensitivity = threshold + min-blob area. Zones are normalized 0…1 rects so they survive orientation change.
- **Alerts without cloud:** send a control message over the open connection; Viewer shows a banner and a local notification. True lock-screen push requires APNs (Apple's cloud) — optional, documented, never required.
- **Audio/alarm:** `AVAudioRecorder` metering; siren is a bundled CAF played at max volume; strobe is `AVCaptureDevice.torchMode` pulses; talkback is a second low-rate audio track Viewer → Node.
- **Auto-arm:** if the Viewer connection drops, Node sets `armed = true` and keeps detecting locally, writing clips to disk.
- **Multi-node:** Viewer holds `id → Connection` ; grid uses a JPEG preview track (~2 fps) and promotes one node to the full H.264 stream.
- **Detection:** Vision + Core ML on the Node. Person first, then tripwire (line vs centroid), then a local faceprint gallery. Unknown-face alerts are a policy feature — keep them out of the App Store copy if review is a goal.
- **Recording:** circular file on Node (low-res continuous optional); high-res clip from a 10 s pre-roll ring + post-roll. Export via `PHPhotoLibrary` on the Viewer after a LAN copy.

## Security Baseline

- Pairing PIN is shown on the Node screen, never in Bonjour TXT.
- After first pair, store a device key and require it on reconnect.
- Encrypt before any use off the home LAN (Phase 1.5).
- Validate every control message (schema, size cap, role checks). Siren/strobe only from a paired Viewer.
- No analytics SDKs. No crash reporter that uploads frames.
- Visible in-app "this node is live" banner. The camera LED is not enough product-wise in two-party consent states.
- Do not add hidden-camera, stealth, or "disable recording indicator" features.

## Anti-Patterns

- MultipeerConnectivity as the video pipe
- Sending frames to a vendor cloud "just for signaling" or shipping a Lookout relay as the only away path
- Background silent-audio hacks to keep the camera alive for App Store builds
- 1080p30 from day one (heat death on an iPhone 11)
- Trusting LAN membership as authentication
- Hiding siren/detection in review builds
- APNs as a Phase 1 dependency
- Face recognition that phones home

## Best Practices

- One app binary, role switch — not two apps
- Test on two physical devices on the same 5 GHz LAN before optimizing
- Protocol-wrap capture, encode, and transport so Swift Testing can fake them (`swift-protocol-di-testing`)
- Watch thermal state and battery; prefer a worse picture over a reboot
- Name nodes by room (`Kitchen`, `Hall`) not by device model
- Guided Access + Guided Access passcode as the Node setup last step
- Keep the Phase 1 demo script to: install → pick roles → grant local network → enter PIN → see feed

## Related Skills

- `swiftui-patterns` — role picker, viewer chrome, grid
- `swift-protocol-di-testing` — fake capture/transport in tests
- `swift-concurrency-6-2` — session actors, `Sendable` frames
- `foundation-models-on-device` — later on-device summaries, not live video
- `ios-icon-gen` — app icon imagesets
- `liquid-glass-design` — viewer chrome
- `latency-critical-systems` — measure capture/encode/net/display separately
- `security-review` — pairing, TLS pinning, control-plane auth
