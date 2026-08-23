# 🚨 Troubleshooting: TrueNAS Mount Recovery for Plex Media Server (Cebu)

* **Date**: June 1, 2026
* **Objective**: Resolve Plex Media Server "Playback Error: Please check that the file exists and the necessary drive is mounted" on the Cebu node.
* **Status**: 🟢 Resolved & Verified

---

## 1. Problem Statement

When attempting to play media from the Cebu Plex Media Server (LXC Container `109`, IP `192.168.1.215`), playback failed for files stored on the TrueNAS SCALE share. The client presented the following error:
> Playback Error: Please check that the file exists and the necessary drive is mounted.

---

## 2. Investigation & Root Cause Analysis

### Step 1: Check Plex Container Mount Configuration
We logged into the Cebu Proxmox host (`192.168.1.26`) and reviewed the LXC container configuration for Plex (`109.conf`):
```text
mp0: /mnt/plex,mp=shared
mp1: /mnt/plex1,mp=shared1
mp2: /mnt/cebu-seagate,mp=/mnt/seagate
```
Inside the container, the TrueNAS share `/mnt/cebu-seagate` is mapped to `/mnt/seagate`.

### Step 2: Inspect Host Mount Status
We checked if `/mnt/cebu-seagate` was mounted on the Cebu host:
```bash
df -h | grep cebu-seagate
```
**Outcome**: The query returned no results. The mount directory `/mnt/cebu-seagate` was completely empty, and the share was not mounted on the host.

### Step 3: Identify Root Cause
On **May 28, 2026**, the TrueNAS SCALE VM (`120`) experienced a crash and a subsequent QEMU virtual disk I/O pause due to ZFS pool degradation.
Although the TrueNAS VM was successfully resumed and restarted:
1. The CIFS/Samba mount on the Cebu Proxmox host (`//192.168.1.211/seagate/Share`) did not automatically remount once TrueNAS came back online.
2. Other TrueNAS shares (e.g., `/mnt/truenas-photo` and `/mnt/truenas/seagate`) also remained unmounted.
3. This left the Plex bind mount pointing to an empty host directory, leading to the playback failures.

---

## 3. Resolution Steps Taken

### Step 1: Mount the TrueNAS Share on Cebu Host
We verified network connectivity to TrueNAS (`ping -c 3 192.168.1.211`) and mounted the directory manually to check for errors:
```bash
mount -v /mnt/cebu-seagate
```
**Outcome**: The mount succeeded. `df -h` verified the share was attached:
```text
//192.168.1.211/seagate/Share     16T  6.1T  9.5T  40% /mnt/cebu-seagate
```

### Step 2: Remount All Remaining Shares
To ensure all other services depending on TrueNAS had their shares restored, we executed:
```bash
mount -a
```
**Outcome**: Verified all TrueNAS mounts are now active:
- `/mnt/cebu-seagate` (Plex mount)
- `/mnt/truenas-photo` (Immich mount)
- `/mnt/truenas/seagate` (Arr stack mount)

### Step 3: Verify Container Accessibility
We verified that the files are now fully readable by the `plex` user inside LXC `109`:
```bash
pct exec 109 -- su -s /bin/bash -c 'ls -la /mnt/seagate/Movies /mnt/seagate/TV\ Shows' plex
```
**Outcome**: The command successfully listed all movie and TV show folders with appropriate read permissions.

---

## 4. Outcome & Validation

- **Storage Restored**: All TrueNAS CIFS mount points on the Cebu Proxmox host are fully active.
- **Plex Playback Restored**: The media files in `/mnt/seagate` are readable by the Plex Media Server container. Playback of files stored on the TrueNAS pool should now function normally without errors.

---

## 5. Recovery Automation Script

An automation script has been created to quickly diagnose and recover from this state in the future. The script automatically:
1. Audits all Cebu ZFS pools and clears any degraded/faulted flags (`zpool clear`).
2. Resumes VM 120 (TrueNAS) if it is in an `io-error` (paused) state, or starts it if stopped.
3. Pings TrueNAS until network accessibility is restored.
4. Audits and mounts any offline CIFS shares on the Cebu host (`mount -a` followed by manual mounts if needed).
5. Verifies container read permissions for the `plex` user inside LXC `109`.

### How to Run
From your local machine (with configured SSH keys to the Cebu Proxmox host), execute the following in the repository:
```bash
python scripts/recover-degraded-das.py
```

---

## 📚 References
* [TrueNAS-Storage-IO-Error-Pause-Troubleshooting](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-Storage-IO-Error-Pause-Troubleshooting.md) — Root cause of the initial storage crash.
* [Plex Cloning Guide](file:////opt/homelab-infrastructure/06-Guides/Plex%20Cloning%20Guide.md) — Infrastructure setup and directory bind-mapping details.
