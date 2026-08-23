import subprocess

CEBU = "192.168.1.26"

script_content = """import subprocess

def run_guest_cmd(args):
    cmd = ["pct", "exec", "112", "--"] + args
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.stdout.strip()

queues = ["thumbnailGeneration", "metadataExtraction", "faceDetection", "smartSearch", "videoConversion", "library"]
states = ["active", "waiting", "delayed"]

print("Immich Queue Lengths (from Redis):")
print("-" * 60)
print(f"{'Queue':<25} | {'Active':<8} | {'Waiting':<8} | {'Delayed':<8}")
print("-" * 60)

for q in queues:
    counts = {}
    for s in states:
        key = f"immich_bull:{q}:{s}"
        out = run_guest_cmd(["redis-cli", "-p", "6379", "llen", key])
        if "WRONGTYPE" in out or not out.isdigit():
            out = run_guest_cmd(["redis-cli", "-p", "6379", "zcard", key])
            if "WRONGTYPE" in out or not out.isdigit():
                out = "0"
        
        counts[s] = out
        
    if int(counts["active"]) > 0 or int(counts["waiting"]) > 0 or int(counts["delayed"]) > 0:
        print(f"{q:<25} | {counts['active']:<8} | {counts['waiting']:<8} | {counts['delayed']:<8}")

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

run_ssh(CEBU, ["cat > /tmp/check-redis-jobs.py"], input_data=script_content)
run_ssh(CEBU, ["python3 /tmp/check-redis-jobs.py"])
