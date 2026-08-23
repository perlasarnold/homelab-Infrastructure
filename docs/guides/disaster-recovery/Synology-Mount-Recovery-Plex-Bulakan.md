# 🚨 Troubleshooting: Synology Mount Recovery & Optimization (Bulakan)

* **Date**: June 12, 2026
* **Objective**: Resolve Plex, Jellyfin, and Audiobookshelf connection issues to mounted Synology CIFS storage shares after a Bulakan host reboot.
* **Status**: 🟢 Resolved, Verified, & Optimized

---

## 1. Problem Statement

After the Proxmox **Bulakan** server (`VLAN 1 [Management]`) was rebooted, the Plex Media Server, Jellyfin, and Audiobookshelf containers could not connect to their mounted drives. Synology storage (`PNAS` at `VLAN 1 [Management]`) was verified online and accessible from other hosts on the network.

---

## 2. Investigation & Root Cause Analysis

### Step 1: Check Mount Status on the Host
We logged into the Bulakan Proxmox host and checked the disk mounts using `df -h`. 
**Outcome**: The Synology CIFS shares `/mnt/plex`, `/mnt/plex1`, `/mnt/pnas_photos`, and `/mnt/audiobooks` were completely absent from the mount table. The directories were empty.

### Step 2: Check Container Bind-Mount Configurations
We checked the Proxmox LXC configurations for Plex (`104.conf`), Jellyfin (`110.conf`), and Audiobookshelf (`100.conf`):
- Plex and Jellyfin map `/mnt/plex` -> `/shared` and `/mnt/plex1` -> `/shared1`.
- Audiobookshelf maps `/mnt/audiobooks` -> `/mnt/audiobooks`.

Since these directories were empty on the host when the containers started, they bind-mounted empty directories. Even if the network shares mounted later on the host, the active mount namespace of the running LXC containers would not show the files.

### Step 3: Identify Root Cause
During the early stage of the Bulakan boot process, systemd attempted to mount the CIFS shares from the Synology NAS. However, because the network interface (or network stack) was not fully initialized and online yet, the mounting attempts failed. 

The `/etc/fstab` configuration lacked options to handle network-dependent mounts gracefully, causing them to fail silently and not retry once the network became active.

---

## 3. Resolution & Optimization Steps Taken

### Step 1: Mount the Shares Natively
We verified network connectivity to the Synology NAS and successfully mounted the shares manually:
```bash
mount -a
```
This restored the files inside the `/mnt/plex`, `/mnt/plex1`, `/mnt/pnas_photos`, and `/mnt/audiobooks` directories on the Bulakan host.

### Step 2: Reboot LXC Containers
To refresh the bind mount namespaces inside the running containers, we rebooted the affected LXCs:
```bash
pct reboot 104
pct reboot 110
pct reboot 100
```
**Outcome**: Verified that files became visible inside `/shared`, `/shared1`, and `/mnt/audiobooks` inside the containers.

### Step 3: Optimize `/etc/fstab` for Auto-Mount Resilience
To ensure that future reboots do not experience this mount failure, we modified `/etc/fstab` on Bulakan. We appended `_netdev`, `nofail`, and `x-systemd.automount` to the option fields for the Synology CIFS shares.

#### Diff of `/etc/fstab`
```diff
- //VLAN 1 [Management]/PlexMediaStorage /mnt/plex cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777 0 0
- //VLAN 1 [Management]/Seagate /mnt/plex1 cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777 0 0
- //VLAN 1 [Management]/photo /mnt/pnas_photos cifs username=homelab-admin,password=Jiggu1ot!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm 0 0
- //VLAN 1 [Management]/Media/Audiobooks /mnt/audiobooks cifs username=homelab-admin,password=Jiggu1ot!@#,iocharset=utf8,vers=3.0,noperm 0 0
+ //VLAN 1 [Management]/PlexMediaStorage /mnt/plex cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,_netdev,nofail,x-systemd.automount 0 0
+ //VLAN 1 [Management]/Seagate /mnt/plex1 cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,_netdev,nofail,x-systemd.automount 0 0
+ //VLAN 1 [Management]/photo /mnt/pnas_photos cifs username=homelab-admin,password=Jiggu1ot!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,_netdev,nofail,x-systemd.automount 0 0
+ //VLAN 1 [Management]/Media/Audiobooks /mnt/audiobooks cifs username=homelab-admin,password=Jiggu1ot!@#,iocharset=utf8,vers=3.0,noperm,_netdev,nofail,x-systemd.automount 0 0
```

* Rationale:
  - `_netdev`: Informs the system that these mounts depend on network access, delaying mounting until network connectivity is active.
  - `nofail`: Prevents the boot process from blocking or failing if the NAS is temporarily offline.
  - `x-systemd.automount`: Automatically mounts the share the moment a container or process attempts to access the directory path, ensuring robust, on-demand connection.

### Step 4: Reload and Verify
We reloaded systemd and verified that the options parsed correctly:
```bash
systemctl daemon-reload
mount -a
```

---

## 4. Outcome & Validation

- **CIFS Storage Restored**: All Synology shares are mounted on Bulakan and will mount on-demand resiliently.
- **Plex, Jellyfin, and Audiobookshelf Restored**: All three containers have been restarted, and their media databases are fully functional and connected to `/shared` and `/mnt/audiobooks`.
- **System Service Checks**: Services `plexmediaserver`, `jellyfin`, and `audiobookshelf` report `active` status.

---

## 5. Recovery Automation Script

An automation script has been created to quickly diagnose and recover from this state in the future. The script automatically:
1. Pings the Synology NAS to verify network reachability.
2. Checks if host mount directories are online and mounts them if offline.
3. Reboots the affected media LXC containers (Plex, Jellyfin, Audiobookshelf) to refresh the bind mounts.
4. Verifies container readability and the active status of their respective systemd services.

### How to Run
From your local machine (with configured SSH keys to the Bulakan Proxmox host), execute the following in the repository:
```bash
python scripts/recover-bulakan-mounts.py
```

---

## 📚 References
* [TrueNAS-Mount-Recovery-Plex-Cebu](file:////opt/homelab-infrastructure/06-Guides/TrueNAS-Mount-Recovery-Plex-Cebu.md) — Reference guide for Cebu node mount issues.
* [Transmission-VPN-Proxmox-Setup](file:////opt/homelab-infrastructure/06-Guides/Transmission-VPN-Proxmox-Setup.md) — Documentation showing the network and mounting topologies on Bulakan.
