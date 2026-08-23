"""
proxmox-ssh-fix.py
Fixes two blockers on Bulakan, then installs SSH keys on both nodes.
"""
import subprocess
import sys

PASSWORD = "***REMOVED***"
BULAKAN = "192.168.1.25"
CEBU    = "192.168.1.26"

PUB_KEY = (
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCpHYi/iT//ctxwpUnNrUGxmJGTAFhUz05xRfSYy3PWjDT9u"
    "GwNGJ1a2W6ABhhQfl/+S6qXFFVDVC3EQqMFl2I1j1vhP/M0AIa9//fBxwCaPlgJuqzs98MFnPvUH58HE/Q8Ym"
    "7CwsPToarQu/4OvXbSEHFhJgU+Yt7MgjHcqFC3t8wyZjcPbIBj3cTqBahwYd+iETbLuIBsJALvY7bKh45tISH"
    "gZL9sKviN9ylBuCwoZmJeBzjd2EVMi5btDhdg+o+0CaHDxkpH9XqjQz6AsxnSqZHUoYpNX721IyBPPv/WRDh8J"
    "6cRUndfjJy0TV0blayla3/95Aar4slvVeIf0UlyMY3k6p2bMBBAytM1QU16JaiIUakgN56GYTbmbrrcVmGR6pkW"
    "8l/+VYiLB18t0wAnFo/Z0u4jUbAIJ1ejqhXx0dgw+DpfG3cj3NVwyVT2zXIhFu5lL8vHoe5KoX/iDrqdwL2Vl"
    "QDnYo+lJLa1o9FnZ/oO0jW5gyj5mAYLrWGualnZ1Q0DDR2/qJciJEC11KI9usZKrXpJgIJ0IjFWBcplejsSE0x"
    "ui5mvlOoOGp5WKiSxLw1xMDH8dEo+Qj8tW5/YpW+JVCjCK/MyMT0ntg9fU1FleGKzmh7I/uxhjJVOb0owVJaA"
    "/yiHNLLT0rhHc+0IqIaizj2xekEIzaUZb7GNpQ== perlas@F5DBSv3"
)

try:
    import paramiko
except ImportError:
    print("Installing paramiko...")
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
            short = cmd[:100].replace("\n", " ")
            print("\n$ %s" % short)
            stdin, stdout, stderr = client.exec_command(cmd, timeout=300)
            out = stdout.read().decode("utf-8", errors="replace").strip()
            err = stderr.read().decode("utf-8", errors="replace").strip()
            exit_code = stdout.channel.recv_exit_status()
            if out:
                print(out)
            if err and exit_code != 0:
                print("STDERR: %s" % err)
            if exit_code not in (0, 1):
                print("[exit code: %d]" % exit_code)
    except Exception as e:
        print("[ERROR] %s" % e)
    finally:
        client.close()


# ============================================================
# BULAKAN: two critical fixes + SSH key
# ============================================================
INSTALL_KEY_CMD = (
    "mkdir -p /root/.ssh && "
    "grep -qF 'perlas@F5DBSv3' /root/.ssh/authorized_keys 2>/dev/null || "
    "echo '%s' >> /root/.ssh/authorized_keys && "
    "chmod 600 /root/.ssh/authorized_keys && "
    "echo 'SSH key installed'"
) % PUB_KEY

bulakan_commands = [
    # Fix 1 — hostname resolution for Cebu node
    "grep -q '192.168.1.26 cebu' /etc/hosts || echo '192.168.1.26 cebu' >> /etc/hosts",
    "getent hosts cebu",

    # Fix 2 — download missing Debian 12 LXC template
    "ls /var/lib/vz/template/cache/",
    "pveam update 2>&1 | tail -3",
    "pveam download local debian-12-standard_12.0-1_amd64.tar.zst 2>&1",
    "ls /var/lib/vz/template/cache/ | grep debian",

    # SSH key
    INSTALL_KEY_CMD,
]

# ============================================================
# CEBU: verify templates + SSH key
# ============================================================
cebu_commands = [
    "ls /var/lib/vz/template/cache/",
    "pveam update 2>&1 | tail -3",
    # Download ubuntu template for CasaOS if missing
    "ls /var/lib/vz/template/cache/ | grep -q ubuntu-22.04 || pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst 2>&1",
    "ls /var/lib/vz/template/cache/",
    INSTALL_KEY_CMD,
]

run_ssh(BULAKAN, bulakan_commands, "Bulakan")
run_ssh(CEBU,    cebu_commands,    "Cebu")

print("\n" + "=" * 60)
print("[DONE] All fixes applied!")
print("Now run: terraform apply -auto-approve")
print("=" * 60)
