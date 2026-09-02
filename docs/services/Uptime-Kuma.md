# ⏱️ Uptime Kuma Service Monitor

* **Category:** Monitoring / Uptime & Alerting
* **Node:** Cebu (`192.168.1.26`)
* **LXC ID:** CT 419
* **VLAN Segment:** VLAN 110 (Services)
* **IP Address:** `192.168.110.61`
* **Web UI / DNS:** `https://kuma.perlasarnold.me` (Port 3001)
* **Runtime:** Docker Engine (`louislam/uptime-kuma:1`) inside LXC with `nesting=true`
* **Networking Mode:** Host Network (`--network=host`) for direct local split-horizon DNS resolution
* **Authentication:** Local User / Authentik Forward-Auth via Nginx Proxy Manager
* **Managed By:** Ansible (`roles/uptime_kuma`) & Terraform (`cebu.tf`)

---

## 🎯 Key Capabilities

* **27 Pre-Configured Homelab Monitors:** Proxmox hypervisors (192.168.1.25/26/27), Synology NAS (PNAS), Pi-holes, NPM, Cloudflared tunnels, Authentik SSO, Wazuh SIEM, Fail2Ban, Grafana, Immich, Media servers (Plex, Jellyfin), and Arr stack.
* **Probing Mechanisms:** HTTP/HTTPS status verification (with SSL validation), TCP Port checks (Proxmox 8006, HAOS 8123), and ICMP Pings.
* **Central Alert Dispatch:** Ready for Discord, Telegram, Pushover, and Webhooks.
* **Redundant Placement:** Hosted on Cebu to guarantee continuous visibility even during maintenance of the primary Bulakan node.

---

## 🛠️ Verification & Maintenance

```bash
# Check container status
pct exec 419 -- docker ps

# View live probe heartbeats
pct exec 419 -- docker logs --tail 50 -f uptime-kuma

# Restart service
pct exec 419 -- docker restart uptime-kuma
```
