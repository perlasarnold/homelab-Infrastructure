# 🔐 Authentik Setup & Operations

Modern identity provider (IdP) and SSO platform for the Homelab-Net homelab.  
**Last Updated:** 2026-05-15

---

## 🛠️ Deployment Details
- **Method:** [Proxmox VE Helper Script](https://community-scripts.org/scripts?id=authentik) (LXC)
- **Node:** Proxmox VE (Bulakan)
- **IP Address:** `VLAN 1 (Management)`
- **Port:** `9000` (HTTP)
- **External URL:** `https://auth.homelab-admin.me` (Routed via NPM + Cloudflare Tunnel)
- **Initial Setup URL:** `http://VLAN 1 (Management):9000/if/flow/initial-setup/`

### Resource Allocation
| Resource | Value |
|----------|-------|
| OS | Debian 13 (Trixie) |
| CPU | 4 vCPU |
| RAM | 4096 MB (4GB) |
| Disk | 16 GB |

---

## 📜 Session Log & Problem History

### Session: 2026-05-15 (Initial Deployment)
- **Task:** Deploy Authentik as a replacement/alternative to enterprise IAM solutions.
- **Action:** Executed community script `bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/authentik.sh)"` in PVE Shell.
- **Problem Encountered:** 
    - Upon visiting the initial setup URL, the page returned a **"Not Found"** error despite the Authentik UI loading.
    - **Diagnosis:** The trailing slash `/` was correctly included, but the background database migrations and "blueprint" applications (which create the setup flow) were still running in the background.
- **Resolution:** 
    - **Patient Wait:** Authentik requires ~2-5 minutes post-install to fully initialize its internal Go/Python stack.
    - Refreshing after the wait period resolved the issue and exposed the Admin account setup.
- **Routing Integration:**
    - Integrated with **Nginx Proxy Manager** (`VLAN 1 (Management)`) for internal proxying.
    - Exposed externally via **Cloudflare Tunnel** (`Bulakan-CF1`) at `auth.homelab-admin.me`.
    - Maintained "No-Open-Ports" security by avoiding router port forwarding.
- **Identity Customization:**
    - Created a personalized administrative account (`homelab-admin`) to replace the default `akadmin`.
    - Assigned the user to the **authentik Admins** group and verified administrative permissions.
    - Standard security practice followed: moving away from default credentials.

---

## 🔧 Maintenance & Operations

### Useful Commands
Run these inside the LXC Console:

**Check Service Status:**
```bash
journalctl -u authentik-server -f  # Web/API logs
journalctl -u authentik-worker -f  # Task/Migration logs
```

**Manual Admin Password Reset:**
*If the initial setup flow is missing or locked out.*
```bash
cd /opt/authentik
uv run python -m manage ak changepassword akadmin
```

**Restart Services:**
```bash
systemctl restart authentik-server authentik-worker
```

### Key Paths
- **Config:** `/etc/authentik/config.yml`
- **Persistent Data:** `/opt/authentik-data` (Certs, Media, GeoIP)
- **App Binaries:** `/opt/authentik`

---

## 🚀 Next Steps
- [x] Configure Nginx Proxy Manager (NPM) for internal proxying.
- [x] Expose externally via Cloudflare Tunnel at `https://auth.homelab-admin.me`.
- [ ] Configure **LDAP Source** (if syncing with existing directory).
- [ ] Set up **Authentik Proxy Outpost** in NPM for Forward Auth.
- [ ] Integrate first application (e.g., Jellyfin or Plex).
