# 🦈 Surfshark VPN Region Change Guide (Gluetun)

- **Date:** May 21, 2026
- **Objective:** Change the connected country/region of the Surfshark VPN tunnel running via the Gluetun Docker container on the Cebu Proxmox host.
- **Maintainer:** Perlas

---

## 🌍 Why Change Regions?
If public trackers (like 1337x or TorrentGalaxy) are blocking your automated searches with "Forbidden" or Cloudflare captchas, the easiest first step is to switch your VPN IP to a different country where the tracker's security rules might be less strict.

## 🛠️ Steps to Change the Region

### 1. Edit the Docker Compose File
On your local Windows machine, open your Arr stack Docker Compose file:
`/opt/homelab-infrastructure\arr-stack-docker-compose.yml`

Find the `gluetun` service block. Under the `environment` section, locate the `SURFSHARK_COUNTRY` variable:

```yaml
  gluetun:
    image: qmcgaw/gluetun
    ...
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=openvpn
      - OPENVPN_USER=YOUR_USER
      - OPENVPN_PASSWORD=YOUR_PASSWORD
      - SURFSHARK_COUNTRY=Brazil # <-- Change this value!
```

Change the country value (e.g., `Netherlands`, `Brazil`, `Switzerland`, `USA`). *Note: Gluetun expects the standard capitalized English name of the country.*

### 2. Push the Changes to Proxmox
Open an SSH terminal to your Proxmox host (`ssh root@192.168.1.26`) and push the updated file into your LXC container (assuming LXC ID `417`):

```bash
# From your Windows machine:
scp /opt/homelab-infrastructure\arr-stack-docker-compose.yml root@192.168.1.26:/root/docker-compose.yml

# Then, SSH into Proxmox and push it into the LXC:
ssh root@192.168.1.26
pct push 417 /root/docker-compose.yml /root/arr-stack/docker-compose.yml
```

### 3. Restart the Docker Stack
Still in your Proxmox SSH session, execute the Docker command inside the LXC container to apply the new region:

```bash
pct exec 417 -- bash -c 'cd /root/arr-stack && docker compose up -d'
```

Gluetun will automatically tear down the old OpenVPN tunnel and establish a new one with the newly specified country. All connected containers (Prowlarr, Jackett, FlareSolverr) will temporarily lose internet access for about 15 seconds while the new tunnel establishes.

---

## ✅ Outcome
The Surfshark VPN tunnel will now route all indexer traffic through the newly specified country, potentially bypassing geographic blocks or Cloudflare IP bans.
