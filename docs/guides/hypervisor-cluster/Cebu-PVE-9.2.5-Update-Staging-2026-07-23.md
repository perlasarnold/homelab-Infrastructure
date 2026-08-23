# Cebu — Proxmox VE 9.2.5 Update

> **Date:** 2026-07-23  
> **Node:** Cebu (`192.168.1.26`)  
> **Objective:** Safely update Cebu from Proxmox VE 9.1.11 to 9.2.5,
> matching Bulakan, with verified rollback data and a controlled reboot.

## Starting state

- PVE Manager: `9.1.11`
- Proxmox VE meta-package: `9.1.0`
- Running kernel: `7.0.2-2-pve`
- Cluster: `Homelab-Net`, quorate with two votes
- `cebu-zfs`: healthy, 16.23% used
- PNAS: active
- Root filesystem: approximately 53 GiB free

Running guests included in the maintenance:

- VM 111 — `haos-17.3`
- CT 103 — `authentik`
- CT 105 — `nginxproxymanager`
- CT 109 — `plex`
- CT 401 — `pihole-cebu`
- CT 404 — `cloudflared-cebu`
- CT 416 — `jellyfin-cebu`

Guests 101, 112, 120, and 417 were stopped before maintenance and remained
stopped.

## Steps Taken

### 1. Staged and validated the package transaction

APT metadata was refreshed from Debian 13 Trixie, Proxmox
no-subscription, and Tailscale repositories. The simulation was saved at:

```text
/root/cebu-pve925-simulation.txt
```

The simulated transaction contained 114 upgrades, 4 new packages, no
removals, and 639 MB of downloads. A second
`--download-only --no-download` run proved the transaction was fully
available in Cebu's local APT cache.

### 2. Created and verified rollback data

The host configuration archive is:

```text
PNAS:backup/cebu-pre-pve925-20260723-133129.tar.gz
```

SHA-256:

```text
0b330e134e9137e907931cfe51cb15bf70e81991979e82d01247b8def4039664
```

The archive passed a `tar -tzf` readability check.

Fresh live snapshot backups were then created on PNAS for every running
guest:

| Guest | Archive | Compressed size |
|---|---|---:|
| CT 103 | `vzdump-lxc-103-2026_07_23-13_37_48.tar.zst` | 1.79 GB |
| CT 105 | `vzdump-lxc-105-2026_07_23-13_45_00.tar.zst` | 1.39 GB |
| CT 109 | `vzdump-lxc-109-2026_07_23-13_48_33.tar.zst` | 11.65 GB |
| VM 111 | `vzdump-qemu-111-2026_07_23-13_55_03.vma.zst` | 1.92 GB |
| CT 401 | `vzdump-lxc-401-2026_07_23-14_02_23.tar.zst` | 291 MB |
| CT 404 | `vzdump-lxc-404-2026_07_23-14_03_01.tar.zst` | 251 MB |
| CT 416 | `vzdump-lxc-416-2026_07_23-14_03_36.tar.zst` | 15.79 GB |

The backup task completed with `TASK OK`. A full `zstd -t` integrity pass
successfully decompressed all seven archives (53,044,549,632 bytes total).
Each archive has a `.protected` marker to prevent automatic pruning.

Plex and Jellyfin media bind mounts were intentionally excluded; those
media files remain on their separately mounted storage. The guest archives
contain the container systems, application configuration, databases, and
locally stored metadata.

### 3. Installed Proxmox VE 9.2.5

The cached transaction was installed non-interactively with existing
configuration files retained:

```bash
DEBIAN_FRONTEND=noninteractive \
NEEDRESTART_MODE=a \
apt-get -y --no-download \
  -o Dpkg::Options::=--force-confold dist-upgrade
```

The transaction completed successfully. `dpkg --audit`, `apt-get check`,
and a new update simulation were clean, with zero pending upgrades.
GRUB detected both the new and previous kernels.

### 4. Performed the controlled reboot

All seven running guests shut down gracefully; no forced stops were
required. Cebu rebooted and selected the new kernel. The seven maintenance
guests auto-started, while guests 101, 112, 120, and 417 stayed stopped.

### 5. Verified the resulting state

- PVE Manager: `9.2.5`
- Proxmox VE meta-package: `9.2.0`
- Running kernel: `7.0.14-6-pve`
- Cluster: both Bulakan and Cebu present; quorate
- PNAS: active, approximately 4.60 TiB free after backups
- `cebu-zfs`: healthy, approximately 16.21% used
- Home Assistant guest agent: responsive
- Authentik and Nginx Proxy Manager containers: system state `running`
- Plex, Pi-hole, Cloudflared, and Jellyfin services: `active`
- Package database: clean; no pending upgrades

## Outcome

Cebu now matches Bulakan at Proxmox VE 9.2.5 and kernel 7.0.14-6-pve.
The cluster, local ZFS storage, PNAS storage, and the seven intended
workloads were healthy after reboot.

## Rollback

- If a later kernel regression appears, select `7.0.2-2-pve` from GRUB.
- Restore host configuration from the verified host archive on PNAS.
- Restore an affected guest from its protected 2026-07-23 VZDump archive.
- Do not run `apt autoremove` until the retained older kernels are no
  longer needed for rollback.

## Follow-up

- Four failed systemd units remain for the intentionally retired DAS pools:
  `das-18tb-1`, `das-18tb-2`, `das-18tb-3`, and `das-6tb`. The active
  `cebu-zfs` pool is healthy. Remove the stale import definitions in a
  separate reviewed cleanup.
- The legacy `pve-no-subscription.list` duplicates the active
  `proxmox.sources` entry. It is harmless but causes duplicate-target APT
  warnings; clean it up separately after backing up the source files.
- Credentials were found embedded in existing guest description fields
  during diagnostics. Rotate the affected credentials and remove secrets
  from Proxmox descriptions; store them in the homelab's secret-management
  system instead.

## References

- [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [Proxmox Package Repositories](https://pve.proxmox.com/wiki/Package_Repositories)
- [Proxmox Overview](../02-Proxmox/Proxmox%20Overview.md)
