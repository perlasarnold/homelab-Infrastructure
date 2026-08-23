import paramiko
import time
import base64

CEBU_IP = "192.168.1.26"
PASSWORD = "***REMOVED***"
NPM_CT_ID = "105"

NPM_AUTHENTIK_CONF = """# ------------------------------------------------------------
# home.homelab-admin.me (Protected by Authentik SSO)
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

  # Authentik Outpost Location
  location /outpost.goauthentik.io {
    proxy_pass http://192.168.110.225:9000/outpost.goauthentik.io;
    proxy_set_header Host $host;
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
  }

  location @authentik_auth_signin {
    internal;
    return 302 /outpost.goauthentik.io/start?rd=$request_uri;
  }

  location / {
    auth_request /outpost.goauthentik.io/auth/nginx;
    error_page 401 = @authentik_auth_signin;

    auth_request_set $auth_header_user $upstream_http_x_authentik_username;
    auth_request_set $auth_header_email $upstream_http_x_authentik_email;
    proxy_set_header X-Authentik-Username $auth_header_user;
    proxy_set_header X-Authentik-Email $auth_header_email;

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
    print(" Enabling Authentik Forward Auth in NPM for home.homelab-admin.me")
    print("==================================================================")

    b64_npm = base64.b64encode(NPM_AUTHENTIK_CONF.encode("utf-8")).decode("ascii")
    run_ssh(CEBU_IP, f"pct exec {NPM_CT_ID} -- bash -c 'echo \"{b64_npm}\" | base64 -d > /data/nginx/proxy_host/9.conf'")
    run_ssh(CEBU_IP, f"pct exec {NPM_CT_ID} -- nginx -s reload")

    time.sleep(3)
    print("\n==================================================================")
    print(" SUCCESS: Authentik SSO Forward Auth Enabled!")
    print("==================================================================")

if __name__ == "__main__":
    main()
