# 🦊 Troubleshooting: Firefox SSL Handshake Failure & NPM Domain Alias Alignment

> **Date:** 2026-08-16  
> **Objective:** Diagnose and resolve why Firefox failed to connect to `https://immich.homelab-admin.me` and `https://jellyfin.homelab-admin.me` while Google Chrome succeeded, following the migration to Nginx Proxy Manager (Cebu CT 105).  
> **Target Environment:** Proxmox VE — `Cebu` (CT 105 / `192.168.120.211`), Proxmox VE — `Dapitan` (CT 504 Immich, CT 510 Jellyfin, CT 509 Plex)  
> **Status:** 🟢 Resolved  

---

## 1. Problem Statement

Following recent Nginx Proxy Manager and Let's Encrypt Wildcard SSL setup:
- Accessing `https://immich.homelab-admin.me` and `https://jellyfin.homelab-admin.me` worked in **Google Chrome**.
- In **Mozilla Firefox**, connections to both URLs failed with SSL/TLS handshake errors (`SEC_ERROR_UNKNOWN_ISSUER`, `SSL_ERROR_UNRECOGNIZED_NAME_ALERT`, or fatal alert `SEC_E_ILLEGAL_MESSAGE`).

---

## 2. Investigation & Root Cause Analysis

### A. DNS Resolution Discrepancy
Inspecting DNS resolution for `immich.homelab-admin.me` and `jellyfin.homelab-admin.me`:
- Pi-hole Split-Horizon DNS (`/etc/dnsmasq.d/99-homelab-admin-lan.conf`) had `address=/immich.homelab-admin.me/192.168.120.211` and `address=/jellyfin.homelab-admin.me/192.168.120.211`.
- Public Cloudflare DNS had proxied `AAAA` records pointing to Cloudflare CDN edge (`2606:4700:...`).

### B. NPM Virtual Host Configuration Inspection
Querying the active NPM SQLite database (`/data/database.sqlite`) and Nginx server blocks (`/data/nginx/proxy_host/`):
- **Immich Host (ID 9):** Configured with only `photos.homelab-admin.me`.
- **Jellyfin Host (ID 10):** Configured with only `media.homelab-admin.me` (pointing to an offline Bulakan IP `192.168.1.126`).
- **Jellyfin Host (ID 11):** Configured with only `jellyfindp.homelab-admin.me` (pointing to active Dapitan CT 510 `192.168.110.43:8096`).
- **Plex Host (ID 12):** Configured with only `plexdp.homelab-admin.me`.

### C. The Root Cause
1. When Firefox requested `https://immich.homelab-admin.me` or `https://jellyfin.homelab-admin.me`, it sent an SNI header for `immich.homelab-admin.me` / `jellyfin.homelab-admin.me` to NPM (`192.168.120.211:443`).
2. Because Nginx had no `server_name` matching `immich.homelab-admin.me` or `jellyfin.homelab-admin.me`, Nginx routed the request to the default fallback server block.
3. The fallback server block had no matching certificate, causing Nginx to present a dummy/mismatched certificate or drop the TLS handshake.
4. **Firefox vs Chrome Behavior:**
   - Chrome connected through Cloudflare edge (via DoH or IPv6 Cloudflare proxy) where Cloudflare handled SSL termination and forwarded to the Cloudflare Tunnel, or Chrome had cached sessions.
   - Firefox queried local Pi-hole and strictly validated the TLS certificate against NPM's server block SNI, resulting in an immediate SSL handshake abort.

---

## 3. Step-by-Step Resolution

### Step 1: Database & File Backup
Created a backup of the SQLite database before making changes:
```bash
pct exec 105 -- cp /data/database.sqlite /data/database.sqlite.bak-20260816
```

### Step 2: Update Domain Names in NPM Database & Server Blocks
Updated the proxy hosts to include standard aliases so all intended domain variants match the Let's Encrypt wildcard certificate (`*.homelab-admin.me`):

1. **Proxy Host 9 (Immich Dapitan CT 504 - `192.168.110.47:2283`):**
   - Added `immich.homelab-admin.me` alongside `photos.homelab-admin.me`.
   - `server_name photos.homelab-admin.me immich.homelab-admin.me;`

2. **Proxy Host 10 (Jellyfin Bulakan CT 110 - `192.168.110.41:8096`):**
   - Configured `jellyfin.homelab-admin.me` and `media.homelab-admin.me` pointing to primary Bulakan Jellyfin (`192.168.110.41:8096`).
   - `server_name jellyfin.homelab-admin.me media.homelab-admin.me;`

3. **Proxy Host 11 (Jellyfin Secondary Dapitan CT 510 - `192.168.110.43:8096`):**
   - Retained `jellyfindp.homelab-admin.me` for secondary Dapitan instance.
   - `server_name jellyfindp.homelab-admin.me;`

4. **Proxy Host 12 (Plex Dapitan CT 509 - `192.168.110.44:32400`):**
   - Added `plex.homelab-admin.me` alongside `plexdp.homelab-admin.me`.
   - `server_name plexdp.homelab-admin.me plex.homelab-admin.me;`

### Step 3: Configure Split-Horizon DNS on Both Pi-holes (CT 301 & CT 401)
To prevent clients from receiving Cloudflare's public IPv6 CDN proxies (`2606:4700:...`) for local homelab domains:
1. Updated `/etc/dnsmasq.d/99-homelab-admin-lan.conf` on both **Bulakan Primary (CT 301)** and **Cebu Secondary (CT 401)**:
   ```ini
   # Split-Horizon DNS Overrides for homelab-admin.me Infrastructure
   address=/homelab-admin.me/192.168.120.211
   address=/homelab-admin.me/::
   server=/www.homelab-admin.me/#
   server=/homelab-admin.github.io/#
   ```
2. Added all service FQDNs to `/etc/pihole/custom.list`.
3. Restarted `pihole-FTL` on both instances.

### Step 4: Syntax Verification & Dynamic Reload
```bash
# Verify Nginx syntax on Cebu CT 105
pct exec 105 -- nginx -t

# Gracefully reload Nginx
pct exec 105 -- nginx -s reload
```

---

## 4. Verification & Validation Results

Executed HTTPS requests directly over TLS against local NPM:

| URL | Target Service | HTTP Status | Response Header / Details | Result |
| :--- | :--- | :--- | :--- | :--- |
| `https://immich.homelab-admin.me` | Immich (Dapitan CT 504) | **200 OK** | `Strict-Transport-Security: max-age=63072000; preload`, `X-Served-By: immich.homelab-admin.me` | 🟢 Success |
| `https://jellyfin.homelab-admin.me` | Jellyfin (Bulakan CT 110) | **200 OK** | `/web/index.html` HTTP 200, `Strict-Transport-Security: max-age=63072000; preload` | 🟢 Success |
| `https://media.homelab-admin.me` | Jellyfin (Bulakan CT 110) | **302 Found** | `Location: web/`, `Strict-Transport-Security: max-age=63072000; preload` | 🟢 Success |
| `https://jellyfindp.homelab-admin.me` | Jellyfin (Dapitan CT 510) | **302 Found** | `Location: web/`, `Strict-Transport-Security: max-age=63072000; preload` | 🟢 Success |
| `https://plex.homelab-admin.me` | Plex (Dapitan CT 509) | **302 Found** | `Location: https://plex.homelab-admin.me/web/index.html` | 🟢 Success |

---

## 5. Preventive Measures & Best Practices

1. **Dual Address Family Overrides (`A` and `AAAA`):** When creating split-horizon DNS overrides in Pi-hole/dnsmasq for domains using Cloudflare CDN, always include `address=/example.com/::` alongside the IPv4 rule to prevent clients from fetching external Cloudflare IPv6 proxy addresses.
2. **Domain Aliasing in NPM:** Whenever defining proxy hosts in NPM, always include both the friendly service name (e.g., `immich.homelab-admin.me`, `jellyfin.homelab-admin.me`) and any category or node-specific subdomains (`photos.homelab-admin.me`, `jellyfindp.homelab-admin.me`).
3. **Firefox DNS over HTTPS (DoH) Settings:** Ensure Firefox is set to **Default Protection** (or Off) in *Settings $\rightarrow$ Privacy & Security $\rightarrow$ DNS over HTTPS* so it respects local Pi-hole DNS rewrites rather than routing queries to public Cloudflare DoH.

---

## 6. References

- [Nginx Proxy Manager Setup & Operations](file:////opt/homelab-infrastructure/05-Services/Nginx%20Proxy%20Manager.md)
- [NPM Let's Encrypt Wildcard SSL Guide](file:////opt/homelab-infrastructure/06-Guides/Nginx-Proxy-Manager-LetsEncrypt-SSL-Guide-2026-08-14.md)
- [Dapitan Plex Reverse Proxy Guide](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Plex-NPM-Proxy-Setup-2026-08-15.md)

