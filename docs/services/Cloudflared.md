# ☁️ Cloudflared Service

The Cloudflared service provides secure, outbound-only tunneling for all homelab services, eliminating the need for open ports on the router.

---

## Current Architecture: Active-Active Redundancy

The homelab uses a redundant dual-node setup to ensure service availability if one Proxmox node goes down.

| Node | Container ID | Hostname | IP Address | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Bulakan** | 304 | `cloudflared` | DHCP | **Primary** |
| **Cebu** | 404 | `cloudflared-cebu` | `192.168.1.7` | **Secondary** |

### Configuration Details
- **Tunnel Name:** `Bulakan-CF1`
- **Data Center:** `lax` (Los Angeles)
- **Authentication:** Token-based systemd service.

---

## Maintenance

### Updating Cloudflared
To update the agent on either node, run:
```bash
apt update && apt install --only-upgrade cloudflared
```

### Restarting Service
```bash
systemctl restart cloudflared
```

---

## Deployment History
- **2026-05-14**: Primary instance established on Bulakan.
- **2026-05-15**: Secondary instance established on Cebu for HA redundancy. Resolved `vnet1` bridge isolation issue during deployment.

---

## Related Documentation
- [[../06-Guides/Cloudflare-Tunnel-Setup]]
- [[../04-Network/Network Overview]]
