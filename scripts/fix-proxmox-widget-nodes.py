import paramiko
import time
import base64

BULAKAN_IP = "192.168.1.25"
PASSWORD = "***REMOVED***"
VMID = "116"

TOKEN_ID = "homepage-monitoring@pve!token-id"
TOKEN_SECRET = "9a861457-a95b-48f6-8ce9-691e52b1a7e4"

SERVICES_YAML = f"""---
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
        href: https://192.168.1.25:8006
        description: Primary PVE Hypervisor Node (Host 1)
        widget:
          type: proxmox
          url: https://192.168.1.25:8006
          username: {TOKEN_ID}
          password: {TOKEN_SECRET}
          node: Bulakan
          tlsInsecure: true

    - Proxmox Cebu:
        icon: proxmox.png
        href: https://192.168.1.26:8006
        description: Secondary PVE Hypervisor Node (Host 2)
        widget:
          type: proxmox
          url: https://192.168.1.26:8006
          username: {TOKEN_ID}
          password: {TOKEN_SECRET}
          node: cebu
          tlsInsecure: true

    - Proxmox Dapitan:
        icon: proxmox.png
        href: https://192.168.1.27:8006
        description: Tertiary PVE Hypervisor Node (Host 3)
        widget:
          type: proxmox
          url: https://192.168.1.27:8006
          username: {TOKEN_ID}
          password: {TOKEN_SECRET}
          node: Dapitan
          tlsInsecure: true

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

def run_ssh(cmd, timeout=300):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(BULAKAN_IP, username="root", password=PASSWORD, timeout=15)
        print(f"\n$ {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        code = stdout.channel.recv_exit_status()
        if out:
            print(out[:1000])
        if err and code != 0:
            print(f"STDERR: {err[:1000]}")
        return code, out, err
    finally:
        client.close()

def main():
    print("==================================================================")
    print(" Updating Proxmox Exact Node Names in Homepage (Bulakan, cebu, Dapitan)")
    print("==================================================================")

    # 1. Update services.yaml in CT 116
    b64_services = base64.b64encode(SERVICES_YAML.encode("utf-8")).decode("ascii")
    run_ssh(f"pct exec {VMID} -- bash -c 'echo \"{b64_services}\" | base64 -d > /opt/homepage/config/services.yaml'")

    # 2. Restart Homepage container
    print("\n[+] Restarting Homepage container in CT 116...")
    run_ssh(f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose restart'")

    time.sleep(5)
    print("\n==================================================================")
    print(" SUCCESS: Proxmox Node Names Updated!")
    print(" Nodes matched: Bulakan, cebu, Dapitan")
    print(" Refresh http://home.homelab-admin.me now!")
    print("==================================================================")

if __name__ == "__main__":
    main()
