# 🚨 Troubleshooting: TrueNAS & Synology Mount Recovery & Optimization (Cebu)

* **Date**: June 12, 2026
* **Objective**: Resolve Plex and Jellyfin connection issues to mounted TrueNAS and Synology CIFS storage shares after Cebu node boot.
* **Status**: 🟢 Resolved, Verified, & Optimized

---

## 1. Problem Statement

After the Proxmox **Cebu** server (`VLAN 1 [Management]`) booted, the Plex Media Server and Jellyfin-Cebu containers could not connect to their mounted drives. The CIFS storage hosts (TrueNAS VM at `VLAN 1 (Management)` and Synology NAS at `VLAN 1 [Management]`) were verified online and accessible from other network devices.

---

## 2. Investigation & Root Cause Analysis

### Step 1: Check Mount Status on the Cebu Host
We logged into the Cebu Proxmox host and checked the active disk mounts using `df -h`. 
**Outcome**: All fstab cifs shares `/mnt/cebu-seagate`, `/mnt/plex`, `/mnt/plex1`, `/mnt/truenas-photo`, and `/mnt/truenas/seagate` were unmounted and their host directories empty.

### Step 2: Check Container Bind-Mount Configurations
We checked the Proxmox LXC configurations for Plex (`109.conf`) and Jellyfin-Cebu (`416.conf`):
- Plex maps `/mnt/plex` -> `/shared`, `/mnt/plex1` -> `/shared1`, and `/mnt/cebu-seagate` -> `/mnt/seagate`.
- Jellyfin-Cebu maps `/mnt/cebu-seagate` -> `/mnt/seagate`.

Since the host mount directories were empty when the containers started, they bind-mounted empty directories. Even if the network shares mounted later on the host, the active mount namespace of the running LXC containers would not pick up the files.

### Step 3: Identify Root Cause
During the early boot phase of Cebu, systemd attempted to mount the CIFS shares from the local TrueNAS VM and the Synology NAS. Because the network interface was not fully initialized and online, the mounting attempts failed. 

The `/etc/fstab` configuration lacked options to handle network-dependent mounts gracefully, causing them to fail silently and not retry once the network became active.

---

## 3. Resolution & Optimization Steps Taken

### Step 1: Mount the Shares Natively
We verified network connectivity to the Synology NAS and TrueNAS and successfully mounted the shares manually:
```bash
mount -a
```
This restored the files inside `/mnt/cebu-seagate`, `/mnt/plex`, `/mnt/plex1`, `/mnt/truenas-photo`, and `/mnt/truenas/seagate` on the Cebu host.

### Step 2: Reboot LXC Containers
To refresh the bind mount namespaces inside the running containers, we rebooted the affected LXCs:
```bash
pct reboot 109
pct reboot 416
```
**Outcome**: Verified that files became visible inside `/shared`, `/shared1`, and `/mnt/seagate` inside the containers.

### Step 3: Optimize `/etc/fstab` for Auto-Mount Resilience
To ensure that future reboots do not experience this mount failure, we modified `/etc/fstab` on Cebu. We appended `_netdev`, `nofail`, and `x-systemd.automount` to the option fields for the CIFS shares.

#### Diff of `/etc/fstab`
```diff
- //VLAN 1 (Management)/seagate/Share /mnt/cebu-seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,nofail 0 0
- //VLAN 1 [Management]/PlexMediaStorage /mnt/plex cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail 0 0
- //VLAN 1 [Management]/Seagate /mnt/plex1 cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail 0 0
- //VLAN 1 (Management)/photo /mnt/truenas-photo cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,uid=100999,gid=100991,file_mode=0777,dir_mode=0777,nofail 0 0
- //VLAN 1 (Management)/seagate/Share /mnt/truenas/seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,uid=100000,gid=100000,file_mode=0775,dir_mode=0775,nofail 0 0
+ //VLAN 1 (Management)/seagate/Share /mnt/cebu-seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,nofail,_netdev,x-systemd.automount 0 0
+ //VLAN 1 [Management]/PlexMediaStorage /mnt/plex cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail,_netdev,x-systemd.automount 0 0
+ //VLAN 1 [Management]/Seagate /mnt/plex1 cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail,_netdev,x-systemd.automount 0 0
+ //VLAN 1 (Management)/photo /mnt/truenas-photo cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,uid=100999,gid=100991,file_mode=0777,dir_mode=0777,nofail,_netdev,x-systemd.automount 0 0
+ //VLAN 1 (Management)/seagate/Share /mnt/truenas/seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,uid=100000,gid=100000,file_mode=0775,dir_mode=0775,nofail,_netdev,x-systemd.automount 0 0
```

* Rationale:
  - `_netdev`: Informs the system that these mounts depend on network access, delaying mounting until network connectivity is active.
  - `nofail`: Prevents the boot process from blocking or failing if the NAS or VM is temporarily offline.
  - `x-systemd.automount`: Automatically mounts the share the moment a container or process attempts to access the directory path, ensuring robust, on-demand connection.

### Step 4: Reload and Verify
We reloaded systemd and verified that the options parsed correctly:
```bash
systemctl daemon-reload
mount -a
```

---

## 4. Outcome & Validation

- **CIFS Storage Restored**: All TrueNAS and Synology shares are mounted on Cebu and will mount on-demand resiliently.
- **Plex and Jellyfin-Cebu Restored**: Both containers have been restarted, and their media databases are fully functional and connected to `/shared`, `/shared1`, and `/mnt/seagate`.
- **System Service Checks**: Services `plexmediaserver` and `jellyfin` report `active` status.

---

## 5. Recovery Automation Script

An automation script has been created to quickly diagnose and recover from this state in the future. The script automatically:
1. Pings the TrueNAS VM and Synology NAS to verify network reachability.
2. Checks if host mount directories are online and mounts them if offline.
3. Reboots the affected media LXC containers (Plex, Jellyfin) to refresh the bind mounts.
4. Verifies container readability and the active status of their respective systemd services.

### How to Run
From your local machine (with configured SSH keys to the Cebu Proxmox host), execute the following in the repository:
```bash
python scripts/recover-cebu-mounts.py
```

---

## 📚 References
* [Synology-Mount-Recovery-Plex-Bulakan](file:////opt/homelab-infrastructure/06-Guides/Synology-Mount-Recovery-Plex-Bulakan.md) — Companion guide for Bulakan node mount issues.
* [TrueNAS-Mount-Recovery-Plex-Cebu](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-Mount-Recovery-Plex-Cebu.md) — Reference guide for Cebu node mount issues.
