import subprocess
import base64

CEBU = "192.168.1.26"

# sync-photo.sh: rclone.conf and log now on DAS2, destination remains DAS2/photo
photo_sh = """#!/bin/bash
LOCKFILE=/tmp/sync-photo.lock
if [ -e ${LOCKFILE} ] && kill -0 $(cat ${LOCKFILE}); then
    echo "Already running"
    exit
fi
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}
rclone --config /mnt/DAS2-18TB/data/rclone.conf sync photo-source:photo /mnt/DAS2-18TB/photo/ --log-file /mnt/DAS2-18TB/data/scripts/sync-photo.log --log-level INFO
"""

# sync-seagate.sh: rclone.conf and log now on DAS2; Seagate data stays on DAS1
seagate_sh = """#!/bin/bash
rclone --config /mnt/DAS2-18TB/data/rclone.conf sync seagate-source:Seagate /mnt/DAS1-18TB/Seagate/ --log-file /mnt/DAS2-18TB/data/scripts/sync.log --log-level INFO
"""

enc_photo   = base64.b64encode(photo_sh.encode()).decode()
enc_seagate = base64.b64encode(seagate_sh.encode()).decode()

cebu_script = f"""import subprocess

def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("CMD:", ' '.join(cmd))
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)
    return res

# Write sync-photo.sh
run(["qm", "guest", "exec", "120", "--", "sh", "-c",
     "echo {enc_photo} | base64 -d > /mnt/DAS2-18TB/data/scripts/sync-photo.sh"])
run(["qm", "guest", "exec", "120", "--", "chmod", "+x",
     "/mnt/DAS2-18TB/data/scripts/sync-photo.sh"])

# Write sync-seagate.sh
run(["qm", "guest", "exec", "120", "--", "sh", "-c",
     "echo {enc_seagate} | base64 -d > /mnt/DAS2-18TB/data/scripts/sync-seagate.sh"])
run(["qm", "guest", "exec", "120", "--", "chmod", "+x",
     "/mnt/DAS2-18TB/data/scripts/sync-seagate.sh"])

# Verify
run(["qm", "guest", "exec", "120", "--", "cat",
     "/mnt/DAS2-18TB/data/scripts/sync-photo.sh"])
run(["qm", "guest", "exec", "120", "--", "cat",
     "/mnt/DAS2-18TB/data/scripts/sync-seagate.sh"])

print("Done!")
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    return res

run_ssh(CEBU, ["cat > /tmp/rewrite-scripts.py"], input_data=cebu_script)
run_ssh(CEBU, ["python3 /tmp/rewrite-scripts.py"])
