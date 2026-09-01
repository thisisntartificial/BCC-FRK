# Stock iOS constraints

Read this before promising background cameras, lock-screen push, or Bluetooth video fallback.

## Local network and discovery

- `NSLocalNetworkUsageDescription` + `NSBonjourServices` are mandatory. If either is missing, browse fails with no useful error.
- The user must tap Allow on the Local Network prompt. Say so in the first-run UI.
- Guest Wi-Fi **client isolation** and many mesh "AP isolation" modes block device-to-device TCP. Symptom: browse may still see names, connect hangs.
- iCloud Private Relay and most VPNs break LAN Bonjour. Detect a VPN and tell the user to turn it off.
- Devices must share a broadcast domain. Different VLANs / "IoT network" SSIDs will not see each other.
- Bluetooth LE is fine for pairing, owner-presence, and control. It is not a live H.264 path. Snapshot fallback only; say so in the UI.
- Phone-to-phone live video without a router is AWDL (`includePeerToPeer`), which is still Wi-Fi.
- A Node can bind `:8787` on all interfaces and show its LAN IP. That is the away-access primitive. Stock iOS cannot run `cloudflared` / `ngrok` inside Lookout.
- Tailscale / WireGuard (user-installed) can reach that bind from LTE. Treat Tailscale as a known VPN: do not tell the user to turn it off when they are using it as the tunnel.
- Other VPNs and iCloud Private Relay still break LAN Bonjour. Say so.
- Opening a router port with UPnP is not a reliable or acceptable product path (CGNAT, hotel Wi-Fi, open camera).

## Foreground capture

- `AVCaptureSession` is a foreground feature. When the Node is suspended, the stream dies.
- `isIdleTimerDisabled = true` keeps the screen on. Combine with a dim overlay so the phone can sit on a shelf overnight.
- Silent-audio keep-alive hacks are App Store risk and still fail. Do not rely on them.
- Guided Access is the supported way to pin the Node app.
- Always-plugged-in is an operational requirement, not a nice-to-have.

## Push notifications

| Viewer state | What you can promise |
|--------------|----------------------|
| Open, connected | In-app alert in well under 2 s |
| Connected, briefly backgrounded | Best-effort local notification if you still have a socket |
| Force-quit or hours in background | Nothing local. Needs APNs |

APNs is Apple's cloud. Optional later, user-owned cert, never required for "no cloud, no subscription."

Critical Alerts play through silent mode and need a separate Apple entitlement. Do not plan Phase 2 around them.

## Heat, battery, and session death

- Sustained 1080p30 cooking an iPhone 11 is expected. Start at 720p15 or 480p15.
- Subscribe to `ProcessInfo.thermalStateDidChangeNotification`.
- `AVCaptureSessionRuntimeError` and `wasInterrupted` are normal. Restart the session; do not show a generic "camera failed."
- Battery-aware mode: drop fps, stop the on-Node preview, and warn at 20%.

## Audio and torch

- Talkback needs `AVAudioSession` category `.playAndRecord` with `.defaultToSpeaker` on the Node.
- Siren is a bundled sound at max volume. You cannot override hardware silent-switch in all states; say so.
- Torch strobe fights the camera session (same device). Prefer a short pulse pattern or an external lamp; test on device before promising a movie-style strobe.

## Encryption and entitlements

- Network.framework can do TLS with a custom `sec_protocol_options` identity. Pin the cert exchanged at pairing.
- Local Network, Camera, and Microphone are the only required entitlements for Phase 1–3.
- Background Modes (`audio`, `voip`) will not make this a legal always-on security camera. VoIP background for a camera app is a review rejection.

## MultipeerConnectivity vs Network.framework

MultipeerConnectivity gives you discovery + encrypted sessions quickly and then fights you: peer limit, unpredictable buffering, weaker control of UDP vs TCP. Use it only for a throwaway prototype. Ship Network.framework.

## App Store

Local spare-phone cameras are an established category. Rejection risk goes up when the listing promises covert recording, unknown-face dossiers, or "works hidden in a room." Keep that language off the store page. Do not ship a review-time feature flag that hides siren or detection.

## What "no cloud" actually means

- No vendor account, no vendor relay, no vendor ML. A user-owned Tailscale/WireGuard overlay is their network, not Lookout SaaS.
- The phones still use Apple's OS, iCloud backup if the user enabled it (exclude clip directories from backup), and optional APNs if the user opts in.
- Document that iCloud Photos export is the user's Photos library, not your SaaS.
