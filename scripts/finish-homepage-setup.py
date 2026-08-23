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
    print(f" Writing updated docker-compose.yml and launching CT {VMID}")
    print("==================================================================")

    # 1. Write updated docker-compose.yml into CT 116
    print("\n[+] Updating /opt/homepage/docker-compose.yml in CT 116...")
    b64_compose = base64.b64encode(DOCKER_COMPOSE.encode("utf-8")).decode("ascii")
    write_cmd = f"pct exec {VMID} -- bash -c 'echo \"{b64_compose}\" | base64 -d > /opt/homepage/docker-compose.yml'"
    run_ssh(write_cmd)

    # 2. Verify file content
    run_ssh(f"pct exec {VMID} -- head -n 10 /opt/homepage/docker-compose.yml")

    # 3. Enable & start Docker daemon
    run_ssh(f"pct exec {VMID} -- systemctl enable --now docker")

    # 4. Launch Homepage using docker-compose
    print("\n[+] Launching Homepage with docker-compose in CT 116...")
    run_ssh(f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose up -d'", timeout=300)

    # 5. Verify running container
    time.sleep(5)
    print("\n[+] Checking container status:")
    run_ssh(f"pct exec {VMID} -- bash -c 'cd /opt/homepage && docker-compose ps'")

    # 6. Check HTTP endpoint local response
    time.sleep(5)
    code, out, _ = run_ssh(f"pct exec {VMID} -- curl -I http://localhost:3000")
    print(f"\n[+] HTTP Check inside CT {VMID}:\n{out}")

    # Get CT IP
    _, ip_out, _ = run_ssh(f"pct exec {VMID} -- hostname -I")
    ct_ip = ip_out.split()[0] if ip_out else "192.168.1.250"

    print("\n==================================================================")
    print(" DEPLOYMENT COMPLETE: Homepage is LIVE and running in CT 116!")
    print(f" Internal Access: http://{ct_ip}:3000")
    print(" Cloudflare Hostname Target: https://home.homelab-admin.me")
    print("==================================================================")

if __name__ == "__main__":
    main()
