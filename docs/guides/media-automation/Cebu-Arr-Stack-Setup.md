# 🎞️ Cebu Arr Stack Setup Guide

- **Date:** May 20, 2026
- **Objective:** Provision a dedicated Arr stack (Sonarr, Radarr, Bazarr, Wizarr, Prowlarr, Jackett, FlareSolverr) running on Docker Compose within an LXC container on the Cebu Proxmox host, secured by a Surfshark VPN (Gluetun).
- **Maintainer:** Perlas

---

## 🖥️ System Specifications & Context

The Arr stack is deployed on the secondary Proxmox node (`Cebu`) to distribute the workload and utilize Docker Compose inside a lightweight Debian LXC container. This follows community best-practices for resource efficiency while utilizing Nesting for Docker support.

| Parameter | Specification | Rationale |
| :--- | :--- | :--- |
| **Host Node** | `Cebu` (192.168.1.26) | Workload distribution across the homelab cluster. |
| **Instance Type** | Unprivileged LXC + Nesting | Required to run Docker securely within an LXC with minimal resource overhead. |
| **Operating System** | Debian 12 | Stable foundation for Docker workloads. |
| **CPU Allocation** | 2 Cores | Sufficient for API polling, UI serving, and lightweight tasks. |
| **RAM Allocation** | 2048 MiB (2 GiB) | Lightweight allocation; containers share resources efficiently. |
| **Storage (Media)** | TrueNAS SMB | Centralized media storage (`DAS1-18TB\seagate\share`) mounted on the host and bind-mounted to the LXC. |

---

## 🛠️ Phase 1: Proxmox Host & LXC Provisioning

### 1. Host Storage Mapping
Because unprivileged LXCs cannot safely mount SMB shares directly, the TrueNAS storage must be mounted to the Cebu Proxmox host and bind-mounted into the LXC.

1. SSH into the **Cebu Host** (`192.168.1.26`).
2. Create the mount point:
   ```bash
   mkdir -p /mnt/truenas/seagate
   ```
3. Append the CIFS mount to `/etc/fstab` (using your existing `/etc/samba/credentials-seagate` file):
   ```text
   //192.168.1.211/seagate /mnt/truenas/seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,uid=100000,gid=100000,file_mode=0775,dir_mode=0775,nofail 0 0
   ```
   *(Note: `uid=100000,gid=100000` maps to the unprivileged root inside the LXC)*
5. Mount the share:
   ```bash
   mount -a
   ```

### 2. LXC Creation
1. Provision a new Debian 12 LXC container on the Cebu node.
2. Ensure **Nesting** and **Keyctl** are enabled in the container options (`features: keyctl=1,nesting=1`).
3. Add the Bind Mount to pass the media directory into the container. Edit the container conf (`/etc/pve/lxc/VMID.conf`):
   ```text
   mp0: /mnt/truenas/seagate/share,mp=/mnt/truenas/seagate/share
   ```
4. Start the container and log in via SSH or the Proxmox Console.

---

## 🐋 Phase 2: Docker & Docker Compose Setup

Install the Docker engine inside the LXC container.

```bash
# Update repositories
apt update && apt upgrade -y

# Install dependencies
apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Compose
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

---

## 📦 Phase 3: The Arr Stack Docker Compose (with Surfshark VPN)

Because Jackett connects to external torrent trackers, we route it through a **Gluetun** container configured with Surfshark to prevent ISP tracking.

1. Create the project directory:
   ```bash
   mkdir -p ~/arr-stack
   cd ~/arr-stack
   ```
2. Create the `docker-compose.yml` file:
   ```bash
   nano docker-compose.yml
   ```
3. Paste the following declarative configuration:

```yaml
services:
  gluetun:
    image: qmcgaw/gluetun
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "9117:9117" # Expose Jackett Web UI through the VPN
      - "9696:9696" # Expose Prowlarr Web UI through the VPN
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=openvpn
      - OPENVPN_USER=YOUR_SURFSHARK_SERVICE_USER
      - OPENVPN_PASSWORD=YOUR_SURFSHARK_SERVICE_PASSWORD
      - SURFSHARK_COUNTRY=Netherlands
      - FIREWALL_OUTBOUND_SUBNETS=192.168.1.0/24 # Required to access Jackett from your LAN
      - TZ=America/Los_Angeles
    restart: always

  jackett:
    image: lscr.io/linuxserver/jackett:latest
    container_name: jackett
    network_mode: "service:gluetun" # Routes all Jackett traffic through the VPN
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/jackett:/config
      - /mnt/truenas/seagate/share/downloads:/downloads
    depends_on:
      gluetun:
        condition: service_healthy
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    network_mode: "service:gluetun" # Routes all Prowlarr traffic through the VPN
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/prowlarr:/config
    depends_on:
      gluetun:
        condition: service_healthy
    restart: unless-stopped

  flaresolverr:
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    network_mode: "service:gluetun" # Must share VPN IP with Prowlarr
    environment:
      - LOG_LEVEL=info
      - TZ=America/Los_Angeles
    depends_on:
      gluetun:
        condition: service_healthy
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/sonarr:/config
      - /mnt/truenas/seagate/share:/data/media
    ports:
      - "8989:8989"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/radarr:/config
      - /mnt/truenas/seagate/share:/data/media
    ports:
      - "7878:7878"
    restart: unless-stopped

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
    volumes:
      - ./config/bazarr:/config
      - /mnt/truenas/seagate/share:/data/media
    ports:
      - "6767:6767"
    restart: unless-stopped

  wizarr:
    image: ghcr.io/wizarrrr/wizarr:latest
    container_name: wizarr
    environment:
      - TZ=America/Los_Angeles
    volumes:
      - ./config/wizarr:/data/database
    ports:
      - "5690:5690"
    restart: unless-stopped
```

4. Launch the stack:
   ```bash
   docker compose up -d
   ```

---

## 🔗 Phase 4: Integration & Operations

### 1. Web UI Accessibility
Navigate to the LXC container's IP address (e.g., `http://192.168.1.X`) on the respective ports to configure the applications:
- **Sonarr:** `http://<IP>:8989`
- **Radarr:** `http://<IP>:7878`
- **Bazarr:** `http://<IP>:6767`
- **Prowlarr:** `http://<IP>:9696` (Traffic passes through Gluetun securely)
- **Jackett:** `http://<IP>:9117` (Traffic passes through Gluetun securely)
- **Wizarr:** `http://<IP>:5690`

### 2. Standardizing Root Folders
When configuring Radarr and Sonarr, navigate to **Settings > Media Management** and ensure the Root Folders are set to the newly mapped bind mount:
- Movies: `/data/media/movies` (or wherever your `share` directory organizes them)
- TV Shows: `/data/media/tv`

### 3. Connecting Jackett securely over the VPN
1. In Jackett, configure your desired indexers. All indexer connections are naturally routed through Surfshark.
2. Copy the **API Key** from the top right corner of the Jackett Web UI.
3. In Sonarr/Radarr, navigate to **Settings > Indexers > Add > Torznab**.
4. Because Jackett is attached to the `gluetun` network namespace, you must use the `gluetun` container name for the URL inside Docker: 
   `http://gluetun:9117/api/v2.0/indexers/<indexer_name>/results/torznab/`
5. Paste the API key and save.

> [!TIP]  
> To test that Jackett is correctly using the VPN, you can execute a curl command inside the Jackett container:  
> `docker exec -it jackett curl https://ifconfig.me`  
> The returned IP should be a Surfshark server IP, not your home IP.

## ✅ Outcome
- The Debian LXC container (`arr-stack-cebu`, IP `192.168.1.42`) was successfully provisioned with Nesting and Keyctl enabled.
- The TrueNAS SMB share (`/mnt/truenas/seagate/share`) was mapped to the host and bind-mounted to the LXC for native I/O performance.
- Gluetun was successfully configured with Surfshark OpenVPN credentials, ensuring encrypted routing for Jackett.
- Sonarr, Radarr, Bazarr, Prowlarr, Jackett, FlareSolverr, and Wizarr were successfully deployed via Docker Compose and are accessible on the network.

---

## 📚 References
- [LinuxServer.io Fleet Setup](https://docs.linuxserver.io/)
- [Gluetun VPN Client Documentation](https://github.com/qdm12/gluetun-wiki/tree/main)
- [[Transmission-VPN-Proxmox-Setup]] — Guide for connecting the download client to this stack.
