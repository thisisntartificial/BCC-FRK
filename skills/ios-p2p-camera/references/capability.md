# Capability contract — local P2P iPhone camera

Durable constraints for Lookout-class apps. Update this file when a product decision changes; do not bury the same facts only in chat.

## Capability

- **Name:** Local peer-to-peer camera node + viewer
- **Primary actors:** Home owner (Viewer), spare-phone Camera Node, optional guest node
- **Outcome after ship (Phase 1):** Two stock iPhones on the same Wi-Fi discover each other and show a live camera feed on the Viewer with end-to-end latency under 1 second
- **Success signal:** Point the Node at a room; see that room on the Viewer without an account, server, or subscription

## Product intent

A single iOS app lets a spare iPhone act as a wireless camera and a primary iPhone act as the console. Media and detection stay on the LAN (or on-device). Later phases add motion, audio/alarm, many nodes, on-device ML, and local review.

## Constraints

- Stock iOS only. No jailbreak, no private API as a required path.
- No vendor cloud and no subscription required for the core loop.
- One binary, two roles.
- Camera Node must remain in the foreground and preferably plugged in.
- Viewer lock-screen push is **not** a Phase 1–3 promise (APNs is Apple cloud and optional).
- Pairing is explicit (PIN/QR). LAN membership is not auth.
- Encrypt the stream before use off a trusted home LAN (Phase 1.5).
- Do not hide security features to obtain App Store review.
- Visible LIVE / recording indicator in the Node UI.
- Frames never leave the device except over a paired connection (LAN, or the same local port via a user-owned tunnel).
- Away viewing is optional. Default is LAN. Tunnel is the user's Tailscale / WireGuard / home helper, not a Lookout account.

## Actors and surfaces

- Camera Node: status UI, pairing PIN, live indicator, LAN URL (`http://<ip>:8787`), later siren/strobe
- Viewer: discovery list, live feed, typed/overlay URL, later grid, event timeline, panic
- Local HTTP: `/health`, `/snap`, `/live` (token required)
- Control plane: arm/disarm, sensitivity, zones, talkback, siren
- Media plane: H.264 (and later JPEG preview, AAC talkback)
- Storage: Node disk first; Viewer copies clips on demand

## States and transitions

```text
Node: idle → advertising → paired → streaming → (armed | disarmed)
Node: streaming → degraded (thermal / low battery / weak wifi)
Node: streaming → disconnected → auto-armed (Phase 3+)
Viewer: browsing → pairing → watching → (backgrounded; alerts best-effort)
Pairing: unknown → pin-challenge → trusted
```

Illegal: `unknown → streaming`. Illegal: control commands from an unpaired peer.

## Interface contract

**Inputs (Node):** camera frames, mic levels, battery, thermal, pairing PIN entry confirmation, control messages from a trusted Viewer.

**Outputs (Node):** Bonjour advertisement, framed H.264, heartbeats, event metadata, later clips.

**Inputs (Viewer):** browse results, PIN/QR, user arm/siren/talk, later zone drawings.

**Outputs (Viewer):** decoded video, in-app alerts, later Photos exports.

**Failure:** show a concrete reason (local network permission, VPN, client-isolation Wi-Fi, PIN mismatch, thermal shutdown, capture session died). Retry browse automatically; do not retry siren.

**Idempotency:** `arm`, `disarm`, and `stop-siren` are idempotent. `trigger-siren` may be repeated; the Node coalesces to one playing tone.

## Data implications

- Source of truth for pairing keys and room settings: each device's local store (Keychain for keys, App Group optional later)
- Clips and the ring buffer live on the Node unless copied
- Retention: user-defined cap; default delete oldest events
- No account database

## Security and policy

- Trust boundary is the pairing, not the SSID
- Size-cap and schema-validate every message
- Siren/strobe/talkback require a trusted Viewer
- Two-party consent: product copy must not encourage covert recording
- Reject stealth / LED-disable features

## Non-goals

- Lookout-operated video relay or "works from anywhere" with no extra app/helper
- UPnP / raw port-forward as the away-access product path
- Android / web as Phase 1 clients
- HomeKit Secure Video
- Vendor-hosted ML
- Background camera capture as a guaranteed iOS capability
- Covert surveillance positioning

## Open questions

- Minimum iOS version (recommend iOS 17+ for modern Network.framework + Observation)
- Whether Phase 1.5 TLS blocks the first TestFlight or ships one week later
- Whether guest-node expiry is Phase 1 or Phase 4
- App Store vs TestFlight-first for siren/auto-arm wording
- Whether Tailscale is documented-only or Lookout detects a `100.x` address and offers it on the Node screen

## Handoff

Ready for a Mac + two iPhones: create an Xcode app, copy Phase 1 patterns from `SKILL.md` and `examples/`, wrap capture/transport behind protocols, and do not start motion work until the live feed is under 1 s on device.
