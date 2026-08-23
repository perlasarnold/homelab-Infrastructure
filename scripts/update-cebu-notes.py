import subprocess

CEBU = "192.168.1.26"

notes = """# 🖼️ Cebu Immich LXC (112)

**Role:** High-Performance Photo Vault (Standby / Migration Target)
**Access URL:** http://192.168.1.189:2283

## ⚙️ Specs & Acceleration
* **OS:** Debian 13 (Unprivileged)
* **Resources:** 4 Cores, 4GB RAM
* **GPU:** Intel iGPU Passthrough (ffmpeg & ML active)
* **DB Engine:** PostgreSQL 16 + VectorChord

## 📁 TrueNAS SMB Mounts (via Host /mnt/truenas-photo)
* **mp0:** `/mnt/truenas-photo/Immich` ➔ `/opt/immich/upload` *(Main Uploads)*
* **mp1:** `/mnt/truenas-photo` ➔ `/mnt/truenas-photo` *(External Libs: Photography & Edits)*
"""

# Write raw notes to a file on Cebu via SSH input
subprocess.run(["ssh", f"root@{CEBU}", "cat > /tmp/immich-notes.md"], input=notes, text=True, encoding="utf-8")

# Read that file directly into the description
cmd = ["ssh", f"root@{CEBU}", "pct set 112 -description \"$(cat /tmp/immich-notes.md)\""]
res = subprocess.run(cmd, capture_output=True, text=True)

if res.stdout:
    print(res.stdout)
if res.stderr:
    print("STDERR:", res.stderr)
