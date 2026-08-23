# Cebu Immich Container Startup Troubleshooting

**Date:** 2026-06-01  
**Objective:** Diagnose and resolve startup failures with the Standby Immich LXC container (`112`) on the Proxmox **Cebu** hypervisor, and fix the subsequent infinite restart loop of the `immich-web` service.

---

## Issue Description

The Standby Immich LXC container (`112`) on the Proxmox **Cebu** hypervisor was in a `stopped` state. Attempting to start the container via Proxmox (`pct start 112`) failed with the following error:

```text
run_buffer: 569 Script exited with status 2
lxc_init: 1037 Failed to run lxc.hook.pre-start for container "112"
__lxc_start: 2208 Failed to initialize container "112"
startup for container '112' failed
```

After resolving the container startup issue, the `immich-web.service` inside the LXC container entered a crash-loop state (restarting every 15-20 seconds) and was failing to accept incoming connections on port `2283`.

---

## Steps Taken & Rationale

### 1. Investigating the LXC Container Hook Failure
- **Action:** Inspected `/etc/pve/lxc/112.conf` to view the mount points and device maps. Checked `/usr/share/lxc/config/common.conf.d/01-pve.conf` which defines the pre-start hook: `/usr/share/lxc/hooks/lxc-pve-prestart-hook`.
- **Action:** Verified that the mapped device nodes (`/dev/dri/card1` and `/dev/dri/renderD128`) existed on the Cebu host.
- **Action:** Checked the source paths for the mount points on the host:
  - `mp0: /mnt/truenas-photo/Immich,mp=/opt/immich/upload`
  - `mp1: /mnt/truenas-photo,mp=/mnt/truenas-photo`
- **Result:** The directory `/mnt/truenas-photo/Immich` was completely missing on the host. Because the mount point source path did not exist on the Cebu host, the LXC pre-start hook script failed with status code `2`, causing the container startup block.
- **Fix:** Created the missing directory `/mnt/truenas-photo/Immich` on the host, which is an SMB share mounted from TrueNAS (`//192.168.1.211/photo`).
- **Verification:** Successfully started container `112` using `pct start 112`.

### 2. Resolving the `immich-web` Service Crash Loop
- **Action:** Checked the status of internal services inside LXC `112`. Found `immich-web.service` constantly restarting (restart counter > 30).
- **Action:** Inspected the service definition at `/etc/systemd/system/immich-web.service` to find the log files. Standard output and error were routed to `/var/log/immich/web.log`.
- **Action:** Read `/var/log/immich/web.log` and identified the crash trace:
  ```text
  ERROR [Microservices:StorageService] Failed to read (/opt/immich/upload/encoded-video/.immich): Error: ENOENT: no such file or directory, open '/opt/immich/upload/encoded-video/.immich'
  microservices worker error: Error: Failed to read: "<UPLOAD_LOCATION>/encoded-video/.immich (/opt/immich/upload/encoded-video/.immich)
  ```
- **Rationale:** Immich performs system integrity folder checks at boot to verify that storage paths are correctly mounted and readable. It looks for a `.immich` sentinel file inside the subdirectories under `/opt/immich/upload/` (including `thumbs`, `upload`, `backups`, `library`, `profile`, and `encoded-video`). Because `/mnt/truenas-photo/Immich` was newly created and empty, these subdirectories and sentinel files did not exist.
- **Fix:** Created the required directories and sentinel files inside container `112`'s upload path as the `immich` user:
  ```bash
  su -s /bin/bash -c 'mkdir -p /opt/immich/upload/{thumbs,upload,backups,library,profile,encoded-video}' immich
  su -s /bin/bash -c 'touch /opt/immich/upload/{thumbs,upload,backups,library,profile,encoded-video}/.immich' immich
  ```

---

## Outcome

- **LXC Container Status:** The `immich` LXC container (`112`) starts successfully on boot.
- **Immich Services:** Both `immich-web.service` and `immich-ml.service` are running stable without any crashes.
- **Web App Health:** The Nest application successfully initialized, and the Immich server is listening on port `2283`.

---

## References

- [Cebu Immich LXC Config](file:///etc/pve/lxc/112.conf)
- [Immich System Integrity Folder Checks](https://docs.immich.app/administration/system-integrity#folder-checks)
- [Cebu LXC Setup Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-Immich-LXC-Setup-Guide.md)
