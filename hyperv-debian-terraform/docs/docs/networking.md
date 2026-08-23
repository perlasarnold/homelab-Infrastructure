# Cloudflare Tunnels + Tailscale

Two networking layers for different needs:

| | Cloudflare Tunnel | Tailscale |
|---|---|---|
| **Use for** | Public services (wiki, Vaultwarden) | Private admin UIs (Portainer, Grafana, Guacamole) |
| **Requires open ports?** | No | No |
| **Authentication** | Cloudflare Access (email/SSO/OTP) | Your identity provider (Google/GitHub) |
| **Cost** | Free (Zero Trust free tier) | Free up to 3 users / 100 devices |
| **Latency** | Via Cloudflare edge | Direct peer-to-peer (WireGuard) |

---

## Cloudflare Tunnel Setup

### Prerequisites

- A domain on Cloudflare (DNS managed by Cloudflare)
- A Cloudflare account (free tier works)

### Step 1 — Create the tunnel

1. Go to **dash.cloudflare.com → Zero Trust → Networks → Tunnels**
2. Click **Create a tunnel** → name it `homelab`
3. Copy the **Tunnel Token** shown on screen

### Step 2 — Encrypt and store the token

```bash
# On your machine (not the server!):
cat > secrets/cloudflared.env <<EOF
TUNNEL_TOKEN=eyJhIjoiYWJj...
EOF

sops --encrypt secrets/cloudflared.env > secrets/cloudflared.env.enc
rm secrets/cloudflared.env
git add secrets/cloudflared.env.enc
git commit -m "Add cloudflared secret"
git push
```

### Step 3 — Add to Docker deploy dropdown

Trigger **Actions → Docker Deploy → service: cloudflared**

### Step 4 — Configure public hostnames in Cloudflare

Back in the Cloudflare Tunnel dashboard, add **Public Hostname** entries:

| Subdomain | Domain | Service |
|---|---|---|
| `wiki` | yourdomain.com | `http://wikijs:3000` |
| `vault` | yourdomain.com | `http://vaultwarden:80` |
| `cloud` | yourdomain.com | `http://nextcloud:80` |

!!! warning "Never tunnel admin UIs"
    Do **not** create public routes for Portainer, Grafana, Prometheus, or Guacamole.
    These should only be accessible via Tailscale.

### Step 5 — Optional: Cloudflare Access policy

Add an extra login gate in front of your tunneled services:

**Zero Trust → Access → Applications → Add an application → Self-hosted**

- Application domain: `wiki.yourdomain.com`
- Policy: Allow email ends with `@yourdomain.com`
- This adds a Cloudflare-managed login page on top of your service

---

## Tailscale Setup

### Step 1 — Get an auth key

1. Go to **tailscale.com → Settings → Keys → Generate auth key**
2. Check **Reusable** and **Ephemeral** (ephemeral = removed when offline)

### Step 2 — Encrypt and store the key

```bash
cat > secrets/tailscale.env <<EOF
TS_AUTHKEY=tskey-auth-XXXXXXXXXXXX
EOF

sops --encrypt secrets/tailscale.env > secrets/tailscale.env.enc
rm secrets/tailscale.env
git add secrets/tailscale.env.enc && git commit -m "Add tailscale secret" && git push
```

### Step 3 — Deploy Tailscale

**Actions → Docker Deploy → service: tailscale**

The VM will appear in your Tailscale admin console within ~30 seconds:
**tailscale.com/admin/machines**

### Step 4 — Access services via Tailscale

From any device with Tailscale installed:

```
http://debian-server:9000   # Portainer
http://debian-server:3000   # Grafana
http://debian-server:8085   # Guacamole
http://debian-server:3001   # Uptime Kuma
```

The hostname `debian-server` is the `hostname:` set in the Tailscale compose file. You can also use the Tailscale IP shown in the admin console.

### Step 5 — MagicDNS (optional)

Enable MagicDNS in Tailscale admin → all your devices get `.ts.net` hostnames automatically. No manual IP management needed.

---

## Recommended Access Map

```
Service              Cloudflare Tunnel   Tailscale   Notes
─────────────────────────────────────────────────────────────
Wiki.js              ✅ wiki.domain.com  ✅           Public-facing docs
Vaultwarden          ✅ vault.domain.com ✅           Needs HTTPS for clients
Nextcloud            ✅ cloud.domain.com ✅           Large file sync
Portainer            ❌                 ✅ only       Admin UI — never public
Grafana              ❌                 ✅ only       Admin UI — never public
Prometheus           ❌                 ✅ only       Internal metrics
Guacamole            ❌                 ✅ only       SSH gateway — never public
Pi-hole              ❌                 ✅ only       DNS — internal only
Uptime Kuma          ❌                 ✅ only       Status — optional public
Jupyter              ❌                 ✅ only       Dev tool — internal only
```
