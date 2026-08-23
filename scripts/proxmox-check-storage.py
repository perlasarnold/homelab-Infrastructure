"""
proxmox-check-storage.py
Check actual storage names on Cebu and check pihole protection status.
"""
import subprocess, sys

PASSWORD = "***REMOVED***"
BULAKAN  = "192.168.1.25"
CEBU     = "192.168.1.26"

try:
    import paramiko
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko", "-q"])
    import paramiko


def run_ssh(host, commands, label):
    print("\n" + "=" * 60)
    print("Connecting to %s (%s)..." % (label, host))
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username="root", password=PASSWORD, timeout=15)
        print("[OK] Connected to %s" % label)
        for cmd in commands:
            short = cmd[:120]
            print("\n$ %s" % short)
            stdin, stdout, stderr = client.exec_command(cmd, timeout=60)
            out = stdout.read().decode("utf-8", errors="replace").strip()
            err = stderr.read().decode("utf-8", errors="replace").strip()
            exit_code = stdout.channel.recv_exit_status()
            if out:
                print(out)
            if err:
                print("STDERR: %s" % err)
    except Exception as e:
        print("[ERROR] %s" % e)
    finally:
        client.close()


cebu_commands = [
    # List actual ZFS datasets/pools
    "pvesm list cebu-zfs 2>&1 || echo 'cebu-zfs not found as pvesm'",
    "pvesm status",
    "zpool list",
    # Fix: ensure terraform API token is privileged (root@pam is fine for bind mounts)
    "pveum user token list root@pam",
    "pveum acl list | grep terraform",
]

bulakan_commands = [
    # Check pihole 301 protection status
    "pct config 301 | grep protection",
    # Disable protection on pihole
    "pct set 301 --protection 0 && echo 'Protection disabled on CT 301'",
    # Check pihole protection status again
    "pct config 301 | grep protection",
]

run_ssh(CEBU, cebu_commands, "Cebu")
run_ssh(BULAKAN, bulakan_commands, "Bulakan")

print("\n[DONE] Diagnostics complete")
