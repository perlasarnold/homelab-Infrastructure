# 🚨 Troubleshooting: TrueNAS System Dataset Deadlock and SMB Service Recovery

* **Date**: May 21, 2026
* **Objective**: Diagnose and resolve the TrueNAS SCALE SMB (`smbd`) service startup failure caused by a space deadlock on the system dataset (`/var/db/system`), and finalize the photo storage migration cutover.
* **Status**: 🟢 Resolved & Verified

---

## 1. Problem Statement

During the final cutover of the photo storage migration from `DAS1-18TB` to `DAS2-18TB`, the Samba service (`smbd`) on TrueNAS SCALE (VM 120) crashed and refused to start. Attempts to mount the SMB share `//192.168.1.211/photo` on the Proxmox Cebu host (`192.168.1.26`) failed with:

```text
mount error: Server abruptly closed the connection.
mount error(112): Host is down
```

As a result, the Immich LXC container (ID 112) on Cebu host failed to start due to its pre-start mount checks failing.

---

## 2. Investigation & Root Cause Analysis

### Step 1: Check Samba Daemon Status
We queried the status of the Samba service inside the TrueNAS guest:
```bash
qm guest exec 120 -- systemctl status smbd
```
**Outcome**: The service status was `failed (Result: exit-code)` with code `status=1/FAILURE`.

### Step 2: Execute Samba in Debug Mode
To capture the exact initialization failure, we ran `smbd` in the foreground with debugging enabled:
```bash
qm guest exec 120 -- smbd -i -d 3
```
**Output**:
```text
messaging_dgm_init: bind failed: No space left on device
messaging_dgm_ref failed: No space left on device
```

### Step 3: Analyze Storage Mounts and Space Availability
We inspected the filesystem space allocation inside the TrueNAS VM using `df -h`:
```text
DAS1-18TB/photo                 9.5T  9.5T     0 100% /mnt/DAS1-18TB/photo
DAS1-18TB/.system/samba4        256K  256K     0 100% /var/db/system/samba4
```
**Finding**: The TrueNAS System Dataset (`/var/db/system`) was located on the `DAS1-18TB` pool, which was 100% saturated. Because Samba stores active lock files, sockets, and databases under `/var/db/system/samba4`, it was unable to create messaging sockets and crashed with `No space left on device`.

---

## 3. Resolution Plan & Steps Taken

### Step 1: Migrate System Dataset to DAS2
Since the newly migrated pool (`DAS2-18TB`) had 6.2 TB of free space, we moved the TrueNAS system dataset there using the middlewared API:
```bash
# Call the update service natively on Cebu to avoid nested shell quoting issues:
qm guest exec 120 -- midclt call systemdataset.update '{"pool": "DAS2-18TB"}'
```
*Note: This command returned Job ID `5937`.*

We verified migration job completion:
```bash
qm guest exec 120 -- midclt call core.get_jobs '[["id", "=", 5937]]'
```
**Outcome**: Completed successfully with status `SUCCESS` and automatically relocated the system dataset to `DAS2-18TB/.system`.

### Step 2: Restart the CIFS Service
We restarted the Samba service using the TrueNAS middlewared API:
```bash
qm guest exec 120 -- midclt call service.restart cifs
```
**Outcome**: The service restarted successfully and `systemctl status smbd` returned `active (running)`.

### Step 3: Remount the SMB Share on Cebu Host
On the Cebu Proxmox host, we lazy-unmounted the stale mount and remounted it:
```bash
umount -f -l /mnt/truenas-photo
mount /mnt/truenas-photo
df -h /mnt/truenas-photo
```
**Outcome**: Mounted successfully:
`//192.168.1.211/photo   16T  9.4T  6.2T  61% /mnt/truenas-photo`

### Step 4: Start the Immich LXC Container
We started Container 112 on Cebu:
```bash
pct start 112
```
**Outcome**: The container started successfully and Immich services (`immich-ml.service`, `immich-web.service`) returned to an active running state.

### Step 5: Reclaim DAS1 Pool Space
With the new SMB share verified and running, we destroyed the old photo dataset inside the TrueNAS guest:
```bash
qm guest exec 120 -- zfs destroy -r DAS1-18TB/photo
```
**Outcome**: Reclaimed **9.45 TB** of space on the `DAS1-18TB` pool (released asynchronously in the background).

### Step 6: Restore and Update the Photo Sync Script
Since the previous write attempts during the space deadlock left `/mnt/DAS1-18TB/data/scripts/sync-photo.sh` truncated to 0 bytes, we restored its original contents and updated the destination path to `/mnt/DAS2-18TB/photo/`:
```bash
# Script content restored and written:
rclone --config /mnt/DAS1-18TB/data/rclone.conf sync photo-source:photo /mnt/DAS2-18TB/photo/ --log-file /mnt/DAS1-18TB/data/scripts/sync-photo.log --log-level INFO
```

We then re-enabled the photo sync cron job on TrueNAS:
```bash
qm guest exec 120 -- midclt call cronjob.update 2 '{"enabled": true}'
```

---

## 4. Outcome & Validation

1. **SMB Share Path Redirected**: Verified that the SMB share `photo` now points to `/mnt/DAS2-18TB/photo`.
2. **Mounts Restored**: Cebu Host mount `/mnt/truenas-photo` successfully points to the 16 TB share on `DAS2-18TB` with 6.2 TB free space.
3. **Application Live**: Immich container is online and fully functional.
4. **Cron Job Enabled**: The sync cron job was re-enabled inside TrueNAS.

---

## 📚 References
* [Cebu-Immich-LXC-Setup-Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-Immich-LXC-Setup-Guide.md)
* [TrueNAS-on-Proxmox-Setup](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-on-Proxmox-Setup.md)
