"""
proxmox-fix-final.py
1. Download debian-12-standard_12.12-1 on Cebu (latest)
2. Remove replication job 301-0 from Bulakan
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
            stdin, stdout, stderr = client.exec_command(cmd, timeout=300)
            out = stdout.read().decode("utf-8", errors="replace").strip()
            err = stderr.read().decode("utf-8", errors="replace").strip()
            exit_code = stdout.channel.recv_exit_status()
            if out:
                print(out)
            if err:
                print("ERR: %s" % err[:200])
            if exit_code != 0:
                print("[exit %d]" % exit_code)
    except Exception as e:
        print("[ERROR] %s" % e)
    finally:
        client.close()


cebu_commands = [
    # Download the actual latest template available
    "pveam download local debian-12-standard_12.12-1_amd64.tar.zst 2>&1",
    "ls /var/lib/vz/template/cache/ | grep debian",
]

bulakan_commands = [
    # Remove replication job for CT 301 using pvesh
    "pvesh delete /cluster/replication/301-0 2>&1",
    # Verify deletion
    "pvesh get /cluster/replication 2>&1",
    # Check token ACL - use simple bash output
    "cat /etc/pve/user.cfg | grep terraform",
]

run_ssh(CEBU,    cebu_commands,    "Cebu")
run_ssh(BULAKAN, bulakan_commands, "Bulakan")

print("\n[DONE]")
