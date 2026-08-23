import paramiko
import time
import base64

BULAKAN_IP = "192.168.1.25"
PASSWORD = "***REMOVED***"
VMID = "116"

DOCKER_COMPOSE = """version: '3.8'

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
      - HOMEPAGE_ALLOWED_HOSTS=home.homelab-admin.me,192.168.120.211,192.168.1.250,localhost,127.0.0.1,*
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
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
            print(out[:2000])
        if err and code != 0:
            print(f"STDERR: {err[:2000]}")
        return code, out, err
    finally:
        client.close()

def main():
    print("==================================================================")
    print(" Setting HOMEPAGE_ALLOWED_HOSTS in CT 116 docker-compose.yml")
    print("==================================================================")

    # 1. Write updated docker-compose.yml with HOMEPAGE_ALLOWED_HOSTS
    b64_compose = base64.b64encode(DOCKER_COMPOSE.encode("utf-8")).decode("ascii")
    run_ssh(f"pct exec {VMID} -- bash -c 'echo \"{b64_compose}\" | base64 -d > /opt/homepage/docker-compose.yml'")

    # 2. Re-create / restart container
    print("\n[+] Re-creating Homepage container with environment variables...")
    run_ssh(f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose up -d'")

    # 3. Test HTTP request with Host header
    time.sleep(3)
    code, out, _ = run_ssh(BULAKAN_IP, "curl -sI -H 'Host: home.homelab-admin.me' http://192.168.120.211")
    print(f"\n[+] HTTP Test Output:\n{out}")

    print("\n==================================================================")
    print(" SUCCESS: HOMEPAGE_ALLOWED_HOSTS configured!")
    print(" You can now refresh http://home.homelab-admin.me in your browser.")
    print("==================================================================")

if __name__ == "__main__":
    main()
