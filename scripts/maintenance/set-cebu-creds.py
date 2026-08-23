"""
set-cebu-creds.py
Creates the user 'homelab-admin' with the requested password and sudo privileges
on all Cebu LXC containers.
"""
import subprocess, sys

CEBU_IP = "192.168.1.26"
PROXMOX_PASS = "***REMOVED***"
TARGET_USER = "homelab-admin"
TARGET_PASS = "***REMOVED***"

CONTAINERS = {
    401: "pihole-cebu",
    402: "fileserver",
    403: "casaos",
    416: "jellyfin-cebu"
}

try:
    import paramiko
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko", "-q"])
    import paramiko

def run_ssh_commands(host, commands, label):
    print("\n" + "=" * 60)
    print(f"Connecting to {label} ({host})...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username="root", password=PROXMOX_PASS, timeout=15)
        print(f"[OK] Connected to {label}")
        for cmd in commands:
            print(f"\n$ {cmd[:120]}")
            stdin, stdout, stderr = client.exec_command(cmd, timeout=300)
            out = stdout.read().decode("utf-8", errors="replace").strip()
            err = stderr.read().decode("utf-8", errors="replace").strip()
            exit_code = stdout.channel.recv_exit_status()
            if out:
                print(out)
            if err and exit_code != 0:
                print(f"STDERR: {err}")
            if exit_code != 0:
                print(f"[exit code: {exit_code}]")
    except Exception as e:
        print(f"[ERROR] {e}")
    finally:
        client.close()

commands = []

for vmid, name in CONTAINERS.items():
    commands.extend([
        f"echo '--- Configuring {name} ({vmid}) ---'",
        # Check if container is running
        f"pct status {vmid} | grep -q 'status: running' || pct start {vmid}",
        # Create user
        f"pct exec {vmid} -- bash -c 'id -u {TARGET_USER} &>/dev/null || useradd -m -s /bin/bash {TARGET_USER}'",
        # Set password
        f"pct exec {vmid} -- bash -c 'echo \"{TARGET_USER}:{TARGET_PASS}\" | chpasswd'",
        # Ensure sudo is installed and add user to sudo group
        f"pct exec {vmid} -- bash -c 'apt-get update >/dev/null 2>&1 && apt-get install -y sudo >/dev/null 2>&1'",
        f"pct exec {vmid} -- bash -c 'usermod -aG sudo {TARGET_USER}'",
        f"echo 'Successfully configured {TARGET_USER} on {name}'"
    ])

run_ssh_commands(CEBU_IP, commands, "Cebu Host")
print("\n[DONE] All credentials configured!")
