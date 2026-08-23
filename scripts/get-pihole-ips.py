import subprocess, sys

CEBU_IP = "192.168.1.26"
BULAKAN_IP = "192.168.1.25"
PROXMOX_PASS = "***REMOVED***"

try:
    import paramiko
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko", "-q"])
    import paramiko

def get_ip(host, vmid, name):
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username="root", password=PROXMOX_PASS, timeout=10)
        cmd = f"pct exec {vmid} -- ip -4 addr show eth0 | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){{3}}'"
        stdin, stdout, stderr = client.exec_command(cmd, timeout=30)
        out = stdout.read().decode().strip()
        if out:
            print(f"{name} ({vmid}) on {host}: {out}")
        else:
            print(f"{name} ({vmid}) on {host}: Could not determine IP. (Container might be booting or down)")
    except Exception as e:
        print(f"Error connecting to {host}: {e}")
    finally:
        client.close()

get_ip(BULAKAN_IP, 301, "pihole")
get_ip(CEBU_IP, 401, "pihole-cebu")
