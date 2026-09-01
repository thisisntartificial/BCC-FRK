# Local IP and tunnels

Lookout stays a local camera. Off-LAN viewing is the same local server reached through a **user-owned** tunnel. Lookout does not run a relay, account, or subscription for this.

## What the Node puts up

The Camera Node binds a listener on all interfaces and shows the address on its status screen:

```text
Kitchen
http://192.168.1.42:8787
token required
```

Same process, two ways in:

| Path | Who uses it | Address |
|------|-------------|---------|
| Bonjour + framed TCP | Lookout Viewer on the LAN | `_lookout._tcp` |
| Local HTTP | Browser, second phone, Home Assistant, tunnel | `http://<lan-ip>:8787` |

Advertise the HTTP port in Bonjour TXT (`http=8787`) so the Viewer can offer "Open URL" without guessing.

### HTTP surface (keep it tiny)

| Route | Body | Notes |
|-------|------|-------|
| `GET /health` | `{"room":"Kitchen","armed":false}` | No video |
| `GET /snap` | JPEG | Pairing token; good for alerts and HA |
| `GET /live` | MJPEG or fMP4 | Pairing token; browser-friendly |
| `GET /` | One-page player | Loads `/live` after token |

Do not ship an open webcam on the LAN. Every video route checks the pairing token (header `X-Lookout-Token` or a short-lived query). The token is created at PIN pair, not printed in Bonjour TXT.

Phase 1 can show the LAN IP even before `/live` exists. Phase 1.5 ships `/health` + `/snap` + `/live`.

## "Anywhere" is the tunnel, not Lookout

```text
Home                           Away
Node :8787 ── LAN ── Viewer    Viewer on cellular
      │
      └── user tunnel ───────── same :8787 on overlay IP
```

The Node does not know it is "on the internet." It only binds `:8787`. Whatever overlay reaches that bind (Tailscale, WireGuard, a Pi subnet router) is the user's.

### Pick a tunnel (in this order)

| Option | How | Why |
|--------|-----|-----|
| **Tailscale on both phones** | User installs Tailscale, same tailnet. Lookout is `http://100.x.x.x:8787` or MagicDNS `kitchen.tailnet.ts.net:8787` | Best stock-iOS path. No Lookout servers. No router ports. |
| **WireGuard profile** | User or a home server issues a peer. Lookout listens; Viewer joins the WG net | Same idea, more setup |
| **Home helper** (Mac / Pi) | Helper runs Tailscale subnet router or `cloudflared` to `192.168.1.42:8787` | When you do not want Tailscale on the spare phone |
| Lookout-hosted relay | You terminate video in your cloud | Reject as the default. That is Manything. |

Do not use UPnP / "open port 8787 on the router" as the product path. It fights CGNAT, hotel Wi-Fi, and the security story.

### What stock iOS will not do

- Run `cloudflared` or `ngrok` as a child process inside Lookout
- Keep `:8787` alive after the Node is suspended (the lamp rule still holds)
- Punch out of a double-NAT without an overlay
- Make Tailscale unnecessary if the user wants "open this on LTE with zero extra apps" — that requires *someone's* relay. If you add one later, it is an explicit opt-in product, not the core loop.

## Viewer behavior

1. On the LAN: Bonjour first. Fall back to typed `http://192.168.x.x:8787`.
2. Off LAN: connect to the saved overlay URL (Tailscale IP / MagicDNS / helper hostname). Same token.
3. If both fail, say which: "No local camera" vs "Tunnel offline" vs "Token rejected."
4. Treat Tailscale as a *known* VPN. Do not show the generic "turn off your VPN" error when the only VPN is the tunnel you asked them to install. Other VPNs / Private Relay still break LAN Bonjour.

## Security

- Binding on `0.0.0.0` means guest Wi-Fi neighbors can hit `:8787`. Token + TLS (Phase 1.5) are required before you tell anyone to tunnel.
- Prefer HTTPS with the pairing-pinned cert once the tunnel exists. HTTP-on-LAN is a demo only.
- A public Cloudflare Quick Tunnel URL without a token is an open camera. Never generate one inside the app.
- Rate-limit `/snap` and `/live`. One stream per token is enough for v1.

## Product copy

- Node: "This camera is at `http://192.168.1.42:8787`. Same Wi-Fi works now. For away-from-home, put both phones on the same Tailscale network."
- Settings: a "Away access" card with three states — Off (LAN only), Tailscale detected (`100.x` shown), Custom URL (user pastes helper hostname).
- Do not promise "works from anywhere" on the App Store without saying a user-owned tunnel is required.
