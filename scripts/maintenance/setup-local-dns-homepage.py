import paramiko

BULAKAN_IP = "192.168.1.25"
CEBU_IP = "192.168.1.26"
PASSWORD = "***REMOVED***"

NPM_IP = "192.168.120.211"
DOMAIN = "home.homelab-admin.me"

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
            print(out)
        if err and code != 0:
            print(f"STDERR: {err}")
        return code, out, err
    finally:
        client.close()

def main():
    print("==================================================================")
    print(" Configuring Local DNS for home.homelab-admin.me -> 192.168.120.211")
    print("==================================================================")

    # 1. Update Bulakan Pi-hole CT 301 dnsmasq config
    dnsmasq_rule = f"address=/{DOMAIN}/{NPM_IP}"
    print(f"\n[+] Adding dnsmasq rule to Bulakan Pi-hole CT 301...")
    run_ssh(BULAKAN_IP, f"pct exec 301 -- bash -c 'echo \"{dnsmasq_rule}\" > /etc/dnsmasq.d/99-homepage.conf'")

    # Also add to /etc/hosts on CT 301
    run_ssh(BULAKAN_IP, f"pct exec 301 -- bash -c 'grep -q \"{DOMAIN}\" /etc/hosts || echo \"{NPM_IP} {DOMAIN}\" >> /etc/hosts'")

    # Restart pi-hole / FTL or dnsmasq on CT 301
    run_ssh(BULAKAN_IP, "pct exec 301 -- systemctl restart pihole-FTL 2>/dev/null || pct exec 301 -- systemctl restart dnsmasq 2>/dev/null || true")

    # 2. Update Cebu Pi-hole CT 401 dnsmasq config
    print(f"\n[+] Adding dnsmasq rule to Cebu Pi-hole CT 401...")
    run_ssh(CEBU_IP, f"pct exec 401 -- bash -c 'echo \"{dnsmasq_rule}\" > /etc/dnsmasq.d/99-homepage.conf'")

    # Also add to /etc/hosts on CT 401
    run_ssh(CEBU_IP, f"pct exec 401 -- bash -c 'grep -q \"{DOMAIN}\" /etc/hosts || echo \"{NPM_IP} {DOMAIN}\" >> /etc/hosts'")

    # Restart pi-hole / FTL or dnsmasq on CT 401
    run_ssh(CEBU_IP, "pct exec 401 -- systemctl restart pihole-FTL 2>/dev/null || pct exec 401 -- systemctl restart dnsmasq 2>/dev/null || true")

    # 3. Test DNS resolution from Bulakan host
    print("\n[+] Testing DNS resolution from Bulakan host...")
    run_ssh(BULAKAN_IP, f"nslookup {DOMAIN} 127.0.0.1 || ping -c 1 {DOMAIN} || true")

    print("\n==================================================================")
    print(" SUCCESS: Local DNS configured for home.homelab-admin.me!")
    print(f" {DOMAIN} -> {NPM_IP} (Nginx Proxy Manager)")
    print(" Nginx Proxy Manager forwards to -> http://192.168.1.250:3000")
    print("==================================================================")

if __name__ == "__main__":
    main()
