import subprocess

CEBU = "192.168.1.26"

cebu_script = """import subprocess
import json

def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    try:
        data = json.loads(res.stdout)
        return data.get("out-data", res.stdout)
    except:
        return res.stdout

# Update cron job 1 (sync-seagate) to DAS2 script path
print("Updating cron job 1 (sync-seagate)...")
result = run(["qm", "guest", "exec", "120", "--", "midclt", "call", "cronjob.update", "1",
              '{"command": "/mnt/DAS2-18TB/data/scripts/sync-seagate.sh"}'])
print(result)

# Update cron job 2 (sync-photo) to DAS2 script path
print("Updating cron job 2 (sync-photo)...")
result = run(["qm", "guest", "exec", "120", "--", "midclt", "call", "cronjob.update", "2",
              '{"command": "/mnt/DAS2-18TB/data/scripts/sync-photo.sh"}'])
print(result)

# Verify both
print("\\nVerifying cron jobs...")
result = run(["qm", "guest", "exec", "120", "--", "midclt", "call", "cronjob.query"])
jobs = json.loads(result)
for job in jobs:
    print(f"  ID {job['id']}: enabled={job['enabled']} command={job['command']}")
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    return res

run_ssh(CEBU, ["cat > /tmp/update-crons.py"], input_data=cebu_script)
run_ssh(CEBU, ["python3 /tmp/update-crons.py"])
