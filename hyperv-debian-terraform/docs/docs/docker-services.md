# Docker Services — Homelab Reference

All services are deployed via:
**Actions → Docker Deploy → (pick service)**

Secrets are SOPS-encrypted in `secrets/*.env.enc`. Port reference below.

---

## Service Map

| Service | Deploy name | Port | Access method | r/homelab ★ |
|---|---|---|---|---|
| **Portainer** | `portainer` | 9000 | Tailscale | ★★★★★ |
| **Nginx Proxy Manager** | `nginx-proxy-manager` | 81 (admin) | Tailscale | ★★★★★ |
| **Pi-hole** | `pihole` | 8080 | Tailscale | ★★★★★ |
| **Jellyfin** | `jellyfin` | host | Tailscale | ★★★★★ |
| **Nextcloud** | `nextcloud` | 8081 | Cloudflare + Tailscale | ★★★★☆ |
| **Grafana** | `monitoring` | 3000 | Tailscale | ★★★★★ |
| **Prometheus** | `monitoring` | 9090 | Tailscale only | — |
| **Uptime Kuma** | `uptime-kuma` | 3001 | Tailscale | ★★★★★ |
| **Vaultwarden** | `vaultwarden` | 8083 | Cloudflare + HTTPS | ★★★★★ |
| **Immich** | `immich` | 2283 | Tailscale | ★★★★★ |
| **Wiki.js** | `wikijs` | 3005 | Cloudflare | ★★★★☆ |
| **Guacamole** | `guacamole` | 8085 | Tailscale only | ★★★★☆ |
| **Cloudflare Tunnel** | `cloudflared` | — | — | — |
| **Tailscale** | `tailscale` | — | — | — |
| **Jupyter Lab** | `jupyter` | 8888 | Tailscale (on-demand) | — |

---

## Recommended Deployment Order

```
1. tailscale          → join tailnet (access all services safely)
2. portainer          → Docker UI
3. uptime-kuma        → monitor everything from the start
4. nginx-proxy-manager → set up SSL before exposing anything
5. cloudflared        → expose NPM publicly with HTTPS
6. pihole             → network-wide ad blocking
7. wikijs             → deploy the docs
8. vaultwarden        → password manager (needs HTTPS via NPM first)
9. monitoring         → Grafana dashboards
10. as needed...
```

---

## Storage Footprint (approximate)

| Service | Image size | Data volume |
|---|---|---|
| Portainer | 80 MB | < 100 MB |
| NPM | 100 MB | < 50 MB |
| Pi-hole | 150 MB | < 50 MB |
| Jellyfin | 400 MB | + your media |
| Nextcloud | 800 MB | + user data |
| Monitoring stack | 600 MB | ~1 GB/month metrics |
| Uptime Kuma | 200 MB | < 50 MB |
| Vaultwarden | 15 MB | < 50 MB |
| Immich | 2 GB (ML) | + your photos |
| Wiki.js | 300 MB | < 100 MB |
| Guacamole | 350 MB | < 50 MB |
| Tailscale | 20 MB | < 10 MB |
| cloudflared | 30 MB | none |

!!! tip "Minimising storage"
    - All images use `restart: unless-stopped` (not `always`) so containers don't start until needed
    - Jupyter uses `restart: "no"` — only start it when analysing, then stop
    - Log rotation is enforced by Docker daemon (10MB max, 3 files)
    - Monthly maintenance automatically prunes unused images older than 7 days
