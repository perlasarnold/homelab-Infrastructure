import subprocess
import base64

CEBU = "192.168.1.26"

cebu_script = """import subprocess
import json
import base64
import time

def run_cmd(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise Exception(f"Command {' '.join(cmd)} failed: stdout={res.stdout}, stderr={res.stderr}")
    return res.stdout

def run_guest_cmd(args):
    cmd = ["qm", "guest", "exec", "120", "--"] + args
    out_str = run_cmd(cmd)
    try:
        data = json.loads(out_str)
    except Exception as e:
        raise Exception(f"Failed to parse JSON output: {out_str}. Error: {e}")
    if data.get("exitcode", 0) != 0:
        raise Exception(f"Guest command {' '.join(args)} failed: {data}")
    return data.get("out-data", "")

print("1. Creating ZFS snapshot of DAS1-18TB/data...")
run_guest_cmd(["zfs", "snapshot", "DAS1-18TB/data@migrate"])

print("2. Launching ZFS replication to DAS2-18TB/data...")
# Run via transient systemd-run unit
run_guest_cmd(["systemd-run", "--unit=zfs-migrate-data", "sh", "-c", "zfs send -Rv DAS1-18TB/data@migrate | zfs recv -Fuv DAS2-18TB/data"])

# Wait for completion
print("Waiting for ZFS replication to complete...")
completed = False
for i in range(60):
    status_out = run_guest_cmd(["systemctl", "status", "zfs-migrate-data"])
    if "Active: inactive" in status_out or "status=0/SUCCESS" in status_out:
        print("Replication completed successfully.")
        completed = True
        break
    elif "status=1/FAILURE" in status_out:
        raise Exception(f"Replication unit failed: {status_out}")
    time.sleep(2)

if not completed:
    raise Exception("Timeout waiting for replication to complete.")

# Clean up systemd transient unit
run_guest_cmd(["systemctl", "reset-failed", "zfs-migrate-data"])

print("3. Verifying destination dataset mount...")
zfs_list_out = run_guest_cmd(["zfs", "list", "DAS2-18TB/data"])
print(zfs_list_out)

print("4. Re-writing scripts on DAS2 with updated paths...")
# Write sync-photo.sh
photo_sh = \"\"\"#!/bin/bash
LOCKFILE=/tmp/sync-photo.lock
if [ -e ${LOCKFILE} ] && kill -0 $(cat ${LOCKFILE}); then
    echo "Already running"
    exit
fi
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}
rclone --config /mnt/DAS2-18TB/data/rclone.conf sync photo-source:photo /mnt/DAS2-18TB/photo/ --log-file /mnt/DAS2-18TB/data/scripts/sync-photo.log --log-level INFO
\"\"\"
encoded_photo = base64.b64encode(photo_sh.encode('utf-8')).decode('utf-8')
run_guest_cmd(["sh", "-c", f"echo {encoded_photo} | base64 -d > /mnt/DAS2-18TB/data/scripts/sync-photo.sh"])
run_guest_cmd(["chmod", "+x", "/mnt/DAS2-18TB/data/scripts/sync-photo.sh"])

# Write sync-seagate.sh
seagate_sh = \"\"\"#!/bin/bash
rclone --config /mnt/DAS2-18TB/data/rclone.conf sync seagate-source:Seagate /mnt/DAS1-18TB/Seagate/ --log-file /mnt/DAS2-18TB/data/scripts/sync.log --log-level INFO
\"\"\"
encoded_seagate = base64.b64encode(seagate_sh.encode('utf-8')).decode('utf-8')
run_guest_cmd(["sh", "-c", f"echo {encoded_seagate} | base64 -d > /mnt/DAS2-18TB/data/scripts/sync-seagate.sh"])
run_guest_cmd(["chmod", "+x", "/mnt/DAS2-18TB/data/scripts/sync-seagate.sh"])

print("5. Updating TrueNAS Cron Jobs...")
cron_out = run_guest_cmd(["midclt", "call", "cronjob.query"])
cron_jobs = json.loads(cron_out)

for job in cron_jobs:
    job_id = job["id"]
    command = job["command"]
    if "sync-seagate.sh" in command:
        print(f"Updating Seagate cron job {job_id} to new path...")
        run_guest_cmd(["midclt", "call", "cronjob.update", str(job_id), '{"command": "/mnt/DAS2-18TB/data/scripts/sync-seagate.sh"}'])
    elif "sync-photo.sh" in command:
        print(f"Updating Photo cron job {job_id} to new path...")
        run_guest_cmd(["midclt", "call", "cronjob.update", str(job_id), '{"command": "/mnt/DAS2-18TB/data/scripts/sync-photo.sh"}'])

print("6. Destroying old ZFS dataset DAS1-18TB/data...")
run_guest_cmd(["zfs", "destroy", "-r", "DAS1-18TB/data"])

print("SUCCESS: Data dataset migration and configuration updates completed successfully!")
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    return res

run_ssh(CEBU, ["cat > /tmp/migrate-data.py"], input_data=cebu_script)
run_ssh(CEBU, ["python3 /tmp/migrate-data.py"])
