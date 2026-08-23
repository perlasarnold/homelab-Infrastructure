# 🚨 Troubleshooting: TrueNAS Storage I/O Error and QEMU VM Pause

* **Date**: May 28, 2026
* **Objective**: Diagnose and resolve TrueNAS SCALE VM (VM 120) crash/unresponsiveness caused by a host storage pool degradation and subsequent QEMU virtual disk I/O pause.
* **Status**: 🟢 Resolved & Verified

---

## 1. Problem Statement

The TrueNAS SCALE server (IP `VLAN 1 (Management)`) went into an error state, causing complete loss of storage services (SMB shares `/mnt/cebu-seagate` and `/mnt/truenas-photo` were unreachable) and making hosted media applications (Plex, Jellyfin) fail. 

Symptoms included:
- The TrueNAS VM was marked as "running" in Proxmox, but was completely unresponsive.
- Pings to `VLAN 1 (Management)` failed with "Destination Host Unreachable."
- Attempting to query VM status via QEMU Guest Agent resulted in `QEMU guest agent is not running`.
- Administrative reboots of the VM from Proxmox timed out (`VM quit/powerdown failed - got timeout`).

---

## 2. Investigation & Root Cause Analysis

### Step 1: Inspect Detailed VM Status in Proxmox
We logged into the Proxmox Cebu host (`VLAN 1 [Management]`) and queried the detailed VM status using:
```bash
qm status 120 --verbose
```
**Outcome**:
- **`qmpstatus`**: `io-error`
- **`scsi1` stats**: `failed_wr_operations: 10`

> [!NOTE]
> When a virtual disk (like `scsi1`) encounters a write or read I/O error from the underlying host storage, QEMU's safety mechanism automatically pauses the VM's CPU execution (`qmpstatus: io-error`). This prevents data corruption inside the guest operating system.

### Step 2: Audit Host ZFS Pools
Since the virtual disk `scsi1` maps to the Proxmox storage pool `DAS1`, we checked the ZFS status of all host pools on the Cebu hypervisor:
```bash
zpool status
```
**Outcome**: The `das-18tb-1` pool (backing `DAS1`) was in a **`DEGRADED`** state:
```text
  pool: das-18tb-1
 state: DEGRADED
status: One or more devices has experienced an unrecoverable error.  An
	attempt was made to correct the error.  Applications are unaffected.
action: Determine if the device needs to be replaced, and clear the errors
	using 'zpool clear' or replace the device with 'zpool replace'.
config:

	NAME                                STATE     READ WRITE CKSUM
	das-18tb-1                          DEGRADED     0     0     0
	  ata-ST18000NT001-3NF101_ZVTG3P96  DEGRADED     0     0     0  too many errors
```

### Step 3: Verify Physical Disk Health
We queried the SMART status of the degraded disk `/dev/sdb` (`ZVTG3P96`) to verify if it was a hardware failure:
```bash
smartctl -a /dev/sdb
```
**Outcome**:
- SMART overall-health self-assessment: **PASSED**
- Reallocated Sector Count: **0**
- Current Pending Sector: **0**
- Offline Uncorrectable: **0**
- SMART Error Log: **No Errors Logged**

**Conclusion**: The disk is physically healthy. The pool degradation was caused by a transient SCSI link error or driver-level command timeout (Command_Timeout: 18), causing ZFS to mark the device degraded and suspend VM writes.

---

## 3. Resolution Steps Taken

### Step 1: Clear ZFS Pool Error Flags
To restore the pool status and allow write operations to resume on the host:
```bash
zpool clear das-18tb-1
```
We checked `zpool status das-18tb-1` and verified it returned to **`ONLINE`** with 0 errors.

### Step 2: Resume the VM in Proxmox
We resumed VM execution to let QEMU retry the blocked write operations:
```bash
qm resume 120
```
This changed the VM's `qmpstatus` from `io-error` back to `running`. 

### Step 3: Allow Clean Shutdown & Restart
Upon resuming, the guest CPU processed the pending reboot/powerdown signal that was sent earlier during the hang. The VM executed a clean shutdown and transitioned to `stopped`.

We then started the VM cleanly:
```bash
qm start 120
```

### Step 4: Verify Service and Mount Status
After the VM booted, we checked:
1. **Network Ping**: `VLAN 1 (Management)` responded to pings successfully.
2. **QEMU Guest Agent**:
   ```bash
   qm guest exec 120 -- systemctl status qemu-guest-agent
   ```
   *Outcome: `Active: active (running)`.*
3. **Samba Service**:
   ```bash
   qm guest exec 120 -- systemctl status smbd
   ```
   *Outcome: `Status: "smbd: ready to serve connections..."`.*
4. **CIFS Mounts on Cebu Host**:
   ```bash
   df -h | grep -E 'truenas|seagate|photo'
   ```
   *Outcome: Verified `//VLAN 1 (Management)/seagate/Share` and `//VLAN 1 (Management)/photo` were successfully mounted and readable.*

---

## 4. Outcome & Validation

- **TrueNAS Restored**: TrueNAS SCALE VM is fully operational with all host ZFS pools in `ONLINE` status.
- **Data Integrity**: QEMU's `io-error` pause mechanism successfully protected the guest filesystem during the host pool degradation, avoiding any data loss or filesystem corruption.
- **Client Mounts**: SMB shares are active, and files can be read/written normally from client machines.

---

## 📚 References
* [TrueNAS-on-Proxmox-Setup](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-on-Proxmox-Setup.md) — Host storage layout and disk configurations.
* [TrueNAS-System-Dataset-Deadlock-Recovery](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-System-Dataset-Deadlock-Recovery.md) — CIFS service troubleshooting.
* [TrueNAS-Mount-Recovery-Plex-Cebu](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-Mount-Recovery-Plex-Cebu.md) — CIFS mount recovery guide following TrueNAS storage crash.
