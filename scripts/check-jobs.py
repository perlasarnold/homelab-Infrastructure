import subprocess

CEBU = "192.168.1.26"

script_content = """import subprocess
import json

def run_guest_cmd(args):
    cmd = ["pct", "exec", "112", "--"] + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout.strip()

api_key = run_guest_cmd(["sudo", "-u", "postgres", "psql", "-d", "immich", "-t", "-A", "-c", "SELECT key FROM api_key LIMIT 1;"])

curl_cmd = [
    "curl", "-s", "-H", f"x-api-key: {api_key}", "http://127.0.0.1:2283/api/jobs"
]
jobs_json = run_guest_cmd(curl_cmd)

try:
    jobs = json.loads(jobs_json)
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
except Exception as e:
    print(f"Failed to parse jobs JSON: {e}")
    print(jobs_json)
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)
    return res

run_ssh(CEBU, ["cat > /tmp/check-jobs.py"], input_data=script_content)
run_ssh(CEBU, ["python3 /tmp/check-jobs.py"])
