# 🌐 Nginx Proxy Manager (NPM) Setup & Operations

Centralized reverse proxy for managing SSL certificates and subdomain routing.  
**Last Updated:** 2026-08-15

---

## 🛠️ Deployment Details
- **Method:** [Proxmox VE Helper Script](https://community-scripts.org/scripts?id=nginx-proxy-manager) (LXC)
- **Node:** Proxmox VE — **Cebu** (CT 105) — *sole active instance*
- **IP Address:** `192.168.120.211` (**DMZ VLAN 120**)
- **Admin Port:** `81` → `http://192.168.120.211:81`
- **External Ports:** `80` (HTTP), `443` (HTTPS) — *Managed via UniFi Port Forwarding & Cloudflare Tunnel.*

> [!WARNING]
> **Bulakan NPM instances are permanently offline and decommissioned:**
> - CT 502 (`192.168.1.210`) — was the primary; now offline permanently.
> - CT 102 (`192.168.120.212`) — legacy/secondary; now offline permanently.
> All proxy routing, SSL certificate management, and new proxy host configurations must be done on the **Cebu NPM** at `http://192.168.120.211:81`.

### Resource Allocation
| Resource | Value |
|----------|-------|
| OS | Debian 12 (Bookworm) |
| CPU | 1 vCPU |
| RAM | 2048 MB (2GB) |
| Disk | 8 GB |

### Active Wildcard SSL Certificates
| Domain | Provider / Challenge | Token / Method | Expiry / Renewal |
| :--- | :--- | :--- | :--- |
| `*.homelab-admin.me`, `homelab-admin.me` | Let's Encrypt / DNS-01 | Cloudflare API Token (`Zone:DNS:Edit`) | Auto-renewed via NPM scheduler |

### Active Proxy Hosts
| Subdomain(s) | Forward Address | Upstream Service | SSL Certificate | Features Enabled | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `auth.homelab-admin.me` | `http://192.168.110.225:9000` | Authentik SSO | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `immich.homelab-admin.me`, `photos.homelab-admin.me` | `http://192.168.110.47:2283` | Immich Photos (Dapitan CT 504) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets, 50GB Upload | 🟢 Online |
| `jellyfin.homelab-admin.me`, `media.homelab-admin.me` | `http://jellyfin_ha_cluster:8096` | Jellyfin HA Cluster (Bulakan CT 110 Primary + Dapitan CT 510 Standby) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets, Auto-Failover | 🟢 Online (HA Cluster) |
| `jellyfindp.homelab-admin.me` | `http://192.168.110.43:8096` | Jellyfin Media Secondary (Dapitan CT 510) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Streaming Directives | 🟢 Online |
| `plex.homelab-admin.me`, `plexdp.homelab-admin.me` | `http://192.168.110.44:32400` | Plex Media Server (Dapitan CT 509) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Streaming Directives | 🟢 Online (LAN Only) |
| `photoview.homelab-admin.me` | `http://192.168.110.48:8000` | Photoview Photo Gallery (Dapitan CT 511) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | ⏳ Pending Deployment |
| `bookorbit.homelab-admin.me` | `http://192.168.110.50:3000` | BookOrbit Ebook Platform (Dapitan CT 514) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `readarr.homelab-admin.me` | `http://192.168.110.42:8787` | Readarr Book Automation (Cebu CT 417) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `sonarr.homelab-admin.me` | `http://192.168.110.42:8989` | Sonarr TV Automation (Cebu CT 417) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `torrent.homelab-admin.me` | `http://192.168.110.42:9091` | Transmission BitTorrent (Cebu CT 417) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `home.homelab-admin.me` | `http://192.168.1.250:3000` | Homepage Dashboard (Bulakan CT 116) | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |

---

## 📜 Session Log & Problem History

### Session: 2026-08-22 (Homepage Dashboard & Transmission Reverse Proxy Setup)
- **Task:** Configure Nginx Proxy Manager reverse proxy and Wildcard SSL routing for `home.homelab-admin.me` (`192.168.1.250:3000`) and `torrent.homelab-admin.me` (`192.168.110.42:9091`).
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/16.conf` (`torrent.homelab-admin.me`) and `/data/nginx/proxy_host/17.conf` (`home.homelab-admin.me`) on Cebu CT 105 (`192.168.120.211`).
  - Synchronized SQLite `proxy_host` table entries (Host IDs 16 and 17) with wildcard certificate `*.homelab-admin.me`.
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Added DNS records to Pi-hole `custom.list` on Cebu CT 401 and Bulakan CT 301.
  - Verified Nginx configuration syntax (`nginx -t`) and executed graceful reload (`nginx -s reload`) with zero downtime.

### Session: 2026-08-22 (Sonarr Reverse Proxy & Wildcard SSL Configuration)
- **Task:** Configure Nginx Proxy Manager reverse proxy routing for `sonarr.homelab-admin.me` pointing to Cebu Arr Stack CT 417 (`http://192.168.110.42:8989`).
- **Guide Created:** [`Sonarr-NPM-Reverse-Proxy-Guide-2026-08-22.md`](file:////opt/homelab-infrastructure/06-Guides/Sonarr-NPM-Reverse-Proxy-Guide-2026-08-22.md)
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/15.conf` on Cebu CT 105 (`192.168.120.211`).
  - Synchronized SQLite `proxy_host` table entry (Host ID 15) with wildcard certificate `*.homelab-admin.me` (`certificate_id: 3`).
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Verified Nginx configuration syntax (`nginx -t`) and executed graceful reload (`nginx -s reload`) with zero downtime.

### Session: 2026-08-22 (BookOrbit Reverse Proxy & Wildcard SSL Configuration)
- **Task:** Configure Nginx Proxy Manager reverse proxy routing for `bookorbit.homelab-admin.me` pointing to Dapitan BookOrbit CT 514 (`http://192.168.110.50:3000`).
- **Guide Created:** [`BookOrbit-Deployment-Guide-Dapitan.md`](file:////opt/homelab-infrastructure/06-Guides/BookOrbit-Deployment-Guide-Dapitan.md)
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/13.conf` on Cebu CT 105 (`192.168.120.211`).
  - Bound Let's Encrypt wildcard certificate `*.homelab-admin.me` (`/etc/letsencrypt/live/npm-3/`).
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Verified Nginx configuration syntax and performed graceful daemon reload with zero downtime.

### Session: 2026-08-18 (Jellyfin Active-Active High Availability Setup)
- **Task:** Establish High Availability upstream failover for `jellyfin.homelab-admin.me` and `media.homelab-admin.me` between Bulakan CT 110 (Primary) and Dapitan CT 510 (Standby).
- **Guide Created:** [`Jellyfin-Active-Active-HA-Setup-Guide-2026-08-18.md`](file:////opt/homelab-infrastructure/06-Guides/Jellyfin-Active-Active-HA-Setup-Guide-2026-08-18.md)
- **Configuration:**
  - Configured upstream `jellyfin_ha_cluster` with `ip_hash` session affinity and `backup` failover.
  - Added failover parameters `proxy_next_upstream error timeout http_502 http_503 http_504`.
  - Maintained zero downtime via Nginx graceful reload.

### Session: 2026-08-16 (Firefox SSL Handshake Failure & Subdomain Alias Resolution)
- **Task:** Resolve SSL connection failure in Firefox for `https://immich.homelab-admin.me` and `https://jellyfin.homelab-admin.me`.
- **Guide Created:** [`NPM-Firefox-Domain-Mismatch-Troubleshooting-2026-08-16.md`](file:////opt/homelab-infrastructure/06-Guides/NPM-Firefox-Domain-Mismatch-Troubleshooting-2026-08-16.md)
- **Root Cause:** NPM proxy host definitions only included `photos.homelab-admin.me` and `jellyfindp.homelab-admin.me`. When Firefox queried local Pi-hole DNS (`192.168.120.211`), SNI mismatches caused Nginx to fall back to the default server block without valid certificates, aborting the TLS handshake.
- **Actions Taken:**
  - Added `immich.homelab-admin.me` alias to Proxy Host 9.
  - Added `jellyfin.homelab-admin.me` and `media.homelab-admin.me` aliases to Proxy Host 11 (`192.168.110.43:8096`).
  - Added `plex.homelab-admin.me` alias to Proxy Host 12 (`192.168.110.44:32400`).
  - Decommissioned obsolete Host 10 pointing to offline node `192.168.1.126`.
  - Tested and reloaded Nginx configuration dynamically on Cebu CT 105.

### Session: 2026-08-15 (Dapitan Plex Reverse Proxy & VLAN 110 Migration)
- **Task:** Migrate Dapitan Plex (CT 509) to SERVICES VLAN 110 (`192.168.110.44:32400`) and establish reverse proxy routing on `plexdp.homelab-admin.me`.
- **Guide Created:** [`Dapitan-Plex-NPM-Proxy-Setup-2026-08-15.md`](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Plex-NPM-Proxy-Setup-2026-08-15.md)
- **Actions Taken:**
  - Migrated CT 509 from VLAN 1 (`192.168.1.44`) to SERVICES VLAN 110 (`192.168.110.44/24`) with `hwaddr=00:11:22:33:44:55` preserved.
  - Created DNS-Only `A` record on Cloudflare for `plexdp.homelab-admin.me` pointing to public WAN IP.
  - Added Pi-hole local DNS override mapping `plexdp.homelab-admin.me` $\rightarrow$ `192.168.120.211` (NPM Cebu).
  - Configured NPM Proxy Host 12 with Wildcard SSL (`*.homelab-admin.me`), HTTP/2, HSTS, Force SSL, Websockets, and Plex streaming buffer optimizations.
  - Updated Plex `Preferences.xml` with `customConnections="https://plexdp.homelab-admin.me:443"`, `lanNetworks="192.168.110.0/24,192.168.1.0/24,192.168.120.0/24"`, and `RelayEnabled="0"`.

### Session: 2026-08-14 (Wildcard SSL & Multi-Service Proxy Setup)
- **Task:** Configure Let's Encrypt Wildcard SSL (`*.homelab-admin.me`) using Cloudflare DNS-01 challenge and apply to core services.
- **Guide Created:** [`Nginx-Proxy-Manager-LetsEncrypt-SSL-Guide-2026-08-14.md`](file:////opt/homelab-infrastructure/06-Guides/Nginx-Proxy-Manager-LetsEncrypt-SSL-Guide-2026-08-14.md)
- **Cloudflare Integration:**
  - Created Cloudflare DNS API token with `Zone:DNS:Edit` permissions for `homelab-admin.me`.
  - Configured DNS-01 challenge in NPM with 30s propagation delay.
- **Certificates Issued:** Wildcard SSL covering `homelab-admin.me` and `*.homelab-admin.me`.
- **Proxy Hosts Configured:**
  - `auth.homelab-admin.me` $\rightarrow$ `http://192.168.110.225:9000` (Authentik)
  - `photos.homelab-admin.me` $\rightarrow$ `http://192.168.110.47:2283` (Immich)
  - `media.homelab-admin.me` $\rightarrow$ `http://192.168.1.126:8096` (Jellyfin)
- **Security Toggles:** Enforced **Force SSL** (301 redirect), **HTTP/2**, **HSTS**, and **Websockets** on all proxy hosts.

### Session: 2026-05-15 (Initial Deployment & Cloudflare Integration)
- **Task:** Deploy NPM to handle routing for Authentik and future homelab services.
- **Action:** Executed community script `bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/nginxproxymanager.sh)"`.
- **Security Decision:**
    - **Rejected** the standard "Step 3" recommendation to open ports 80/443 on the router.
    - **Opted** for integration with existing **Cloudflare Tunnels** to maintain a "No-Open-Ports" security posture.
- **Cloudflare Configuration:**
    - Added Public Hostname `auth.homelab-admin.me` inside the `Bulakan-CF1` tunnel.
    - Pointed the service to `http://192.168.1.210:80`.

---

## 🔧 Maintenance & Operations

### Useful Commands
Run these inside the LXC Console:

**Check Logs:**
```bash
# NPM doesn't use standard systemd logs for access; check the logs dir
ls /data/logs
tail -f /data/logs/proxy-host-1_access.log
```

**Test Certbot Auto-Renewal:**
```bash
certbot renew --dry-run
```

**Restart Services:**
```bash
systemctl restart nginx-proxy-manager
```

### Key Paths
- **Data Directory:** `/data` (DB, Certificates, Configs)
- **Let's Encrypt:** `/etc/letsencrypt`
- **Live Certs:** `/data/tls/certbot/live/`

---

## 🚀 Next Steps
- [x] Configure Let's Encrypt Wildcard SSL (`*.homelab-admin.me`) via Cloudflare DNS-01 API challenge.
- [x] Migrate core services (`auth`, `photos`, `media`) to NPM routing with wildcard SSL.
- [ ] Configure **Forward Auth** using Authentik Proxy Outpost.
- [ ] Migrate Plex (`192.168.1.215:32400`) and Audiobookshelf (`192.168.1.59:13378`) to NPM routing.

