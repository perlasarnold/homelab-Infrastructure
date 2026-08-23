import subprocess

CEBU = "192.168.1.26"

create_script = r"""import json
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
print("Fetching API key from Immich DB...")
db_res = subprocess.run(
    ["sudo", "-u", "postgres", "psql", "-d", "immich", "-t", "-A", "-c",
     "SELECT key FROM api_keys LIMIT 1;"],
    capture_output=True, text=True
)
api_key = db_res.stdout.strip()
print(f"Key: {api_key[:12]}..." if api_key else "No key in DB")

if not api_key:
    print("No API key found - exiting")
    exit(1)

# Get user info
me = api("GET", "/api/users/me", api_key=api_key)
if not me:
    print("ERROR: API key invalid")
    exit(1)
user_id = me.get("id")
print(f"User: {me.get('email')} | ID: {user_id}")

# List existing libraries to avoid duplicates
existing = api("GET", "/api/libraries", api_key=api_key) or []
existing_names = [l.get("name") for l in existing]
print(f"Existing libraries: {existing_names}")

for lib_name, lib_path in [("Photography", "/mnt/truenas-photo/Photography"), ("Edits", "/mnt/truenas-photo/Edits")]:
    if lib_name in existing_names:
        print(f"\n{lib_name} library already exists, skipping creation.")
        lib_id = next(l["id"] for l in existing if l["name"] == lib_name)
    else:
        print(f"\nCreating {lib_name} external library...")
        lib = api("POST", "/api/libraries", {
            "ownerId": user_id,
            "importPaths": [lib_path],
            "name": lib_name,
            "exclusionPatterns": []
        }, api_key=api_key)
        if not lib:
            print(f"  FAILED")
            continue
        lib_id = lib.get("id")
        print(f"  Created: {lib_id}")

    # Trigger scan
    scan_resp = api("POST", f"/api/libraries/{lib_id}/scan", {}, api_key=api_key)
    print(f"  Scan triggered: {scan_resp}")

# Final list
print("\nFinal library list:")
all_libs = api("GET", "/api/libraries", api_key=api_key) or []
for l in all_libs:
    print(f"  [{l.get('type','?')}] {l.get('name')} -> {l.get('importPaths')}")
"""

def run_ssh(host, cmd_args, input_data=None):
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    if res.stdout:
        print(res.stdout)
    if res.stderr:
        print("STDERR:", res.stderr)
    return res

# Write script to Cebu, then copy into container and execute
run_ssh(CEBU, ["cat > /tmp/create-libraries.py"], input_data=create_script)
run_ssh(CEBU, ["sh", "-c", "pct push 112 /tmp/create-libraries.py /tmp/create-libraries.py && pct exec 112 -- python3 /tmp/create-libraries.py"])
