import subprocess
import json

CEBU = "192.168.1.26"

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    return res

script = """#!/bin/bash
echo "--- Folder Sizes ---"
du -sh /mnt/DAS2-18TB/photo/*
echo ""
echo "--- ZFS Snapshots ---"
zfs list -t snapshot -o name,used,refer
"""

# write to Cebu then execute via qm guest exec
run_ssh(CEBU, ["cat > /tmp/check-truenas.sh"], input_data=script)

# We use qm guest exec to push the script to TrueNAS (vmid 120) and run it
# Actually, pushing to TrueNAS from Cebu is a bit tricky with qm guest exec.
# Instead, we can just run the commands directly via qm guest exec.

cmd_folders = 'du -sh /mnt/DAS2-18TB/photo/Edits /mnt/DAS2-18TB/photo/Immich /mnt/DAS2-18TB/photo/Lightroom /mnt/DAS2-18TB/photo/Memories /mnt/DAS2-18TB/photo/MobileBackup /mnt/DAS2-18TB/photo/Photography /mnt/DAS2-18TB/photo/PhotoLibrary'
res1 = run_ssh(CEBU, ["qm", "guest", "exec", "120", "--", "sh", "-c", cmd_folders])
print("Folder Sizes Output:")
print(res1.stdout)

res2 = run_ssh(CEBU, ["qm", "guest", "exec", "120", "--", "zfs", "list", "-t", "snapshot", "-o", "name,used,refer"])
print("Snapshots Output:")
try:
    data = json.loads(res2.stdout)
    print(data.get("out-data", ""))
except:
    print(res2.stdout)

