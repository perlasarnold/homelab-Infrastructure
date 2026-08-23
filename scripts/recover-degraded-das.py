import subprocess
import sys
import time

CEBU_IP = "192.168.1.26"
TRUENAS_IP = "192.168.1.211"
PLEX_CT_ID = "109"

def run_ssh(host, cmd_args, input_data=None):
    """Executes a command via SSH on the target host."""
    full_args = ["ssh", f"root@{host}"] + cmd_args
    res = subprocess.run(full_args, input=input_data, capture_output=True, text=True, encoding="utf-8")
    return res

def main():
    print("=================================================================")
    print("   Cebu DAS Storage & TrueNAS VM Recovery Automation Script")
    print("=================================================================")
    
    # 1. Check Cebu host ZFS pools status
    print("\n[Step 1] Checking Cebu ZFS pools health status...")
    res = run_ssh(CEBU_IP, ["zpool", "status"])
    if res.returncode != 0:
        print(f"Error: Failed to connect to Cebu host ({CEBU_IP}). Details:")
        print(res.stderr)
        sys.exit(1)
        
    status_output = res.stdout
    pools_needing_clear = []
    
    # Check for degraded or faulted pools
    for pool in ["das-18tb-1", "das-18tb-2", "das-18tb-3", "das-6tb", "cebu-zfs"]:
        if pool in status_output:
            # Check individual pool health status
            res_pool = run_ssh(CEBU_IP, ["zpool", "list", "-H", "-o", "health", pool])
            health = res_pool.stdout.strip() if res_pool.returncode == 0 else "UNKNOWN"
            print(f" - Pool '{pool}': {health}")
            if health in ["DEGRADED", "FAULTED"] or "too many errors" in status_output or "ONLINE" not in health:
                pools_needing_clear.append(pool)
                
    if pools_needing_clear:
        print("\n[!] Degraded or faulted ZFS pools found. Attempting to clear errors...")
        for pool in pools_needing_clear:
            print(f" -> Clearing errors on pool: {pool}")
            res_clear = run_ssh(CEBU_IP, ["zpool", "clear", pool])
            if res_clear.returncode == 0:
                print(f"    Successfully cleared pool '{pool}'.")
            else:
                print(f"    Failed to clear pool '{pool}': {res_clear.stderr.strip()}")
        
        # Verify if pools are online now
        print("Rechecking pools status...")
        time.sleep(2)
        res_recheck = run_ssh(CEBU_IP, ["zpool", "status"])
        print(res_recheck.stdout)
    else:
        print(" -> All ZFS pools report ONLINE/healthy.")

    # 2. Check TrueNAS VM (VM 120) status
    print("\n[Step 2] Checking TrueNAS SCALE VM (VM 120) status...")
    res_vm = run_ssh(CEBU_IP, ["qm", "status", "120", "--verbose"])
    if res_vm.returncode != 0:
        print("Error: Failed to retrieve status of VM 120.")
        sys.exit(1)
        
    vm_status = {}
    for line in res_vm.stdout.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            vm_status[k.strip()] = v.strip()
            
    qmpstatus = vm_status.get("qmpstatus", "unknown")
    status = vm_status.get("status", "unknown")
    print(f" - VM Status: {status}")
    print(f" - QEMU QMP Status: {qmpstatus}")
    
    if qmpstatus == "io-error":
        print("\n[!] TrueNAS VM has experienced a disk I/O error and is paused.")
        print(" -> Resuming TrueNAS VM execution...")
        res_resume = run_ssh(CEBU_IP, ["qm", "resume", "120"])
        if res_resume.returncode == 0:
            print("    VM resume signal sent successfully.")
        else:
            print(f"    Failed to resume VM: {res_resume.stderr.strip()}")
            
        print(" -> Waiting 10 seconds for VM to process pending commands / reboot...")
        time.sleep(10)
        
        # Recheck VM status
        res_vm = run_ssh(CEBU_IP, ["qm", "status", "120", "--verbose"])
        for line in res_vm.stdout.splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                vm_status[k.strip()] = v.strip()
        status = vm_status.get("status", "unknown")
        print(f" - New VM Status: {status}")
        
    if status == "stopped":
        print("\n[!] TrueNAS VM is stopped. Starting it cleanly...")
        res_start = run_ssh(CEBU_IP, ["qm", "start", "120"])
        if res_start.returncode == 0:
            print("    TrueNAS VM started successfully.")
        else:
            print(f"    Failed to start VM: {res_start.stderr.strip()}")
        print(" -> Waiting 30 seconds for TrueNAS to boot and initialize network...")
        time.sleep(30)
    elif status == "running" and qmpstatus != "io-error":
        print(" - TrueNAS VM is running and responsive at hypervisor level.")

    # 3. Check network ping to TrueNAS
    print(f"\n[Step 3] Checking network ping to TrueNAS IP ({TRUENAS_IP})...")
    ping_success = False
    for attempt in range(5):
        res_ping = run_ssh(CEBU_IP, ["ping", "-c", "2", "-W", "2", TRUENAS_IP])
        if res_ping.returncode == 0:
            print(f" -> TrueNAS IP ({TRUENAS_IP}) is reachable.")
            ping_success = True
            break
        else:
            print(f" -> Reachability check {attempt+1}/5: waiting for network...")
            time.sleep(5)
            
    if not ping_success:
        print("[!] Warning: TrueNAS VM is running but network is unreachable. Please check TrueNAS console.")
        sys.exit(1)

    # 4. Check Cebu host mount status
    print("\n[Step 4] Checking CIFS storage mount points on Cebu host...")
    mount_paths = {
        "/mnt/cebu-seagate": "//192.168.1.211/seagate/Share",
        "/mnt/truenas-photo": "//192.168.1.211/photo",
        "/mnt/truenas/seagate": "//192.168.1.211/seagate/Share"
    }
    
    res_df = run_ssh(CEBU_IP, ["df", "-h"])
    df_output = res_df.stdout
    
    unmounted = []
    for path, share in mount_paths.items():
        if path not in df_output:
            print(f" - Mount '{path}' is OFFLINE.")
            unmounted.append(path)
        else:
            print(f" - Mount '{path}' is ONLINE.")
            
    if unmounted:
        print("\n[!] Missing mount points found. Attempting to mount them...")
        res_mount = run_ssh(CEBU_IP, ["mount", "-a"])
        time.sleep(2)
        res_df = run_ssh(CEBU_IP, ["df", "-h"])
        df_output = res_df.stdout
        
        still_unmounted = []
        for path in unmounted:
            if path not in df_output:
                still_unmounted.append(path)
                
        if still_unmounted:
            print("[!] Some mount points failed to mount automatically via 'mount -a':")
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
        print(" -> All CIFS mount points are online on the Cebu host.")

    # 5. Check Plex container (109) read accessibility
    print("\n[Step 5] Checking Plex container (LXC 109) media accessibility...")
    res_plex = run_ssh(CEBU_IP, ["pct", "status", "109"])
    if "status: running" in res_plex.stdout:
        print(" - Plex container is running.")
        print(" -> Testing directory readability as 'plex' user...")
        res_read = run_ssh(CEBU_IP, ["pct exec 109 -- su -s /bin/bash -c 'ls -l /mnt/seagate/Movies' plex"])
        if res_read.returncode == 0:
            print(" -> [SUCCESS] Plex user can successfully read files on the TrueNAS mount!")
        else:
            print(" -> [WARNING] Plex user failed to read files on the TrueNAS mount. Error:")
            print(res_read.stderr.strip() or res_read.stdout.strip())
            print("    Consider restarting the plex container: 'pct reboot 109'")
    else:
        print(" - Plex container is stopped. Starting it...")
        run_ssh(CEBU_IP, ["pct", "start", "109"])
        print("    Plex container started.")

    print("\n=================================================================")
    print("   Recovery automation complete.")
    print("=================================================================")

if __name__ == "__main__":
    main()
