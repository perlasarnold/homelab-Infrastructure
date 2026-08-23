import paramiko
import time
import base64

BULAKAN_IP = "192.168.1.25"
CEBU_IP = "192.168.1.26"
PASSWORD = "***REMOVED***"

NPM_CT_ID = "105"        # On Cebu
PIHOLE_BULAKAN_CT = "301" # On Bulakan
PIHOLE_CEBU_CT = "401"    # On Cebu

NPM_IP = "192.168.120.211"
HOMEPAGE_IP = "192.168.1.250"
DOMAIN = "home.homelab-admin.me"

NPM_CONF = """# ------------------------------------------------------------
# home.homelab-admin.me
# ------------------------------------------------------------

server {
  set $forward_scheme http;
  set $server         "192.168.1.250";
  set $port           3000;

  listen 80;
  listen [::]:80;

  server_name home.homelab-admin.me;
  http2 off;

  # Block Exploits
  include /etc/nginx/conf.d/include/block-exploits.conf;

  access_log /data/logs/proxy-host-9_access.log proxy;
  error_log /data/logs/proxy-host-9_error.log warn;

  location / {
    # Proxy!
    include /etc/nginx/conf.d/include/proxy.conf;
  }

  # Custom
  include /data/nginx/custom/server_proxy[.]conf;
}
"""

def run_ssh(host, cmd, timeout=300):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username="root", password=PASSWORD, timeout=15)
        print(f"\n[{host}] $ {cmd}")
        stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace").strip()
        err = stderr.read().decode("utf-8", errors="replace").strip()
        code = stdout.channel.recv_exit_status()
        if out:
            print(out[:2000])
        if err and code != 0:
            print(f"STDERR: {err[:2000]}")
        return code, out, err
    finally:
        client.close()

def main():
    print("==================================================================")
    print(" Adding home.homelab-admin.me to Nginx Proxy Manager & Pi-hole DNS")
    print("==================================================================")

    # 1. Write Nginx proxy host config into CT 105 on Cebu
    print("\n[+] Creating Nginx proxy host configuration for home.homelab-admin.me...")
    b64_conf = base64.b64encode(NPM_CONF.encode("utf-8")).decode("ascii")
    write_cmd = f"pct exec {NPM_CT_ID} -- bash -c 'echo \"{b64_conf}\" | base64 -d > /data/nginx/proxy_host/9.conf'"
    run_ssh(CEBU_IP, write_cmd)

    # 2. Register proxy host in NPM SQLite database if sqlite3 exists
    print("\n[+] Updating NPM SQLite Database...")
    sql_cmd = (
        f"pct exec {NPM_CT_ID} -- bash -c 'sqlite3 /data/database.sqlite "
        f"\"INSERT INTO proxy_host (id, created_on, modified_on, domain_names, forward_scheme, forward_host, forward_port, access_list_id, certificate_id, ssl_forced, caching_enabled, block_exploits, advanced_config, meta, allow_websocket_upgrade, http2_support, enabled) "
        f"VALUES (9, DATETIME(\\\"now\\\"), DATETIME(\\\"now\\\"), \\\\[\\\\\"home.homelab-admin.me\\\\\"\\\\] , \\\"http\\\", \\\"192.168.1.250\\\", 3000, 0, 0, 0, 0, 1, \\\"\\\", \\\"{{}}\\\", 1, 0, 1);\"'"
    )
    run_ssh(CEBU_IP, sql_cmd)

    # 3. Reload Nginx configuration in CT 105 on Cebu
    print("\n[+] Reloading Nginx Proxy Manager daemon...")
    run_ssh(CEBU_IP, f"pct exec {NPM_CT_ID} -- nginx -s reload")

    # 4. Add Pi-hole Local DNS Record on Bulakan (CT 301)
    print(f"\n[+] Adding Pi-hole Local DNS Record on Bulakan (CT {PIHOLE_BULAKAN_CT})...")
    dns_cmd_b = f"pct exec {PIHOLE_BULAKAN_CT} -- bash -c 'grep -q \"{DOMAIN}\" /etc/pihole/custom.list || echo \"{NPM_IP} {DOMAIN}\" >> /etc/pihole/custom.list && pihole restartdns reload-lists'"
    run_ssh(BULAKAN_IP, dns_cmd_b)

    # 5. Add Pi-hole Local DNS Record on Cebu (CT 401)
    print(f"\n[+] Adding Pi-hole Local DNS Record on Cebu (CT {PIHOLE_CEBU_CT})...")
    dns_cmd_c = f"pct exec {PIHOLE_CEBU_CT} -- bash -c 'grep -q \"{DOMAIN}\" /etc/pihole/custom.list || echo \"{NPM_IP} {DOMAIN}\" >> /etc/pihole/custom.list && pihole restartdns reload-lists'"
    run_ssh(CEBU_IP, dns_cmd_c)

    print("\n==================================================================")
    print(" SUCCESS: home.homelab-admin.me configured in NPM & Pi-hole!")
    print(f" Local LAN DNS: {DOMAIN} -> {NPM_IP}")
    print(f" Nginx Proxy Target: {DOMAIN} -> http://{HOMEPAGE_IP}:3000")
    print("==================================================================")

if __name__ == "__main__":
    main()
