# Cebu TrueNAS DAS Safe Shutdown

**Date:** 2026-07-22  
**Objective:** Safely take the failed DAS enclosure and its TrueNAS-backed storage offline without allowing Proxmox workloads to write to missing storage paths.

## Problem

TrueNAS SCALE VM 120 used three virtual disks stored on the Proxmox host pools `das-18tb-1`, `das-18tb-2`, and `das-18tb-3`. A fourth DAS pool, `das-6tb`, provided the `DAS4-Backups` directory storage.

The DAS was experiencing failed or blocked I/O. Pool status queries stalled, and clean exports of `das-18tb-3` and `das-6tb` entered uninterruptible kernel I/O waits. This prevented Cebu from completing a normal software reboot after the enclosure was powered off.

## Steps Taken

### 1. Stop TrueNAS storage consumers

The TrueNAS-dependent workloads were stopped before the storage layer:

- Plex LXC 109
- Jellyfin LXC 416
- Immich LXC 112 was already stopped
- Arr Stack LXC 417 was already stopped

This prevented new application writes while TrueNAS was shutting down.

### 2. Shut down TrueNAS cleanly

TrueNAS VM 120 completed a normal ACPI shutdown. Its `onboot` setting was changed from `1` to `0` so it cannot start while its virtual disks are unavailable.

A recovery copy of its configuration was saved on Cebu at:

```text
/root/120.conf.pre-das-shutdown-20260722
```

### 3. Export the Proxmox DAS pools

The following pools exported cleanly:

- `das-18tb-1`
- `das-18tb-2`

The following exports blocked in uninterruptible I/O because of the failed DAS path:

- `das-18tb-3`
- `das-6tb`

No forced ZFS export was attempted. With TrueNAS and its consumers stopped, the DAS enclosure was powered off.

### 4. Recover Cebu from blocked I/O

A normal `systemctl reboot` was initiated. Cebu stopped accepting SSH connections but remained reachable by ICMP because the kernel could not complete shutdown while the two ZFS export processes were blocked in I/O.

Cebu was physically powered off, left off for approximately ten seconds, and powered back on while the DAS remained off.

### 5. Prevent writes to missing DAS paths

After reboot, the four ZFS storage entries were inactive. However, `DAS4-Backups` initially appeared active because `/das-6tb` existed as an ordinary directory on Cebu's root filesystem. Leaving it active could have redirected scheduled backups onto the 68 GB Proxmox root volume.

The storage configuration was backed up to:

```text
/root/storage.cfg.pre-das-off-20260722
```

The following Proxmox storage definitions were disabled but retained:

- `DAS1`
- `DAS2`
- `DAS3`
- `DAS4`
- `DAS4-Backups`

Immich LXC 112 autostart was also disabled because its two bind mounts depend on `/mnt/truenas-photo`. Its configuration backup is:

```text
/root/112.conf.pre-das-off-20260722
```

## Outcome

- Cebu booted and rejoined the two-node `Homelab-Net` cluster with quorum.
- Only the internal `cebu-zfs` pool is imported from local ZFS storage.
- No blocked `zpool export` processes remain.
- No DAS filesystems are mounted.
- TrueNAS VM 120 is stopped with autostart disabled.
- Immich LXC 112 is stopped with autostart disabled.
- All DAS-related Proxmox storage entries are disabled.
- Cebu's root filesystem is healthy at 19% utilization.
- Plex and Jellyfin restarted and can continue using their Synology-backed paths.
- The DAS remains physically powered off.

Expected failed systemd units can still appear for the absent ZFS pools and TrueNAS CIFS mounts. Do not re-enable the DAS storage definitions or start TrueNAS until the enclosure and disks have been assessed.

## Rollback / Reattachment Preconditions

1. Keep TrueNAS VM 120 and Immich LXC 112 stopped.
2. Confirm the DAS enclosure, bridge/controller, cables, power supply, and individual disks are healthy.
3. Power on the DAS and verify stable disk identities before importing any pool.
4. Import and validate one Proxmox pool at a time.
5. Re-enable the corresponding Proxmox storage only after its mountpoint is verified as a real ZFS filesystem.
6. Start TrueNAS only after all required virtual disks are present.
7. Re-enable workload autostart only after their storage mounts are verified.

## References

- [[TrueNAS-on-Proxmox-Setup]]
- [[TrueNAS-Storage-IO-Error-Pause-Troubleshooting]]
- [[TrueNAS-DAS2-System-Dataset-Space-Deadlock]]
- [[TrueNAS-Mount-Recovery-Plex-Cebu]]

