# Guide: Jellyfin Migration & Setup (Cebu Node)

This guide documents the process of deploying a secondary Jellyfin instance on the `cebu` node, mounting external SMB storage, and migrating all user data from the primary `bulakan` instance.

## 1. Infrastructure Overview

- **Host**: `cebu` (VLAN 1 [Management])
- **Container**: `jellyfin-cebu` (LXC 416)
- **IP Address**: `VLAN 1 (Management)`
- **Storage Source**: TrueNAS SCALE (`VLAN 1 (Management)`)
- **Storage Type**: SMB/CIFS

---

## 2. Storage Implementation

To ensure high performance and persistence, the SMB share is mounted at the host level and passed through to the container.

### Host Mount (Proxmox Cebu)
1. **Mount Point**: `/mnt/cebu-seagate`
2. **Credentials**: Stored securely in `/etc/samba/credentials-seagate`.
3. **Persistence**: Added to `/etc/fstab`:
   ```bash
   //VLAN 1 (Management)/seagate/Share /mnt/cebu-seagate cifs credentials=/etc/samba/credentials-seagate,iocharset=utf8,vers=3.0,nofail 0 0
   ```

### LXC Bind Mount
The host mount is mapped to the container using the Proxmox Container Toolkit:
```bash
pct set 416 -mp0 /mnt/cebu-seagate,mp=/mnt/seagate
```
*Internal Container Path*: `/mnt/seagate`

---

## 3. Data Migration (Bulakan to Cebu)

We migrated user accounts, watch history, and metadata from the existing Bulakan instance (ID 110) to the new Cebu instance (ID 416).

### Directories Migrated
- `/var/lib/jellyfin`: Database, users, metadata, and cache.
- `/etc/jellyfin`: System configuration and server settings.

### Migration Workflow
1. **Stop Services**: Both Jellyfin instances were stopped to prevent database corruption.
2. **Mount Filesystems**: Used `pct mount` on both hosts to access the container root filesystems.
3. **Rsync Transfer**: Synchronized data between hosts over the local network.
4. **Permission Fix**: Reset ownership to `jellyfin:jellyfin` inside the new container.
5. **Restart**: Started the service on both nodes.

---

## 4. Library Configuration

After migration, the library paths were updated in the Jellyfin Web UI to point to the new mount points.

- **Movies**: `/mnt/seagate/Movies`
- **TV Shows**: `/mnt/seagate/TV Shows`

*Note: The migration preserved all user accounts and watch history, so users can log in with their existing credentials.*

---

## 5. Verification

- **Connectivity**: Service is accessible at `http://VLAN 1 (Management):8096`.
- **Storage**: Confirmed ~8GB of metadata was successfully transferred.
- **Playback**: Verified that files from the TrueNAS SMB share play correctly in the new container.

---

## Related Documentation
- [[05-Services/Services Index]] — Master list of all lab services.
- [[06-Guides/TrueNAS-on-Proxmox-Setup]] — Details on the TrueNAS server hosting the media.
- [[06-Guides/TrueNAS-Scheduled-Tasks-Guide]] — Automating backups and syncs for this data.
