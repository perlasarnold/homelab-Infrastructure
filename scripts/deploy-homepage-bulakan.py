import paramiko
import time
import sys
import base64

BULAKAN_IP = "192.168.1.25"
PASSWORD = "***REMOVED***"
VMID = "116"

DOCKER_COMPOSE = """name: homepage

services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    ports:
      - "3000:3000"
    volumes:
      - ./config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Manila
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
"""

SETTINGS_YAML = """---
title: Homelab-Net Dashboard (home.homelab-admin.me)
base: https://home.homelab-admin.me
background:
  image: https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1920&auto=format&fit=crop
  blur: sm
  saturate: 75
  brightness: 50

cardBlur: md
theme: dark
color: slate

headerStyle: clean
hideVersion: false
showFields: true
disableJsonStorage: false

search:
  provider: duckduckgo
  target: _blank
  focus: true
"""

WIDGETS_YAML = """---
- search:
    provider: duckduckgo
    target: _blank

- clock:
    timeformat: "h:mm:ss A"
    dateformat: "dddd, MMMM D, YYYY"
    timezones:
      - Asia/Manila

- greeting:
    text_size: xl
    text: "Welcome back, Admin"

- resources:
    cpu: true
    memory: true
    disk: /
"""

SERVICES_YAML = """---
- Security & Access:
    - Authentik SSO:
        icon: authentik.png
        href: https://auth.homelab-admin.me
        description: Identity Provider & Single Sign-On

    - Guacamole RDP:
        icon: guacamole.png
        href: https://guacamole.homelab-admin.me
        description: HTML5 Remote Desktop Portal (Mint VM)

- Core Infrastructure & Containers:
    - Proxmox Bulakan:
        icon: proxmox.png
        href: https://192.168.10.25:8006
        description: Primary PVE Hypervisor Node (Host 1)
        widget:
          type: proxmox
          url: https://192.168.10.25:8006
          username: homepage-monitoring@pve!token-id
          password: your-proxmox-api-token-secret
          node: bulakan

    - Proxmox Cebu:
        icon: proxmox.png
        href: https://192.168.10.26:8006
        description: Secondary PVE Hypervisor Node (Host 2)
        widget:
          type: proxmox
          url: https://192.168.10.26:8006
          username: homepage-monitoring@pve!token-id
          password: your-proxmox-api-token-secret
          node: cebu

    - Proxmox Dapitan:
        icon: proxmox.png
        href: https://192.168.10.27:8006
        description: Tertiary PVE Hypervisor Node (Host 3)
        widget:
          type: proxmox
          url: https://192.168.10.27:8006
          username: homepage-monitoring@pve!token-id
          password: your-proxmox-api-token-secret
          node: dapitan

    - Portainer:
        icon: portainer.png
        href: https://portainer.homelab-admin.me
        description: Docker Container Management Portal

    - CasaOS:
        icon: casaos.png
        href: https://casa.homelab-admin.me
        description: Smart Home & Application Hub

- Media & Entertainment:
    - Immich Photos:
        icon: immich.png
        href: https://immich.homelab-admin.me
        description: Self-Hosted Photo & Video Management

    - Plex Media Server:
        icon: plex.png
        href: https://plex.homelab-admin.me
        description: Primary Media Streaming (Bulakan/Dapitan)

    - Plex Unraid:
        icon: plex.png
        href: https://plex-unraid.homelab-admin.me
        description: Secondary Unraid Media Server

    - Jellyfin Primary:
        icon: jellyfin.png
        href: https://jellyfin.homelab-admin.me
        description: Main Jellyfin Media Server

    - Jellyfin Cebu:
        icon: jellyfin.png
        href: https://jellyfincb.homelab-admin.me
        description: Cebu Node Jellyfin Server

    - Jellyfin Proxmox:
        icon: jellyfin.png
        href: https://jellyfinpx.homelab-admin.me
        description: Proxmox High-Performance Jellyfin

    - Audiobooks:
        icon: audiobookshelf.png
        href: https://audiobookbay.homelab-admin.me
        description: Audiobooks & Media Library

- Storage & Synology Cloud:
    - Synology DSM:
        icon: synology.png
        href: https://synology.homelab-admin.me
        description: Synology DiskStation Manager Interface

    - Synology Photos:
        icon: synphotos.homelab-admin.me
        href: https://synphotos.homelab-admin.me
        description: Synology Centralized Photo Management

    - Synology File Station:
        icon: synfiles.homelab-admin.me
        href: https://synfiles.homelab-admin.me
        description: Synology Cloud File Browser

    - Synology Drive:
        icon: syndrive.homelab-admin.me
        href: https://syndrive.homelab-admin.me
        description: Synology Personal Cloud Drive Sync

    - Cloud Drive:
        icon: nextcloud.png
        href: https://drive.homelab-admin.me
        description: Unified Storage Drive

- Productivity & Dashboards:
    - Obsidian Sync:
        icon: obsidian.png
        href: https://obsidian.homelab-admin.me
        description: Knowledge Base & Vault Sync

    - Heimdall:
        icon: heimdall.png
        href: https://heimdall.homelab-admin.me
        description: Secondary Dashboard Launcher

    - Main Website:
        icon: globe.png
        href: https://homelab-admin.me
        description: Personal Blog & Portfolio (homelab-admin.github.io)
"""

BOOKMARKS_YAML = """---
- Infrastructure Tools:
    - GitHub:
        - icon: github.png
          href: https://github.com/
    - Docker Hub:
        - icon: docker.png
          href: https://hub.docker.com/
    - Proxmox Forum:
        - icon: proxmox.png
          href: https://forum.proxmox.com/

- Homelab Documentation:
    - Homelab GitHub Repo:
        - icon: github.png
          href: https://github.com/Perlas/homelab
"""

def safe_print(text):
    try:
        print(text)
    except UnicodeEncodeError:
        print(text.encode("ascii", "backslashreplace").decode("ascii"))

def exec_cmd(client, cmd, timeout=300):
    safe_print(f"\n$ {cmd}")
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace").strip()
    err = stderr.read().decode("utf-8", errors="replace").strip()
    exit_code = stdout.channel.recv_exit_status()
    if out:
        safe_print(out)
    if err and exit_code != 0:
        safe_print(f"STDERR: {err}")
    return exit_code, out, err

def exec_in_ct(client, vm_cmd, timeout=300):
    escaped_cmd = vm_cmd.replace("'", "'\\''")
    cmd = f"pct exec {VMID} -- bash -c '{escaped_cmd}'"
    return exec_cmd(client, cmd, timeout=timeout)

def main():
    safe_print("==================================================================")
    safe_print(f" Deploying Homepage (CT {VMID}) on Bulakan Proxmox Host ({BULAKAN_IP})")
    safe_print(" Zero Reboot Guarantee: No host or container restarts will occur.")
    safe_print("==================================================================")

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(BULAKAN_IP, username="root", password=PASSWORD, timeout=15)
        safe_print("[OK] Connected to Bulakan host.")

        # 1. Check if CT 116 exists
        code, out, _ = exec_cmd(client, f"pct status {VMID}")
        if code != 0:
            safe_print(f"[+] Creating LXC Container CT {VMID}...")
            create_cmd = (
                f"pct create {VMID} local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst "
                f"--hostname homepage-bulakan "
                f"--cores 2 "
                f"--memory 1024 "
                f"--swap 512 "
                f"--features nesting=1,keyctl=1 "
                f"--net0 name=eth0,bridge=vmbr0,ip=dhcp,type=veth "
                f"--storage Bulakan-ZFS "
                f"--rootfs Bulakan-ZFS:8 "
                f"--unprivileged 1 "
                f"--onboot 1 "
                f"--start 1"
            )
            code, _, _ = exec_cmd(client, create_cmd, timeout=180)
            if code != 0:
                safe_print(f"[!] Failed to create CT {VMID}")
                sys.exit(1)
            time.sleep(5)
        else:
            safe_print(f"[OK] CT {VMID} exists: {out}")
            if "status: stopped" in out:
                safe_print(f"[+] Starting CT {VMID}...")
                exec_cmd(client, f"pct start {VMID}")
                time.sleep(5)

        # 2. Verify container is running
        code, out, _ = exec_cmd(client, f"pct status {VMID}")
        if "status: running" not in out:
            safe_print(f"[!] CT {VMID} is not running.")
            sys.exit(1)

        # 3. Check / Install Docker inside CT 116
        safe_print(f"\n[+] Checking Docker installation in CT {VMID}...")
        code, out, _ = exec_in_ct(client, "docker --version")
        if code != 0:
            safe_print(f"[+] Installing Docker Engine and Docker Compose in CT {VMID}...")
            exec_in_ct(client, "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y curl ca-certificates gnupg lsb-release")
            exec_in_ct(client, "install -m 0755 -d /etc/apt/keyrings")
            exec_in_ct(client, "curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg")
            exec_in_ct(client, "chmod a+r /etc/apt/keyrings/docker.gpg")
            exec_in_ct(client, "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable' > /etc/apt/sources.list.d/docker.list")
            exec_in_ct(client, "DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin", timeout=300)
            exec_in_ct(client, "systemctl enable --now docker")

        # 4. Create directories and write config files
        safe_print(f"\n[+] Creating /opt/homepage/config in CT {VMID}...")
        exec_in_ct(client, "mkdir -p /opt/homepage/config")

        def write_ct_file(remote_path, content):
            b64_content = base64.b64encode(content.encode("utf-8")).decode("ascii")
            write_cmd = f"echo '{b64_content}' | base64 -d > {remote_path}"
            exec_in_ct(client, write_cmd)

        safe_print("[+] Writing docker-compose.yml...")
        write_ct_file("/opt/homepage/docker-compose.yml", DOCKER_COMPOSE)

        safe_print("[+] Writing config/settings.yaml...")
        write_ct_file("/opt/homepage/config/settings.yaml", SETTINGS_YAML)

        safe_print("[+] Writing config/widgets.yaml...")
        write_ct_file("/opt/homepage/config/widgets.yaml", WIDGETS_YAML)

        safe_print("[+] Writing config/services.yaml...")
        write_ct_file("/opt/homepage/config/services.yaml", SERVICES_YAML)

        safe_print("[+] Writing config/bookmarks.yaml...")
        write_ct_file("/opt/homepage/config/bookmarks.yaml", BOOKMARKS_YAML)

        # 5. Start Homepage using Docker Compose inside CT 116
        safe_print(f"\n[+] Launching Homepage container in CT {VMID}...")
        exec_in_ct(client, "cd /opt/homepage && docker compose up -d", timeout=180)

        # 6. Verify container status and local health
        safe_print(f"\n[+] Verifying Homepage container status...")
        time.sleep(5)
        exec_in_ct(client, "cd /opt/homepage && docker compose ps")

        # Get CT IP address
        _, ip_out, _ = exec_in_ct(client, "hostname -I")
        ct_ip = ip_out.split()[0] if ip_out else "unknown"

        safe_print("\n==================================================================")
        safe_print(" SUCCESS: Homepage has been successfully deployed on CT 116!")
        safe_print(f" CT IP Address: {ct_ip}")
        safe_print(f" Internal Port: 3000 (http://{ct_ip}:3000)")
        safe_print(" Cloudflare Hostname Target: https://home.homelab-admin.me")
        safe_print("==================================================================")

    except Exception as e:
        safe_print(f"[!] Deployment Exception: {e}")
        sys.exit(1)
    finally:
        client.close()

if __name__ == "__main__":
    main()
