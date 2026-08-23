# 📂 Guide: Cloning Plex (Bulakan to Cebu) — SUCCESSFULLY COMPLETED

This guide documents the successful deployment, zero-downtime metadata cloning, database migration, and storage mapping for setting up your **second** Plex Media Server on the **Cebu** node while cloning from the primary **Bulakan** server.

---

## 🎯 Objective
Create a secondary, independent Plex instance (`plex-cebu`) on Cebu sharing the exact same posters, collections, and movie/TV watched history as the primary Bulakan server, without causing any downtime to the primary instance.

## 🛠️ Infrastructure Configuration
- **Primary Host**: Bulakan (`192.168.1.25`) -> Plex Container `104` (`192.168.1.54`)
- **Secondary Host**: Cebu (`192.168.1.26`) -> Plex Container `109` (`192.168.1.215`)
- **Active State**: **SUCCESSFULLY CLONED & ACTIVE**
- **Internal Listening Port**: `32400`

---

## 🔍 Troubleshooting & Resolution History

### Issue 1: Lost Session / Stalled Script
**Scenario**: User ran the initial setup script but "tabbed out," losing the active console window.
- **Troubleshooting Commands**:
    - `pct list`: Check if the container was created (Result: Not found, confirmed dead).
    - `ps aux | grep plex`: Check for running script processes in the background (Result: None).
- **Resolution**: Re-ran the Tteck community script in a clean Proxmox shell, specifying VMID `109` and unprivileged container defaults.

### Issue 2: Terminal Syntax Errors (`^[[200~`)
**Scenario**: Bracketed Paste Mode in certain browsers/consoles injected control characters during pastings.
- **Resolution**: Implemented custom python scripts (using `paramiko`) on the Windows client to run commands directly and robustly over SSH, fully avoiding interactive pasting issues.

### Issue 3: `chown: Invalid argument (22)` during Rsync
**Scenario**: Unprivileged container mount mappings caused ownership errors (`chown`) during standard `rsync`.
- **Resolution**: Allowed rsync to finish copying all raw file data (metadata, images, bundles), and then successfully executed a recursive `chown -R plex:plex` at the host-container level inside Cebu container `109`.

---

## 🚀 The Completed Zero-Downtime Clone Workflow

### Step 1: Bulk Metadata Sync (Phase 2)
Performed a live bulk metadata transfer from the Bulakan ZFS dataset to Cebu's folder while Bulakan remained online:
```bash
rsync -avzh --progress --exclude='Cache' --exclude='*.db*' /Bulakan-ZFS/subvol-104-disk-1/var/lib/plexmediaserver/Library/ root@192.168.1.215:/var/lib/plexmediaserver/Library/
```

### Step 2: Hot Database Backup & Transfer (Phase 3 & 4)
Performed an atomic hot SQLite snapshot of the active library database inside Bulakan's container using the host's `sqlite3` binary, then transferred it securely to Cebu over SCP:
```bash
# 1. Hot DB backup on Bulakan Host
sqlite3 '/Bulakan-ZFS/subvol-104-disk-1/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db' '.backup /Bulakan-ZFS/subvol-104-disk-1/tmp/plex_backup.db'

# 2. Transfer DB securely from Bulakan Host to Cebu Plex Databases folder
scp -o StrictHostKeyChecking=no /Bulakan-ZFS/subvol-104-disk-1/tmp/plex_backup.db root@192.168.1.215:'/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db'
```

### Step 3: Identity Reset & Permissions Fix (Phase 4)
Inside the Cebu Plex LXC (109), deleted the UUID identification file so it won't conflict with Bulakan in your Plex account, fixed ownership recursively to `plex:plex`, and started the service:
```bash
# Delete identity file
rm -f "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml"

# Fix permissions
chown -R plex:plex /var/lib/plexmediaserver/Library/

# Start service
systemctl start plexmediaserver
```

### Step 4: NAS & TrueNAS Media Storage Integration (Phase 5)
Connected the media directories from the Synology NAS (`PNAS` at `192.168.1.12`) and TrueNAS (`192.168.1.211`) to the Cebu Host and bind-mounted them to the Cebu LXC to match the exact library paths expected:
1. **Host CIFS Mounts** (Appended to `/etc/fstab` on Cebu Host):
   ```text
   //192.168.1.12/PlexMediaStorage /mnt/plex cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail 0 0
   //192.168.1.12/Seagate /mnt/plex1 cifs username=Plex,password=Media2023!@#,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail 0 0
   //192.168.1.211/seagate/Share /mnt/cebu-seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,nofail 0 0
   ```
2. **Mount Command**: Run `mount -a` on Cebu Host to activate.
3. **Container Bind Mounts** (Appended to `/etc/pve/lxc/109.conf` on Cebu Host):
   ```text
   mp0: /mnt/plex,mp=shared
   mp1: /mnt/plex1,mp=shared1
   mp2: /mnt/cebu-seagate,mp=/mnt/seagate
   ```
4. **Reboot Container**: Ran `pct reboot 109` to apply.

---

## 🔍 Verification & Operations Audit

- **Plex Service Status**: `active (running)`
- **Port 32400**: Successfully listening and receiving connections.
- **Internal Storage Directories**: Verified `/shared` (PlexMediaStorage), `/shared1` (Seagate), and `/mnt/seagate` (TrueNAS Share) are mounted, populated, and fully readable inside Cebu LXC 109.
- **Zero-Downtime**: The primary Bulakan Plex server experienced **0 seconds** of downtime during the entire cloning process.

---

## 🏁 Post-Installation Claims

1. Access the web dashboard at: **[http://192.168.1.215:32400/web](http://192.168.1.215:32400/web)**.
2. Sign in and follow the Plex instructions to **Claim the Server**.
3. Name it uniquely (e.g., `Pebu` or `Plex-Cebu`) to distinguish it from `plex` (Bulakan).
4. All media titles, watch history, posters, and collections are ready for immediate use!
