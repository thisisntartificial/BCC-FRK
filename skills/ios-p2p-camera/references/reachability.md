# How you watch: Wi-Fi, Bluetooth, web

Three ways to see a Lookout node. Launch is **free**. A paid web tier can come later. Do not put a paywall on Phase 1.

| Path | When | Launch | Later |
|------|------|--------|-------|
| **Wi-Fi** | Same LAN, or phone-to-phone Wi-Fi (AWDL / `includePeerToPeer`) | Free live H.264 | Stays free |
| **Bluetooth** | Nearby, no usable Wi-Fi | Free. Pairing, presence, control. Snapshots or a crawl-speed preview — not full live video | Stays free |
| **Web** | Browser or away-from-home URL | Free if you ship it: raw LAN URL on the Node | Paid. Pretty address (`https://kitchen.lookout.app` or similar), not `192.168.1.42:8787` |

Core promise that never goes paid: two phones, same room or same Wi-Fi, live feed.

## Launch: free, address goes up in a block

When the Node is live, the status screen shows a single **address block** — large, copyable, high contrast:

```text
LOOKOUT · KITCHEN
192.168.1.42:8787
Wi-Fi · live
```

"The camera is up" means that block is on screen. The Viewer can type it, tap it from Bonjour, or scan a QR of it. No account.

Do not hide the address behind a paywall or an account wall at launch.

## Later: web goes paid, address gets pretty

When you turn on billing, only **web / away** is the paid surface.

- Wi-Fi app-to-app stays free.
- Bluetooth nearby stays free.
- `https://<room>.lookout.app` (or one pretty path per house) is the paid thing: browser on a laptop, LTE without Tailscale, share-a-link.

The pretty address is a name, not an IP. Same token, same Node bind. Lookout's paid job is the stable name + relay/tunnel so the browser does not need `192.168.x.x`.

Until that ships, do not promise pretty URLs. Show the LAN block only.

Price is unset. Do not invent a number in the app. The rule is: **free now, web can go up later.**

## Wi-Fi (default, free)

Bonjour `_lookout._tcp` + framed TCP, and the `:8787` HTTP bind for browsers on the LAN.

`NWParameters.includePeerToPeer = true` so two phones can still connect when there is no router (AWDL). That is still Wi-Fi, not Bluetooth, and it is the right "we're in the same room with no network" path for live video.

Token on every video route. Advertise `http=8787` in Bonjour TXT.

## Bluetooth (nearby, free, limited)

Use Bluetooth for what radios allow on stock iOS:

| Job | Use |
|-----|-----|
| Find / pair when Wi-Fi isolation is on | BLE advertise + PIN/QR |
| Owner is in the room (auto-disarm) | BLE beacon from the Viewer |
| Control (arm, stop siren) if TCP is down | Small BLE / Multipeer control messages |
| Live 720p15 | **No.** BLE cannot carry it. Multipeer-over-Bluetooth is a slideshow |

If you offer a Bluetooth "preview," it is JPEG snapshots on a slow interval. UI must say so. Do not market Bluetooth as a third full-quality camera pipe.

## Web (browser / away)

### Launch (free, if present)

Same `:8787` on the LAN. Safari on a Mac on that Wi-Fi. Token required. Ugly address is fine.

User-owned Tailscale to that port can exist as a power-user note. Still free, still not a Lookout account.

### Paid (later)

| Paid web includes | Still free |
|-------------------|------------|
| Pretty address | Lookout Viewer on Wi-Fi |
| Lookout-operated name + tunnel so LTE/browser works with no extra VPN app | Bluetooth nearby |
| Optional share link with expiry | LAN `192.168.x.x` block on the Node |

Do not flip this on in Phase 1. When you do, gate **only** the pretty/public URL and the hosted relay. Do not brick LAN viewing for people who never pay.

A public URL without a token is an open camera. Never ship that.

## Route it yourself (free, always)

Lookout never has to own the away path. The Node is just a device on the house network. Anyone who can reach `:8787` with the token can watch. "Route it yourself" means the user (or a box they already run) forwards that port to wherever they want.

Lookout's job: show the LAN block, accept the token, play video.  
Their job: make `192.168.1.42:8787` reachable from the place they care about.

```text
Node :8787  ──►  their tunnel / VPN / home box  ──►  phone or browser
```

The Viewer has a single field: **Custom URL**. They paste what their route produced. Same token as LAN. No Lookout account. This stays free even after pretty-web goes paid.

### Recipes that actually work

| They already have | What they do | What they paste in Lookout |
|-------------------|--------------|----------------------------|
| **Tailscale** on both phones | Same tailnet. Nothing else. | `http://100.x.x.x:8787` or `http://kitchen.tailnet.ts.net:8787` |
| **WireGuard** home net | Node is a peer (or sits behind the home WG box) | `http://10.0.0.12:8787` |
| **Pi / Mac on the LAN** | `cloudflared`, Caddy, Caddy + Tailscale, or nginx stream to the phone's LAN IP | `https://cam.their.domain` |
| **Home Assistant / Frigate** | Point the integration at the Node LAN URL | (they watch in HA, not in Lookout) |
| **Router port forward** | WAN:443 → `192.168.1.42:8787` | `https://their-dyndns:443` — works until CGNAT; we document, we do not recommend |
| **Reverse SSH / VPS** | Home box `ssh -R` to a VPS they rent | `https://vps.their.domain` |

Stock iOS cannot run `cloudflared` inside Lookout. If they want Cloudflare or a hostname, the process runs on a **helper** (Pi, Mac, NAS), not on the spare iPhone.

### How the app should treat this

1. Node status always shows the LAN block (so they know what to point the tunnel at).
2. Viewer → Add camera → **Custom URL** (plus token). Save it as that room.
3. Optional: "Tailscale detected" if a `100.x` address appears — still their route, not ours.
4. If the custom URL fails: "Your route is down" — not "Lookout is down."
5. Do not charge for Custom URL. Paid web is only the pretty Lookout-hosted name.

### What they need to understand

- The spare phone still has to stay open and plugged in. A tunnel does not keep iOS awake.
- The tunnel endpoint must be on the **same LAN** as the Node (or on the Node via Tailscale). A VPS cannot see `192.168.1.42` unless something at home forwards it.
- Token stays required. A self-hosted HTTPS name without a token is still an open camera.
- If they use Tailscale, do not tell them to "turn off VPN."

## Viewer order

1. Bonjour on Wi-Fi / AWDL  
2. Typed or scanned address from the Node block  
3. Bluetooth control + snapshot fallback  
4. Saved **Custom URL** (their route)  
5. Later, if entitled: pretty Lookout web URL

Errors must name the path: "No Wi-Fi camera" vs "Bluetooth only — snapshots" vs "Web address needs Lookout+" vs "Token rejected."

## What not to do

- Paywall the first two-phone demo  
- Charge for Bluetooth  
- Call BLE a live stream  
- UPnP / open router ports as the pretty-address implementation  
- Put `cloudflared` inside the iOS app  
- Keep the Node serving after iOS suspends it — paid web does not fix the lamp rule  
