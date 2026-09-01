# Lookout

Spare-iPhone camera. One app, two roles. Same Wi-Fi, no account. Phase 1.

iOS still needs a Mac + Xcode. A **computer viewer** runs here with Node.

## Run on this computer

```bash
node apps/Lookout/computer/server.js
```

Open `http://127.0.0.1:8788`. You get a live demo feed on this machine. Paste a phone address block (`http://192.168.x.x:8787` + token) to watch a real Lookout node from the computer.

## Run on two phones

1. Open `Lookout.xcodeproj` in Xcode 16+ (iOS 17).
2. Set your Development Team on the Lookout target.
3. Install on a spare iPhone and your daily iPhone. Same 5 GHz Wi-Fi. VPN / Private Relay off.
4. Spare phone: **This phone is the camera**. Allow Camera and Local Network. Keep the screen open and the phone plugged in.
5. Daily phone: **This phone is the viewer**. Allow Local Network. Type the PIN from the camera. Connect.
6. You should see the room. The camera screen shows the address block (`192.168.x.x:8787`).

Safari on the same Wi-Fi can hit `http://192.168.x.x:8787/health`. `/snap` needs `X-Lookout-Token`.

Custom URL (Tailscale / your Pi): Viewer → Custom URL → paste the route. Always free.

## Tests

```bash
# Wire format + computer viewer (runs anywhere Node is installed)
node tests/lookout/framing.test.js
node tests/lookout/computer.test.js

# On a Mac
xcodebuild -scheme Lookout -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## What Phase 1 is

- Bonjour `_lookout._tcp`
- PIN pair
- JPEG live feed (~10 fps) so the first two-phone demo works without H.264 SPS/PPS work
- Address block + local HTTP
- Custom URL poll of `/snap`

Not yet: H.264, motion, siren, pretty paid web, Boobytrap.
