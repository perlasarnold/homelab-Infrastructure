import subprocess

CEBU = "192.168.1.26"

cebu_script_content = """import subprocess
import time
import json

def run_local(cmd_args):
    print(f"Running locally: {' '.join(cmd_args)}")
    res = subprocess.run(cmd_args, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"FAILED (code {res.returncode})")
        if res.stdout:
            print(f"STDOUT: {res.stdout.strip()}")
        if res.stderr:
            print(f"STDERR: {res.stderr.strip()}")
    else:
        print("SUCCESS")
        if res.stdout:
            print(res.stdout.strip())
    return res

print("--- Step 1: Update SMB Share Path on TrueNAS (VM 120) ---")
update_cmd = ["qm", "guest", "exec", "120", "--", "midclt", "call", "sharing.smb.update", "2", '{"path": "/mnt/DAS2-18TB/photo"}']
run_local(update_cmd)

print("\\n--- Step 2: Restart CIFS Service on TrueNAS ---")
restart_cmd = ["qm", "guest", "exec", "120", "--", "midclt", "call", "service.restart", "cifs"]
run_local(restart_cmd)

print("\\n--- Step 3: Verify SMB Share Path in TrueNAS ---")
query_cmd = ["qm", "guest", "exec", "120", "--", "midclt", "call", "sharing.smb.query"]
run_local(query_cmd)

print("\\n--- Step 4: Waiting for CIFS Service to initialize... (15 seconds) ---")
time.sleep(15)

print("\\n--- Step 5: Lazy Unmount and Remount on Cebu Host ---")
unmount_cmd = ["umount", "-f", "-l", "/mnt/truenas-photo"]
run_local(unmount_cmd)

time.sleep(3)

mount_cmd = ["mount", "/mnt/truenas-photo"]
run_local(mount_cmd)

time.sleep(2)

df_cmd = ["df", "-h", "/mnt/truenas-photo"]
run_local(df_cmd)

print("\\n--- Step 6: Start Immich LXC Container 112 ---")
start_cmd = ["pct", "start", "112"]
run_local(start_cmd)

status_cmd = ["pct", "status", "112"]
run_local(status_cmd)
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        print(f"FAILED: {' '.join(full_args)}")
        if res.stdout:
            print(res.stdout)
        if res.stderr:
            print(res.stderr)
    else:
        print(f"SUCCESS: {' '.join(full_args)}")
        if res.stdout:
            print(res.stdout)
    return res

print("--- Step A: Write Python Cutover Script to Cebu Host ---")
run_ssh(CEBU, ["cat > /tmp/execute-cutover-cebu.py"], input_data=cebu_script_content)

print("\n--- Step B: Execute Cutover Script Natively on Cebu Host ---")
run_ssh(CEBU, ["python3 /tmp/execute-cutover-cebu.py"])
