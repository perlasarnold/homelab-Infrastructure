import subprocess

CEBU = "192.168.1.26"

script_content = """#!/bin/bash
pct exec 112 -- sudo -u postgres psql -d immich -c 'SELECT id, name, type, "importPaths" FROM library;'
pct exec 112 -- sudo -u postgres psql -d immich -c "SELECT count(*) AS photography_assets FROM asset WHERE \\"originalPath\\" LIKE '/mnt/truenas-photo/Photography/%';"
pct exec 112 -- sudo -u postgres psql -d immich -c "SELECT count(*) AS edits_assets FROM asset WHERE \\"originalPath\\" LIKE '/mnt/truenas-photo/Edits/%';"
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)
    return res

run_ssh(CEBU, ["cat > /tmp/check-libs.sh"], input_data=script_content)
run_ssh(CEBU, ["bash /tmp/check-libs.sh"])
