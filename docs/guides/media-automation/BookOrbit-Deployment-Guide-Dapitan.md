# BookOrbit Deployment & Configuration Guide (Dapitan)

**Date:** August 22, 2026  
**Objective:** Deploy BookOrbit on Proxmox node **Dapitan** (`192.168.1.27`), mount the Synology NAS ebook library `\\pnas\Media\Ebooks` persistently, configure SERVICES VLAN 110 segmentation, establish LAN DNS & SSL reverse proxy routing on `bookorbit.perlasarnold.me`, and configure the default administrator credentials.

---

## 🏗️ Architecture & Resulting Layout

| Layer | Component / Location | Specification / Detail |
|:---|:---|:---|
| **Hypervisor Node** | Dapitan | Dell OptiPlex 7050 SFF (`192.168.1.27`) |
| **Container Platform** | LXC CT 514 (`bookorbit-dapitan`) | Ubuntu 24.04 LTS, 2 vCPUs, 2048 MB RAM, 16 GB SSD (`vm-fast`) |
| **Network & VLAN** | **SERVICES VLAN 110** | IP: `192.168.110.50/24`, Gateway: `192.168.110.1`, DNS: `192.168.1.5` |
| **Storage Source** | Synology PNAS SMB | `//192.168.1.12/Media/Ebooks` (`\\pnas\Media\Ebooks`) & `//192.168.1.12/Media/Audiobooks` (`M:\Audiobooks`) |
| **Host Mount Point** | Dapitan Host | `/mnt/bindmounts/ebooks` & `/mnt/bindmounts/audiobooks` via CIFS (`/root/.pnascredentials`) |
| **Container Mount** | CT 514 Bind Mount | `mp0: /mnt/bindmounts/ebooks,mp=/mnt/ebooks` (`/books:ro`) & `mp1: /mnt/bindmounts/audiobooks,mp=/mnt/audiobooks` (`/audiobooks:ro`) |
| **Database** | PostgreSQL + pgvector | `pgvector/pgvector:pg17` (`/opt/bookorbit/data/postgres`) |
| **Reverse Proxy** | Nginx Proxy Manager (Cebu CT 105) | `192.168.120.211` $\rightarrow$ `http://192.168.110.50:3000` |
| **LAN DNS** | Pi-hole (`192.168.1.5`) | `bookorbit.perlasarnold.me` $\rightarrow$ `192.168.120.211` |
| **SSL / TLS** | Wildcard Certificate | `*.perlasarnold.me` (Cloudflare DNS-01 API) |
| **Default Admin** | Setup Onboarding | User: `perlasarnold` |

---

## 🌐 Network & VLAN Rationale

BookOrbit is classified as an **internal application & media service**, operating alongside Plex (`192.168.110.44`), Jellyfin (`192.168.110.43`), Immich (`192.168.110.47`), and Photoview (`192.168.110.48`).

1. **Isolation**: Placing BookOrbit in **SERVICES VLAN 110** isolates it from hypervisor management interfaces (VLAN 10) and IoT peripherals (VLAN 30).
2. **Access Control**: UniFi firewall rules permit incoming traffic to port 3000 exclusively from the Nginx Proxy Manager reverse proxy on **DMZ VLAN 120** (`192.168.120.211`) and trusted admin clients on **TRUSTED VLAN 20**.
3. **Storage Access**: Inter-VLAN rules allow SERVICES VLAN 110 to communicate with Synology NAS storage over CIFS/SMB (Port 445).

---

## 🚀 Step-by-Step Implementation

### Step 1: Configure Persistent Synology SMB Mount on Dapitan Host

1. Create the host bind mount directory on Dapitan:
   ```bash
   mkdir -p /mnt/bindmounts/ebooks /mnt/bindmounts/audiobooks
   ```
2. Verify that `/root/.pnascredentials` exists with Synology NAS credentials (`username=` and `password=`).
3. Add the persistent mount entry to `/etc/fstab` on Dapitan:
   ```fstab
   //192.168.1.12/Media/Ebooks /mnt/bindmounts/ebooks cifs credentials=/root/.pnascredentials,iocharset=utf8,vers=3.0,uid=0,gid=0,file_mode=0775,dir_mode=0775,noperm,nobrl,_netdev,nofail,x-systemd.automount 0 0
   //192.168.1.12/Media/Audiobooks /mnt/bindmounts/audiobooks cifs credentials=/root/.pnascredentials,iocharset=utf8,vers=3.0,uid=0,gid=0,file_mode=0775,dir_mode=0775,noperm,nobrl,_netdev,nofail,x-systemd.automount 0 0
   ```
4. Mount the shares and reload systemd:
   ```bash
   systemctl daemon-reload
   mount -a
   ```

### Step 2: Provision LXC Container (CT 514) on Dapitan

1. Create unprivileged LXC container CT 514 on `vm-fast`:
   ```bash
   pct create 514 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
       --ostype ubuntu \
       --hostname bookorbit-dapitan \
       --memory 2048 \
       --swap 1024 \
       --cores 2 \
       --rootfs vm-fast:16 \
       --net0 name=eth0,bridge=vmbr0,tag=110,ip=192.168.110.50/24,gw=192.168.110.1,type=veth \
       --nameserver 192.168.1.5 \
       --features nesting=1,keyctl=1 \
       --unprivileged 0 \
       --onboot 1
   ```
2. Configure AppArmor unconfined profile and mount points in `/etc/pve/lxc/514.conf`:
   ```text
   lxc.apparmor.profile: unconfined
   mp0: /mnt/bindmounts/ebooks,mp=/mnt/ebooks
   mp1: /mnt/bindmounts/audiobooks,mp=/mnt/audiobooks
   ```
3. Start the container:
   ```bash
   pct start 514
   ```

### Step 3: Install Docker CE & Nested Container Runtime inside CT 514

1. Inside CT 514 (`pct enter 514`), install prerequisites and official Docker CE repository:
   ```bash
   apt-get update -y
   apt-get install -y ca-certificates curl gnupg lsb-release python3 jq openssl git
   install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
   chmod a+r /etc/apt/keyrings/docker.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
   apt-get update -y
   apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   systemctl enable --now docker
   ```
2. Install the OCI runc AppArmor wrapper at `/usr/bin/runc` to ensure nested Docker containers execute reliably.

### Step 4: Deploy BookOrbit Docker Compose Stack

1. Create application structure:
   ```bash
   mkdir -p /opt/bookorbit/data/app /opt/bookorbit/data/postgres
   cd /opt/bookorbit
   ```
2. Create `/opt/bookorbit/docker-compose.yml`:
   ```yaml
   name: bookorbit

   services:
     app:
       container_name: bookorbit-app
       image: ${APP_IMAGE:-ghcr.io/bookorbit/bookorbit:latest}
       restart: unless-stopped
       init: true
       env_file:
         - .env
       ports:
         - "${APP_PORT:-3000}:${PORT:-3000}"
       environment:
         NODE_ENV: production
         PORT: ${PORT:-3000}
         DATABASE_URL: ${DATABASE_URL:-}
         POSTGRES_HOST: ${POSTGRES_HOST:-postgres}
         POSTGRES_PORT: ${POSTGRES_PORT:-5432}
         POSTGRES_USER: ${POSTGRES_USER}
         POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
         POSTGRES_DB: ${POSTGRES_DB}
         JWT_SECRET: ${JWT_SECRET}
         SETUP_BOOTSTRAP_TOKEN: ${SETUP_BOOTSTRAP_TOKEN}
         APP_URL: ${APP_URL}
         CLIENT_URL: ${CLIENT_URL:-${APP_URL}}
         PUID: ${PUID:-0}
         PGID: ${PGID:-0}
         NODE_MAX_OLD_SPACE_SIZE: ${NODE_MAX_OLD_SPACE_SIZE:-2048}
       volumes:
         - /mnt/ebooks:/books:ro
         - /mnt/audiobooks:/audiobooks:ro
         - /opt/bookorbit/data/app:/app/data
       depends_on:
         postgres:
           condition: service_healthy

     postgres:
       container_name: bookorbit-postgres
       image: pgvector/pgvector:pg17
       restart: unless-stopped
       environment:
         POSTGRES_USER: ${POSTGRES_USER}
         POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
         POSTGRES_DB: ${POSTGRES_DB}
       volumes:
         - /opt/bookorbit/data/postgres:/var/lib/postgresql/data
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
         interval: 5s
         timeout: 5s
         retries: 5
   ```
3. Start the stack:
   ```bash
   docker compose up -d
   ```

### Step 5: Configure Reverse Proxy (Nginx Proxy Manager on Cebu CT 105)

1. Deployed `/data/nginx/proxy_host/13.conf` in NPM with Let's Encrypt Wildcard SSL.
2. Verified routing for `bookorbit.perlasarnold.me` $\rightarrow$ `http://192.168.110.50:3000`.

---

## 🔄 Operations & Maintenance

### Check Stack Status
```bash
pct exec 514 -- docker compose -f /opt/bookorbit/docker-compose.yml ps
```

### Restart Stack
```bash
pct exec 514 -- docker compose -f /opt/bookorbit/docker-compose.yml restart
```
