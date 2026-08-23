import subprocess
import json

CEBU = "192.168.1.26"

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    return res

script = """#!/bin/bash
zfs get compressratio,compression,used,logicalused DAS2-18TB/photo
zfs get compressratio,compression,used,logicalused DAS1-18TB/photo
"""

run_ssh(CEBU, ["cat > /tmp/check-compression.sh"], input_data=script)
res = run_ssh(CEBU, ["qm", "guest", "exec", "120", "--", "sh", "/tmp/check-compression.sh"])

try:
    data = json.loads(res.stdout)
    print(data.get("out-data", ""))
    print(data.get("err-data", ""))
except:
    print(res.stdout)
