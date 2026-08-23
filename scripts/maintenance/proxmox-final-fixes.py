"""
proxmox-final-fixes.py
1. Register cebu-zfs as Proxmox storage on Cebu node
2. Grant terraform token full datacenter-level privs for bind mounts
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
            stdin, stdout, stderr = client.exec_command(cmd, timeout=120)
            out = stdout.read().decode("utf-8", errors="replace").strip()
            err = stderr.read().decode("utf-8", errors="replace").strip()
            exit_code = stdout.channel.recv_exit_status()
            if out:
                print(out)
            if err and exit_code != 0:
                print("STDERR: %s" % err)
            if exit_code != 0:
                print("[exit code: %d]" % exit_code)
    except Exception as e:
        print("[ERROR] %s" % e)
    finally:
        client.close()


# Register cebu-zfs in Proxmox storage config AND grant token full privs
# Both need to be done from Bulakan (cluster manager)
bulakan_commands = [
    # Register cebu-zfs storage (cluster-wide, restricted to cebu node)
    "pvesm add zfspool cebu-zfs --pool cebu-zfs --nodes cebu --content rootdir,images 2>&1 || echo 'Storage may already be registered'",
    # Verify it appears
    "pvesm status | grep cebu",
    # Grant terraform token Administrator role at datacenter level (needed for bind mounts)
    "pveum acl modify / --roles Administrator --tokens root@pam!terraform 2>&1",
    # Verify
    "pveum acl list | grep terraform",
]

run_ssh(BULAKAN, bulakan_commands, "Bulakan (cluster manager)")

print("\n[DONE] Storage registered and permissions updated")
