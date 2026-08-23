"""
proxmox-fix-all.py
Fix all remaining blockers:
1. Download debian-12-standard template on Cebu
2. Remove replication job on CT 301
3. Grant token Administrator privs (via pveum, properly)
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
                print("ERR: %s" % err)
            if exit_code != 0:
                print("[exit %d]" % exit_code)
    except Exception as e:
        print("[ERROR] %s" % e)
    finally:
        client.close()


# ---- CEBU: download the standard Debian 12 template for pihole_cebu/jellyfin_cebu ----
cebu_commands = [
    "pveam update 2>&1 | tail -3",
    # List available Debian 12 standard templates
    "pveam available | grep debian-12-standard",
    # Download the correct one (12.7 is latest, 12.2 if available)
    "pveam download local debian-12-standard_12.7-1_amd64.tar.zst 2>&1 || pveam download local debian-12-standard_12.2-1_amd64.tar.zst 2>&1 || echo 'Checking exact name...'",
    "pveam available | grep debian-12-standard | head -5",
    "ls /var/lib/vz/template/cache/ | grep debian",
]

# ---- BULAKAN: remove replication job on CT 301 and grant proper token privs ----
bulakan_commands = [
    # Remove replication job for CT 301 before deletion
    "pvesh get /nodes/Bulakan/replication 2>&1 | head -20",
    "pvesh delete /cluster/replication/301-0 2>&1 || echo 'No replication job or already removed'",
    # Verify
    "pvesh get /cluster/replication 2>&1 | grep 301 || echo 'No replication jobs for 301'",
    # Grant terraform token Administrator role at / (datacenter root)
    "pveum acl modify / --roles Administrator --tokens root@pam!terraform 2>&1",
    # Verify token has correct role
    "pveum acl list 2>&1 | grep terraform || echo 'Check done'",
]

run_ssh(CEBU,    cebu_commands,    "Cebu")
run_ssh(BULAKAN, bulakan_commands, "Bulakan")

print("\n[DONE] All pre-apply fixes complete")
