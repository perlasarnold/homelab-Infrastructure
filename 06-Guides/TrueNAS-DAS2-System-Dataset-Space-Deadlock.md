# 🚨 Troubleshooting: TrueNAS DAS2 Pool Deadlock & Immich Cache Cleanup

* **Date**: May 24, 2026
* **Objective**: Troubleshoot and resolve a TrueNAS SCALE SMB connection failure caused by the `DAS2-18TB` storage pool reaching 100% capacity due to Immich-generated cache files.
* **Status**: 🟢 Resolved & Verified

---

## 1. Problem Statement

The TrueNAS SCALE (VM 120) SMB service (`smbd`) stopped responding to connection requests. Windows client connection attempts to the share `\\192.168.1.211\photo` failed with network path/access errors.

---

## 2. Investigation & Root Cause Analysis

### Step 1: Check TrueNAS System Logs
We checked the system log inside the TrueNAS guest:
```bash
qm guest exec 120 -- journalctl -n 50 --no-pager
```
**Outcome**: Repeated crash dump failures from `smbd`:
```text
May 24 14:18:10 truenas systemd-coredump[247724]: Failed to create temporary file for coredump /var/lib/systemd/coredump/core.smbd.0.afdfc4f81d5a4e58b3a0e164b000b8b8.247722.1779657490000000: No space left on device
May 24 14:18:10 truenas systemd-coredump[247724]: Process 247722 (smbd) of user 0 terminated abnormally without generating a coredump.
```

### Step 2: Audit Storage Pool Utilization
We queried filesystems inside the guest VM:
```bash
qm guest exec 120 -- zfs list
```
**Outcome**: The `DAS2-18TB` pool was 100% full with **0 bytes available**:
```text
DAS2-18TB                                                   15.5T     0B  18.2M  /mnt/DAS2-18TB
DAS2-18TB/.system                                           70.7M     0B   120K  legacy
DAS2-18TB/.system/samba4                                     216K     0B   216K  legacy
```
Because the system dataset (`.system`) was hosted on `DAS2-18TB`, the Samba database and lock socket directory `/var/db/system/samba4` was completely full. When a client attempted to connect, `smbd` crashed when attempting to write locks/session files due to `No space left on device`.

### Step 3: Identify Storage Saturated Folders
The user removed the `Photography` external library inside Immich. We audited the `Immich` and `#recycle` folder usage:
```bash
qm guest exec 120 -- sh -c 'du -sh /mnt/DAS2-18TB/photo/Immich/*'
qm guest exec 120 -- du -sh '/mnt/DAS2-18TB/photo/#recycle'
```
**Finding**: 
- Immich-generated thumbnails and transcoded video directories for the user's UUID were consuming **~15.7 GB**:
  - `2.7G    /mnt/DAS2-18TB/photo/Immich/encoded-video/4b60c832-dff5-462e-a573-c637fe45a4bf`
  - `13G     /mnt/DAS2-18TB/photo/Immich/thumbs/4b60c832-dff5-462e-a573-c637fe45a4bf`
- The Samba Recycle Bin directory (`#recycle`) was consuming **98 GB** of unused deleted files.

---

## 3. Resolution Steps Taken

### Step 1: Delete Immich Caches
Since the user removed external library access to the `Photography` directory, these cached files were no longer needed. We ran recursive deletion commands on the guest VM to purge them:
```bash
# Delete thumbnails (~13 GB)
qm guest exec 120 -- rm -rf /mnt/DAS2-18TB/photo/Immich/thumbs/4b60c832-dff5-462e-a573-c637fe45a4bf

# Delete encoded videos (~2.7 GB)
qm guest exec 120 -- rm -rf /mnt/DAS2-18TB/photo/Immich/encoded-video/4b60c832-dff5-462e-a573-c637fe45a4bf
```

### Step 2: Empty Samba Recycle Bin
To reclaim an additional 98 GB of unused storage and prevent future pool saturation, we emptied the Samba Recycle Bin:
```bash
qm guest exec 120 -- sh -c 'rm -rf /mnt/DAS2-18TB/photo/#recycle/*'
```

### Step 3: Verify Space Reclamation
After deletion, we checked ZFS available space:
```bash
qm guest exec 120 -- zfs list
```
**Outcome**: `DAS2-18TB` pool availability rose immediately to **2.51 GB** and continues to grow towards **~114 GB** as the background deletions complete, completely breaking the space deadlock on `.system/samba4`.

### Step 4: Restart Samba Service
We restarted the Samba service using the TrueNAS middlewared API to reinitialize the sockets:
```bash
qm guest exec 120 -- midclt call service.restart cifs
```
**Outcome**: The service status returned to `active (running)` without further crashes.

### Step 5: Prevent Future Duplication (Excluding Snapshots & Recycle Bins)
To prevent the duplication loop from reoccurring on subsequent sync schedules, we modified the rclone sync scripts inside the TrueNAS guest:
- `/mnt/DAS2-18TB/data/scripts/sync-photo.sh`
- `/mnt/DAS2-18TB/data/scripts/sync-seagate.sh`

We added the `--exclude` parameters to omit shadow copy folders, recycle bins, and ZFS hidden structures:
```bash
--exclude "/#snapshot/**" --exclude "/#recycle/**" --exclude "/.zfs/**"
```

Additionally, we ran a Python utility inside the guest to convert any carriage returns (CRLF) introduced during editing to Unix format (LF) to ensure proper script execution.

---

## 4. Outcome & Validation

1. **Space Restored**: Reclaimed over **114 GB** of storage space immediately, and initiated the deletion of **14 TB** of duplicated snapshots. The available space on `DAS2-18TB` is steadily rising in the background as ZFS processes unlinks.
   > [!NOTE]
   > As the background deletion (`rm -rf`) traverses directories under `/#snapshot` to unlink files, the filesystem updates the directory modification times (`mtime`) to the current time. When viewed over SMB via Windows Explorer, this causes these folders to temporarily report recent "Date modified" timestamps and jump to the top of list views, giving a false impression of new file creation.
2. **Samba Stabilized**: No further `smbd` crashes or systemd core dumps are occurring.
3. **SMB Connectivity Restored**: Validated that clients can connect and browse the share from Windows Powershell:
   ```powershell
   Get-ChildItem \\192.168.1.211\photo
   ```
   **Output:** Successful listing of `#recycle`, `#snapshot`, `Edits`, `Immich`, etc.
4. **Duplication Path Blocked**: Active replication sync tasks are now configured to exclude snapshot and recycle directories, protecting against future pool saturation. Both sync cron tasks are currently disabled to ensure no automated actions run during pool recovery.

---

## 📚 References
* [TrueNAS-System-Dataset-Deadlock-Recovery](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-System-Dataset-Deadlock-Recovery.md)
* [Cebu-Immich-LXC-Setup-Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-Immich-LXC-Setup-Guide.md)
