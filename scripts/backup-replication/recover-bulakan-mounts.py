import subprocess
import sys
import time

BULAKAN_IP = "192.168.1.25"
SYNOLOGY_IP = "192.168.1.12"
CONTAINERS = {
    "104": "Plex",
    "110": "Jellyfin",
    "100": "Audiobookshelf"
}

def run_ssh(host, cmd_args, input_data=None):
    """Executes a command via SSH on the target host."""
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    return res

def main():
    print("=================================================================")
    print("      Bulakan Synology Mounts Recovery Automation Script")
    print("=================================================================")
    
    # 1. Ping Synology NAS to verify online status
    print(f"\n[Step 1] Checking network connectivity to Synology NAS ({SYNOLOGY_IP})...")
    ping_success = False
    for attempt in range(3):
        # On Windows, ping uses -n instead of -c, but we can do a local ping or check it from the host.
        # Let's ping from the host itself to make sure the host has route.
        res_ping = run_ssh(BULAKAN_IP, ["ping", "-c", "2", "-W", "2", SYNOLOGY_IP])
        if res_ping.returncode == 0:
            print(" -> Synology NAS is reachable from Bulakan.")
            ping_success = True
            break
            
        print(f" -> Reachability check {attempt+1}/3: waiting...")
        time.sleep(3)
        
    if not ping_success:
        print("[!] Error: Synology NAS is unreachable from Bulakan. Please check NAS power and network.")
        sys.exit(1)

    # 2. Check mount status on host
    print("\n[Step 2] Checking CIFS storage mount points on Bulakan host...")
    mount_paths = {
        "/mnt/plex": "//192.168.1.12/PlexMediaStorage",
        "/mnt/plex1": "//192.168.1.12/Seagate",
        "/mnt/pnas_photos": "//192.168.1.12/photo",
        "/mnt/audiobooks": "//192.168.1.12/Media/Audiobooks"
    }
    
    res_df = run_ssh(BULAKAN_IP, ["df", "-h"])
    if res_df.returncode != 0:
        print(f"Error: Failed to connect to Bulakan host ({BULAKAN_IP}).")
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
        res_mount = run_ssh(BULAKAN_IP, ["mount", "-a"])
        time.sleep(2)
        
        # Verify
        res_df = run_ssh(BULAKAN_IP, ["df", "-h"])
        df_output = res_df.stdout
        still_unmounted = [p for p in unmounted if p not in df_output]
        
        if still_unmounted:
            print("[!] Warning: Some mounts failed to mount automatically via 'mount -a':")
            for path in still_unmounted:
                print(f"  -> Attempting manual mount for {path}...")
                res_man = run_ssh(BULAKAN_IP, ["mount", "-v", path])
                if res_man.returncode == 0:
                    print(f"     Successfully mounted {path}.")
                else:
                    print(f"     Failed to mount {path}: {res_man.stderr.strip()}")
        else:
            print(" -> All mount points successfully restored.")
    else:
        print("\n[Step 3] All CIFS mount points are online on the Bulakan host.")

    # 4. Restart containers to refresh bind mounts
    print("\n[Step 4] Restarting media LXC containers...")
    for ct_id, name in CONTAINERS.items():
        print(f" -> Rebooting {name} (CT {ct_id})...")
        res_reboot = run_ssh(BULAKAN_IP, ["pct", "reboot", ct_id])
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
        res_status = run_ssh(BULAKAN_IP, ["pct", "status", ct_id])
        print(f" - Container Status: {res_status.stdout.strip()}")
        
        # Check directory readability
        test_path = "/shared" if ct_id != "100" else "/mnt/audiobooks"
        res_read = run_ssh(BULAKAN_IP, ["pct", "exec", ct_id, "--", "ls", test_path])
        if res_read.returncode == 0:
            print(" - Directory Visibility: OK")
        else:
            print(f" - [WARNING] Directory Visibility FAILED: {res_read.stderr.strip()}")
            
        # Check service status
        service_name = "plexmediaserver" if ct_id == "104" else "jellyfin" if ct_id == "110" else "audiobookshelf"
        res_service = run_ssh(BULAKAN_IP, ["pct", "exec", ct_id, "--", "systemctl", "is-active", service_name])
        print(f" - Service Status ({service_name}): {res_service.stdout.strip()}")

    print("\n=================================================================")
    print("      Recovery automation complete.")
    print("=================================================================")

if __name__ == "__main__":
    main()
