import paramiko
import time

BULAKAN_IP = "192.168.1.25"
CEBU_IP = "192.168.1.26"
PASSWORD = "***REMOVED***"

PIHOLE_BULAKAN_CT = "301"
PIHOLE_CEBU_CT = "401"

NPM_IP = "192.168.120.211"

DNSMASQ_CONTENT = """# Split-Horizon DNS Overrides for homelab-admin.me Infrastructure
# All local LAN requests route directly to Nginx Proxy Manager (192.168.120.211)

address=/homelab-admin.me/192.168.120.211
server=/www.homelab-admin.me/#
server=/homelab-admin.github.io/#

address=/home.homelab-admin.me/192.168.120.211
address=/auth.homelab-admin.me/192.168.120.211
address=/immich.homelab-admin.me/192.168.120.211
address=/plex.homelab-admin.me/192.168.120.211
address=/plex-unraid.homelab-admin.me/192.168.120.211
address=/jellyfin.homelab-admin.me/192.168.120.211
address=/jellyfincb.homelab-admin.me/192.168.120.211
address=/jellyfinpx.homelab-admin.me/192.168.120.211
address=/jellyfin2.homelab-admin.me/192.168.120.211
address=/guacamole.homelab-admin.me/192.168.120.211
address=/portainer.homelab-admin.me/192.168.120.211
address=/casa.homelab-admin.me/192.168.120.211
address=/synology.homelab-admin.me/192.168.120.211
address=/synphotos.homelab-admin.me/192.168.120.211
address=/synfiles.homelab-admin.me/192.168.120.211
address=/syndrive.homelab-admin.me/192.168.120.211
address=/drive.homelab-admin.me/192.168.120.211
address=/audiobookbay.homelab-admin.me/192.168.120.211
address=/heimdall.homelab-admin.me/192.168.120.211
address=/obsidian.homelab-admin.me/192.168.120.211
"""

def run_ssh(host, cmd):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username="root", password=PASSWORD, timeout=15)
        print(f"\n[{host}] $ {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=60)
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
    print(" Deploying Split-Horizon DNS for all homelab-admin.me subdomains")
    print(" Target Local Ingress: 192.168.120.211 (Nginx Proxy Manager)")
    print("==================================================================")

    import base64
    b64_dnsmasq = base64.b64encode(DNSMASQ_CONTENT.encode("utf-8")).decode("ascii")

    # 1. Update Primary Pi-hole on Bulakan (CT 301)
    print("\n[+] Updating Primary Pi-hole (Bulakan CT 301)...")
    cmd_write_b = f"pct exec {PIHOLE_BULAKAN_CT} -- bash -c 'echo \"{b64_dnsmasq}\" | base64 -d > /etc/dnsmasq.d/99-homelab-admin-lan.conf'"
    run_ssh(BULAKAN_IP, cmd_write_b)
    run_ssh(BULAKAN_IP, f"pct exec {PIHOLE_BULAKAN_CT} -- systemctl restart pihole-FTL 2>/dev/null || pct exec {PIHOLE_BULAKAN_CT} -- systemctl restart dnsmasq 2>/dev/null || true")

    # 2. Update Secondary Pi-hole on Cebu (CT 401)
    print("\n[+] Updating Secondary Pi-hole (Cebu CT 401)...")
    cmd_write_c = f"pct exec {PIHOLE_CEBU_CT} -- bash -c 'echo \"{b64_dnsmasq}\" | base64 -d > /etc/dnsmasq.d/99-homelab-admin-lan.conf'"
    run_ssh(CEBU_IP, cmd_write_c)
    run_ssh(CEBU_IP, f"pct exec {PIHOLE_CEBU_CT} -- systemctl restart pihole-FTL 2>/dev/null || pct exec {PIHOLE_CEBU_CT} -- systemctl restart dnsmasq 2>/dev/null || true")

    print("\n==================================================================")
    print(" SUCCESS: All homelab-admin.me subdomains now route locally!")
    print(f" Local Ingress Proxy: {NPM_IP}")
    print(" WAN Traffic Bypassed for LAN clients.")
    print("==================================================================")

if __name__ == "__main__":
    main()
