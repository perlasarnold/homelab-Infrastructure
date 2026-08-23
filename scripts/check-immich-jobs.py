import subprocess

CEBU = "192.168.1.26"

cebu_script = r"""import json
import urllib.request
import urllib.error
import subprocess

IMMICH_URL = "http://127.0.0.1:2283"

def api(method, path, body=None, api_key=None):
    url = IMMICH_URL + path
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    if api_key:
        req.add_header("x-api-key", api_key)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"HTTP {e.code} for {method} {path}: {body}")
        return None

# Fetch existing API key from DB
db_res = subprocess.run(
    ["sudo", "-u", "postgres", "psql", "-d", "immich", "-t", "-A", "-c",
     "SELECT key FROM api_key LIMIT 1;"],
    capture_output=True, text=True
)
api_key = db_res.stdout.strip()

if not api_key:
    print("No API key found - exiting")
    exit(1)

# Get jobs
jobs = api("GET", "/api/jobs", api_key=api_key)
if not jobs:
    print("Failed to get jobs")
    exit(1)

print("Immich Job Status:")
print("-" * 60)
print(f"{'Job Type':<30} | {'Active':<8} | {'Pending':<8} | {'Delayed':<8}")
print("-" * 60)
for job_name, job_info in jobs.items():
    queue_status = job_info.get("queueStatus", {})
    active = queue_status.get("isActive", 0)
    pending = queue_status.get("isWaiting", 0)
    delayed = queue_status.get("isDelayed", 0)
    if active > 0 or pending > 0 or delayed > 0:
        print(f"{job_name:<30} | {active:<8} | {pending:<8} | {delayed:<8}")
print("-" * 60)
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)
    return res

run_ssh(CEBU, ["cat > /tmp/check-jobs.py"], input_data=cebu_script)
run_ssh(CEBU, ["sh", "-c", "pct push 112 /tmp/check-jobs.py /tmp/check-jobs.py && pct exec 112 -- python3 /tmp/check-jobs.py"])
