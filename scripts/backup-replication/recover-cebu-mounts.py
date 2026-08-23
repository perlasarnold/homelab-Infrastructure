import subprocess
import sys
import time

CEBU_IP = "192.168.1.26"
TRUENAS_IP = "192.168.1.211"
SYNOLOGY_IP = "192.168.1.12"
CONTAINERS = {
    "109": "Plex",
    "416": "Jellyfin"
}

def run_ssh(host, cmd_args, input_data=None):
    """Executes a command via SSH on the target host."""
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    return res

def main():
    print("=================================================================")
    print("      Cebu Storage Mounts Recovery Automation Script")
    print("=================================================================")
    
    # 1. Ping storage servers
    print(f"\n[Step 1] Checking network connectivity to storage servers...")
    
    for label, ip in [("TrueNAS", TRUENAS_IP), ("Synology NAS", SYNOLOGY_IP)]:
        ping_success = False
        for attempt in range(3):
            res_ping = run_ssh(CEBU_IP, ["ping", "-c", "2", "-W", "2", ip])
            if res_ping.returncode == 0:
                print(f" -> {label} ({ip}) is reachable from Cebu.")
                ping_success = True
                break
            print(f" -> {label} reachability check {attempt+1}/3: waiting...")
            time.sleep(3)
            
        if not ping_success:
            print(f"[!] Error: {label} ({ip}) is unreachable from Cebu. Aborting.")
            sys.exit(1)

    # 2. Check mount status on host
    print("\n[Step 2] Checking CIFS storage mount points on Cebu host...")
    mount_paths = {
        "/mnt/cebu-seagate": "//192.168.1.211/seagate/Share",
        "/mnt/plex": "//192.168.1.12/PlexMediaStorage",
        "/mnt/plex1": "//192.168.1.12/Seagate",
        "/mnt/truenas-photo": "//192.168.1.211/photo",
        "/mnt/truenas/seagate": "//192.168.1.211/seagate/Share"
    }
    
    res_df = run_ssh(CEBU_IP, ["df", "-h"])
    if res_df.returncode != 0:
        print(f"Error: Failed to connect to Cebu host ({CEBU_IP}).")
        print(res_df.stderr)
        sys.exit(1)
        
    df_output = res_df.stdout
    unmounted = []
    
    for path, share in mount_paths.items():
        if path not in df_output:
            print(f" - Mount '{path}' is OFFLINE.")
            unmounted.append(path)
        else:
            print(f" - Mount '{path}' is ONLINE.")
            
    # 3. Mount offline directories
    if unmounted:
        print("\n[Step 3] Restoring offline mount points...")
        res_mount = run_ssh(CEBU_IP, ["mount", "-a"])
        time.sleep(2)
        
        # Verify
        res_df = run_ssh(CEBU_IP, ["df", "-h"])
        df_output = res_df.stdout
        still_unmounted = [p for p in unmounted if p not in df_output]
        
        if still_unmounted:
            print("[!] Warning: Some mounts failed to mount automatically via 'mount -a':")
            for path in still_unmounted:
                print(f"  -> Attempting manual mount for {path}...")
                res_man = run_ssh(CEBU_IP, ["mount", "-v", path])
                if res_man.returncode == 0:
                    print(f"     Successfully mounted {path}.")
                else:
                    print(f"     Failed to mount {path}: {res_man.stderr.strip()}")
        else:
            print(" -> All mount points successfully restored.")
    else:
        print("\n[Step 3] All CIFS mount points are online on the Cebu host.")

    # 4. Restart containers to refresh bind mounts
    print("\n[Step 4] Restarting media LXC containers...")
    for ct_id, name in CONTAINERS.items():
        print(f" -> Rebooting {name} (CT {ct_id})...")
        res_reboot = run_ssh(CEBU_IP, ["pct", "reboot", ct_id])
        if res_reboot.returncode == 0:
            print(f"    Reboot signal sent successfully to {name}.")
        else:
            print(f"    Failed to reboot {name}: {res_reboot.stderr.strip()}")
            
    print(" -> Waiting 10 seconds for containers to initialize...")
    time.sleep(10)

    # 5. Verify container readability and active status
    print("\n[Step 5] Checking container mount connectivity and service statuses...")
    for ct_id, name in CONTAINERS.items():
        print(f"\n--- Checking {name} (CT {ct_id}) ---")
        # Check running status
        res_status = run_ssh(CEBU_IP, ["pct", "status", ct_id])
        print(f" - Container Status: {res_status.stdout.strip()}")
        
        # Check directory readability
        test_path = "/shared" if ct_id == "109" else "/mnt/seagate"
        res_read = run_ssh(CEBU_IP, ["pct", "exec", ct_id, "--", "ls", test_path])
        if res_read.returncode == 0:
            print(" - Directory Visibility: OK")
        else:
            print(f" - [WARNING] Directory Visibility FAILED: {res_read.stderr.strip()}")
            
        # Check service status
        service_name = "plexmediaserver" if ct_id == "109" else "jellyfin"
        res_service = run_ssh(CEBU_IP, ["pct", "exec", ct_id, "--", "systemctl", "is-active", service_name])
        print(f" - Service Status ({service_name}): {res_service.stdout.strip()}")

    print("\n=================================================================")
    print("      Recovery automation complete.")
    print("=================================================================")

if __name__ == "__main__":
    main()
