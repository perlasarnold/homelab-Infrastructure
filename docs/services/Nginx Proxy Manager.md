# 🌐 Nginx Proxy Manager (NPM) Setup & Operations

Centralized reverse proxy for managing SSL certificates and subdomain routing.  
**Last Updated:** 2026-08-23

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
| `*.perlasarnold.me`, `perlasarnold.me` | Let's Encrypt / DNS-01 | Cloudflare API Token (`Zone:DNS:Edit`) | Auto-renewed via NPM scheduler |

### Active Proxy Hosts
| `sonarr.perlasarnold.me` | `http://192.168.110.42:8989` | Sonarr TV Automation (Cebu CT 417) | `*.perlasarnold.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `torrent.perlasarnold.me` | `http://192.168.110.42:8080` | qBittorrent BitTorrent (Cebu CT 417) | `*.perlasarnold.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |
| `home.perlasarnold.me` | `http://192.168.1.250:3000` | Homepage Dashboard (Bulakan CT 116) | `*.perlasarnold.me` | Force SSL, HTTP/2, HSTS, Websockets | 🟢 Online |

---

## 📜 Session Log & Problem History

### Session: 2026-08-23 (Audiobook & Ebook Arr Stack and Bindery Deployment)
- **Task:** Deploy modern book/audiobook automation manager (Bindery) on Cebu CT 417, mount `M:\Audiobooks` (`//192.168.1.12/Media/Audiobooks`), and configure reverse proxy on `readarr.perlasarnold.me`.
- **Guide Created:** [`Audiobook-and-Ebook-Arr-Stack-Deployment-Guide-2026-08-23.md`](file:///c:/Users/Perlas/Documents/Github/homelab/docs/guides/media-automation/Audiobook-and-Ebook-Arr-Stack-Deployment-Guide-2026-08-23.md)
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/14.conf` on Cebu CT 105 (`192.168.120.211`).
  - Attached Let's Encrypt wildcard certificate `*.perlasarnold.me` with Force SSL and HTTP/2.
  - Verified zero downtime reload and HTTP/2 200 response on `https://readarr.perlasarnold.me`.

### Session: 2026-08-22 (Homepage Dashboard & Transmission Reverse Proxy Setup)
- **Task:** Configure Nginx Proxy Manager reverse proxy and Wildcard SSL routing for `home.perlasarnold.me` (`192.168.1.250:3000`) and `torrent.perlasarnold.me` (`192.168.110.42:9091`).
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/16.conf` (`torrent.perlasarnold.me`) and `/data/nginx/proxy_host/17.conf` (`home.perlasarnold.me`) on Cebu CT 105 (`192.168.120.211`).
  - Synchronized SQLite `proxy_host` table entries (Host IDs 16 and 17) with wildcard certificate `*.perlasarnold.me`.
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Added DNS records to Pi-hole `custom.list` on Cebu CT 401 and Bulakan CT 301.
  - Verified Nginx configuration syntax (`nginx -t`) and executed graceful reload (`nginx -s reload`) with zero downtime.

### Session: 2026-08-22 (Sonarr Reverse Proxy & Wildcard SSL Configuration)
- **Task:** Configure Nginx Proxy Manager reverse proxy routing for `sonarr.perlasarnold.me` pointing to Cebu Arr Stack CT 417 (`http://192.168.110.42:8989`).
- **Guide Created:** [`Sonarr-NPM-Reverse-Proxy-Guide-2026-08-22.md`](file:///c:/Users/Perlas/Documents/Github/homelab/06-Guides/Sonarr-NPM-Reverse-Proxy-Guide-2026-08-22.md)
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/15.conf` on Cebu CT 105 (`192.168.120.211`).
  - Synchronized SQLite `proxy_host` table entry (Host ID 15) with wildcard certificate `*.perlasarnold.me` (`certificate_id: 3`).
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Verified Nginx configuration syntax (`nginx -t`) and executed graceful reload (`nginx -s reload`) with zero downtime.

### Session: 2026-08-22 (BookOrbit Reverse Proxy & Wildcard SSL Configuration)
- **Task:** Configure Nginx Proxy Manager reverse proxy routing for `bookorbit.perlasarnold.me` pointing to Dapitan BookOrbit CT 514 (`http://192.168.110.50:3000`).
- **Guide Created:** [`BookOrbit-Deployment-Guide-Dapitan.md`](file:///c:/Users/Perlas/Documents/Github/homelab/06-Guides/BookOrbit-Deployment-Guide-Dapitan.md)
- **Actions Taken:**
  - Deployed `/data/nginx/proxy_host/13.conf` on Cebu CT 105 (`192.168.120.211`).
  - Bound Let's Encrypt wildcard certificate `*.perlasarnold.me` (`/etc/letsencrypt/live/npm-3/`).
  - Enforced Force SSL (HTTP 301 $\rightarrow$ HTTPS), HTTP/2, HSTS (`max-age=63072000; preload`), and Websocket upgrades.
  - Verified Nginx configuration syntax and performed graceful daemon reload with zero downtime.

---

## 🔧 Maintenance & Operations

### Useful Commands
Run these inside the LXC Console:

**Check Logs:**
```bash
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
