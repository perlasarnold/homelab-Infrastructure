import subprocess
import json

CEBU = "192.168.1.26"

cebu_script = """import subprocess
import json
import time

def run(cmd):
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("CMD:", ' '.join(cmd))
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)
    return res

# Use TrueNAS middleware to delete the dataset (handles unmount gracefully)
print("Deleting DAS1-18TB/data via TrueNAS API...")
res = run(["qm", "guest", "exec", "120", "--", "midclt", "call", "pool.dataset.delete",
           "DAS1-18TB/data", '{"recursive": false, "force": true}'])

try:
    data = json.loads(res.stdout)
    job_id = data.get("out-data", "").strip()
    print(f"Job ID: {job_id}")
except Exception as e:
    print(f"Parse error: {e}")

# Verify it's gone
time.sleep(3)
print("\\nVerifying DAS1 datasets...")
res = run(["qm", "guest", "exec", "120", "--", "zfs", "list", "-o", "name,used,avail"])
try:
    data = json.loads(res.stdout)
    print(data.get("out-data", res.stdout))
except:
    print(res.stdout)
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    return res

run_ssh(CEBU, ["cat > /tmp/delete-data-dataset.py"], input_data=cebu_script)
run_ssh(CEBU, ["python3 /tmp/delete-data-dataset.py"])
