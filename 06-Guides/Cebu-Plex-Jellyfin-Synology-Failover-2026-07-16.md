# Cebu Plex and Jellyfin Synology Failover

**Date:** July 16, 2026  
**Objective:** Restore Plex and Jellyfin on the Cebu Proxmox host without importing or writing to the damaged TrueNAS DAS pools.

## Problem

TrueNAS VM 120 could not import `DAS1-18TB`, leaving its `seagate/Share` SMB path unavailable. Plex container 109 and Jellyfin container 416 depended on the Cebu host mount `/mnt/cebu-seagate`, so their media path `/mnt/seagate` was unavailable.

The original Synology NAS at `192.168.1.12` remained healthy. Its `Seagate` share was already mounted on Cebu at `/mnt/plex1`, with the media collection beneath `/mnt/plex1/Share`.

## Steps Taken

1. Verified that `192.168.1.12` responded to ping and accepted SMB connections on TCP 445.
2. Verified that `/mnt/plex1/Share/Movies` was readable on Cebu.
3. Backed up the LXC configurations to:
   - `/root/recovery-backups/20260716-synology-failover/109.conf.before`
   - `/root/recovery-backups/20260716-synology-failover/416.conf.before`
4. Replaced only the affected container bind mounts, preserving the in-container path and making the media read-only:

   ```bash
   pct set 109 -mp2 /mnt/plex1/Share,mp=/mnt/seagate,ro=1
   pct set 416 -mp0 /mnt/plex1/Share,mp=/mnt/seagate,ro=1
   ```

5. Started both containers:

   ```bash
   pct start 109
   pct start 416
   ```

## Outcome

- Plex container 109: running
- Jellyfin container 416: running
- `plexmediaserver.service`: active
- `jellyfin.service`: active
- Both containers can read media below `/mnt/seagate/Movies`
- Plex TCP 32400: open; HTTP endpoint responding
- Jellyfin TCP 8096: open; HTTP endpoint responding
- No TrueNAS data pool was imported read-write, cleared, or modified during this failover.

The media source is temporarily the Synology `Seagate/Share` directory. Application metadata remains on the containers' local `cebu-zfs` root disks.

## Rollback

After TrueNAS storage is repaired and `/mnt/cebu-seagate` is confirmed mounted and readable, restore the original bind mounts:

```bash
pct stop 109
pct stop 416
pct set 109 -mp2 /mnt/cebu-seagate,mp=/mnt/seagate
pct set 416 -mp0 /mnt/cebu-seagate,mp=/mnt/seagate
pct start 109
pct start 416
```

Alternatively, restore the backed-up LXC configuration files during a maintenance window.

## References

- `06-Guides/TrueNAS-Storage-IO-Error-Pause-Troubleshooting.md`
- `06-Guides/TrueNAS-Synology-Mount-Recovery-Cebu.md`
- `06-Guides/Cebu-Jellyfin-Setup-Guide.md`
