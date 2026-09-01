# Naming, extras, and hardware

Use this when picking a public name or deciding what to add beyond the six-phase roadmap.

## Chosen name

**Lookout** — main product, build this first.

- One word, App Store-safe, means watch post
- Bonjour type `_lookout._tcp`
- Bundle ID shape: `app.lookout.cam` or `com.yourorg.lookout`

**Later split (do not build now):** a separate trap face on the same pairing/stream system (working name Boobytrap). Same phones, same LAN, different personality.

**Rejected:** Sentinel, SentinalCam, AirWatch, Nest, Ring, and anything with spy / hidden / nanny / undetectable in the name.

**Friends-as-cameras:** pairing should support a **guest node** that expires at a time you set ("lend me your phone for the party").

## Extras that work well on stock iOS

These fit the no-cloud constraint and are worth scheduling. Starred items punch above their weight.

### Trust and setup

- **QR + 6-digit PIN pairing.** Never advertise the PIN in Bonjour TXT.
- **Guest pairing with expiry.** Friends-as-nodes becomes a real feature.
- **Guided Access card.** Last setup step on a Camera Node: enable Guided Access so a thief or kid cannot exit the app.
- **Room names, not device names.** Kitchen / Hall / Driveway.
- **Setup heat/power checklist.** Plug in, 5 GHz Wi-Fi, keep screen on, don't cover the camera.

### Survive real houses

- **Tamper alert.** Accelerometer spike = phone was moved or knocked over.
- **Charge-lost alert.** USB unplug is the most common "attack" on a spare phone.
- **Covered-lens detect.** Sudden global darkness while armed.
- **Thermal governor.** `ProcessInfo.thermalState` drops fps/resolution before iOS jetsams you.
- **Wi-Fi RSSI + VPN warning.** Private Relay / VPN often breaks LAN Bonjour — show that, don't "just fail."
- **Capture-session watchdog.** `AVCaptureSession` dies silently; restart it.
- **iPad viewer / Mac Catalyst console.** One big grid without new phones.

### Alerts that do not need a vendor cloud

- **In-app banner + sound** while the Viewer is open (Phase 2 contract).
- **Snapshot-first alerts.** A still JPEG is faster and cheaper than a clip.
- **Geofence auto-arm on the Viewer.** When the primary phone leaves home, send `arm` to every paired node (works only if the Viewer can still reach the LAN, or when you return and reconnect).
- **Owner BLE presence.** Viewer advertises a tiny BLE beacon; nodes disarm when the owner is in the room (reduces "I walked into my own kitchen" false alerts).
- **Shortcuts / App Intents.** "Arm House", "Kitchen siren", "Show Hall."
- **Live Activity / Dynamic Island** for armed count and last event (Viewer).
- **Apple Watch glance** for last motion + panic (optional).

True lock-screen push when the Viewer is killed requires APNs. Treat that as an **opt-in**, user-owned Apple push cert, never a product requirement.

### Power-user hooks (keep out of the default path)

- **RTSP publisher on the Node** so Home Assistant / Frigate / an NVR can ingest. Local only.
- **MQTT state** (`armed`, `battery`, `motion`) on the LAN.
- **Laptop viewer** via a local HTTPS page served by the Viewer (not the Node) after it already has the stream.

### Product polish

- **Picture-in-Picture** on the Viewer so the feed survives leaving the app briefly.
- **Low-res preview track** for the Phase 4 grid; promote one node to full H.264.
- **Talk-to-this-room vs all-rooms.**
- **Doorbell mode.** Front-door phone, big tap-to-talk, no siren by default.
- **Software privacy shutter.** One tap blacks the stream and pauses capture.
- **Export to Photos / AirDrop** of a single event (Phase 6).
- **Storage cap + oldest-event eviction** on the Node.
- **Visible LIVE indicator** even though iOS already has a camera LED.

## Extras to defer or reject

| Idea | Why not (yet) |
|------|----------------|
| Bluetooth mesh fallback for video | BLE cannot carry H.264; use it for presence/control only |
| HomeKit Secure Video | Cloud-adjacent, entitlement-heavy, fights the no-subscription story |
| IR floodlight "support" as a software feature | It's a camera setting (disable AE hunting, lock ISO). Don't claim IR hardware you don't have |
| U1 / LiDAR as a Phase 1 requirement | Nice on 12 Pro; must not exclude iPhone 11 nodes |
| Hidden-camera mode / disable LED | Reject. Legal and review risk |
| "Hide security features for App Store" | Reject. Honest local-camera positioning is enough |

## Hardware that actually helps

| Role | Device | Why |
|------|--------|-----|
| Camera Node (fine) | iPhone 11+ | Cheap used, good enough 12 MP, VideoToolbox |
| Camera Node (best) | iPhone 12 Pro / 13 | Better low light; LiDAR unused in Phase 1 |
| Viewer | Current daily phone | Already owned; iPad is the better console |
| Mount | $10 clamp / tripod | Landscape, lens at door height |
| Power | Official or MFi charger, always plugged | Battery-aware mode is a fallback, not a plan |
| Network | Same 5 GHz LAN, no guest isolation, no VPN | Client isolation on mesh Wi-Fi is the #1 "discovery is broken" bug |

Old iPads work as Nodes if they have a camera and run your minimum iOS. An iPad as Viewer is the easiest Phase 4 grid.

## Distribution (honest)

| Channel | Use for |
|---------|---------|
| Two-device Xcode install | Phase 1 proof |
| TestFlight | Beta language, including siren/auto-arm |
| App Store | Local camera / pet / baby / spare-phone monitor. Keep unknown-face copy conservative |
| AltStore / sideload | Entitlements or wording Apple will not take |
| Enterprise cert | Only if you actually have an org; not a consumer sideload cheat |

## Copy you can reuse

- Viewer empty state: "Open Lookout on a spare iPhone, choose Camera Node, and enter the PIN shown there."
- Node status: "This phone is a camera. Keep it plugged in and this screen open."
- Motion alert: "Kitchen · motion · now" plus a snapshot, not a paragraph.
