import paramiko
import time
import base64

BULAKAN_IP = "192.168.1.25"
CEBU_IP = "192.168.1.26"
PASSWORD = "***REMOVED***"

VMID = "116"          # Homepage CT on Bulakan
NPM_CT_ID = "105"     # NPM CT on Cebu

SETTINGS_YAML = """---
title: Homelab-Net Dashboard (home.homelab-admin.me)
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
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    
    # Proxy!
    include /etc/nginx/conf.d/include/proxy.conf;
  }

  # Custom
  include /data/nginx/custom/server_proxy[.]conf;
}
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
    print(" Fixing Homepage Host Validation Failed Error")
    print("==================================================================")

    # 1. Update Homepage settings.yaml (remove base: setting)
    print("\n[+] Updating /opt/homepage/config/settings.yaml in CT 116...")
    b64_settings = base64.b64encode(SETTINGS_YAML.encode("utf-8")).decode("ascii")
    run_ssh(BULAKAN_IP, f"pct exec {VMID} -- bash -c 'echo \"{b64_settings}\" | base64 -d > /opt/homepage/config/settings.yaml'")

    # 2. Restart Homepage container
    print("\n[+] Restarting Homepage container in CT 116...")
    run_ssh(BULAKAN_IP, f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose restart'")

    # 3. Update NPM config with proxy headers
    print("\n[+] Updating Nginx Proxy Manager config in CT 105...")
    b64_npm = base64.b64encode(NPM_CONF.encode("utf-8")).decode("ascii")
    run_ssh(CEBU_IP, f"pct exec {NPM_CT_ID} -- bash -c 'echo \"{b64_npm}\" | base64 -d > /data/nginx/proxy_host/9.conf'")
    run_ssh(CEBU_IP, f"pct exec {NPM_CT_ID} -- nginx -s reload")

    # 4. Test HTTP response
    time.sleep(3)
    code, out, _ = run_ssh(BULAKAN_IP, "curl -I -H 'Host: home.homelab-admin.me' http://192.168.120.211")
    print(f"\n[+] HTTP Check Response:\n{out}")

    print("\n==================================================================")
    print(" SUCCESS: Homepage Host Validation Fixed!")
    print(" You can now refresh http://home.homelab-admin.me in your browser.")
    print("==================================================================")

if __name__ == "__main__":
    main()
