# OptiPlex Proxmox Direct-Attached Storage Plan

- **Date:** 2026-07-22
- **Objective:** Plan storage for a new Dell OptiPlex SFF Proxmox host using one NVMe SSD for Proxmox VE, one 1 TB SSD for VM/LXC disks, and one 18 TB HDD shared directly with Plex, Jellyfin, Immich, and the Arr/download stack without TrueNAS.
- **Status:** Implementation in progress on `Dapitan` (`VLAN 1 [MGMT]`). Base storage was created and verified on 2026-07-22, and Dapitan joined the three-node `Homelab-Net` cluster on 2026-07-23. Extended disk tests, BIOS update, permissions, workload deployment, and data migration remain pending.

## Dapitan Implementation Record

### Verified Hardware

| Component | Installed hardware | Identifier / health |
|---|---|---|
| Host | Dell OptiPlex 7050 | Service tag `F03PGM2`; BIOS `1.6.5` dated 2017-09-09 |
| CPU | Intel Core i5-7500 | 4 cores; VT-x and IOMMU active |
| Memory | 40 GiB | 37 GiB available at idle |
| Integrated GPU | Intel HD Graphics 630 | `i915` loaded; preferred for media transcoding |
| Discrete GPU | NVIDIA GeForce GT 1030 | `nouveau` loaded; no NVENC encoder |
| Network | Intel I219-LM | `e1000e`; bridge `vmbr0`; static IP `VLAN 1 [MGMT]/24` |
| OS disk | Samsung PM961 NVMe 256 GB | Serial `S364NX0J619690`; SMART passed; 3% used |
| VM/LXC SSD | Samsung 870 QVO 1 TB | Serial `S5VSNJ0R409313V`; SMART passed; 25,294 hours; extended test pending |
| Bulk HDD | Seagate IronWolf Pro 18 TB | Serial `ZVTFEZ44`; SMART passed; 14,685 hours; extended test pending |

### Proxmox and Repository State

- Hostname: `Dapitan`
- Proxmox VE: `9.2`
- PVE manager: `9.2.5`
- Installed and running kernel: `7.0.14-6-pve`
- Official `pve-no-subscription` repository: enabled
- Enterprise PVE repository: disabled because the node has no subscription
- Enterprise Ceph repository: disabled because the node has no subscription and does not use Ceph
- Test repository: disabled
- Repository backups: `/root/dapitan-setup-backups/2026-07-22-apt/`
- Failed systemd units after configuration: none

### Legacy Pool Inspection and Authorized Erasure

Both reused data disks contained old ZFS pools. They were inspected read-only before erasure:

- `Matimbo-ZFS` on the Samsung SSD was online and contained approximately 322 GB of logical VM/LXC data.
- `das-18tb-3` on the Seagate HDD contained a 15.6 TiB reserved TrueNAS zvol, but only approximately 75 MB was logically written. The pool recorded legacy permanent corruption.

The owner explicitly authorized permanent erasure of both old pools on 2026-07-22. Disk identities were verified by model, serial, and `/dev/disk/by-id` immediately before removing the GPT and ZFS signatures. The NVMe OS disk and USB installer were excluded.

### Implemented Storage

| Proxmox/ZFS object | Device or mount point | Configuration |
|---|---|---|
| `local` | NVMe `/var/lib/vz` | ISO images, templates, imports, and optional local backups |
| `local-lvm` | NVMe LVM thin pool | Empty installer-created guest storage; not the preferred destination |
| `vm-fast` | Samsung 870 QVO 1 TB | ZFS, `ashift=12`, Zstandard compression, `atime=off`, POSIX ACLs, sparse allocation, autotrim enabled |
| `vm-fast/vmdata` | Proxmox storage ID `vm-fast` | VM images and LXC root filesystems |
| `bulk18/media-data` | `/mnt/bindmounts/media-data` | 1 MiB record size |
| `bulk18/immich-data` | `/mnt/bindmounts/immich-data` | 1 MiB record size |
| `bulk18/shared` | `/mnt/bindmounts/shared` | 128 KiB record size |

Created non-Immich bulk layout, completed on 2026-07-23:

```text
/mnt/bindmounts/media-data/
├── downloads/
│   ├── incomplete/
│   └── complete/
│       ├── movies/
│       └── tv/
└── library/
    ├── movies/
    └── tv/

/mnt/bindmounts/shared/
├── external-photos/
├── documents/
├── exports/
└── staging/
```

Validation completed:

- Both pools are `ONLINE`.
- Both pools report zero read, write, and checksum errors.
- `vm-fast` reports approximately 899 GiB available.
- `bulk18` reports approximately 16.2 TiB available.
- All three bulk datasets mounted with `rw`, `noatime`, extended attributes, and POSIX ACL support.
- Write, checksum-read, and deletion smoke tests passed on all bulk datasets.
- Every implemented non-Immich directory is `root:root` with mode `0755`;
  ownership and application ACLs remain intentionally pending until the
  final unprivileged-LXC UID/GID mappings are known.
- `immich-data` remains empty so Immich can create and own its managed
  `upload`, `library`, `thumbs`, `encoded-video`, `profile`, and `backups`
  directories during deployment.
- `bulk18` was intentionally not added as general Proxmox VM/LXC storage.
- The temporary setup SSH key was removed after the persistent Dapitan-specific key was verified.

### Pending Maintenance Gates

1. Allow the extended SMART tests to finish:
   - Samsung SSD: expected completion around 2026-07-22 23:15 PDT.
   - Seagate HDD: expected completion around 2026-07-24 00:20 PDT.
2. Read and record both final self-test logs.
3. Update the OptiPlex BIOS during a separate physical maintenance window. The installed BIOS is `1.6.5`; Dell requires upgrading to bridge release `1.7.6` before later releases.
4. Verify thermals. The Samsung SSD measured 52°C during initial inspection.
5. Configure dataset ownership and ACLs only after the final LXC UID/GID mappings are known.
6. Deploy workloads and add least-privilege bind mounts.
7. Complete workload data migration.

### Bulakan Datacenter Join Preflight and Outcome

Read-only checks were completed on 2026-07-23 before attempting to add Dapitan to the existing `Homelab-Net` cluster.

| Check | Result |
|---|---|
| Existing cluster before join | `Homelab-Net`, nodes `Bulakan` (`VLAN 1 [MGMT]`) and `cebu` (`VLAN 1 [MGMT]`) |
| Final cluster health | Quorate; three of three expected votes online, with quorum of two |
| Bulakan version | PVE manager `9.2.5`, kernel `7.0.14-6-pve` |
| Cebu version | PVE manager `9.2.5`, kernel `7.0.14-6-pve` |
| Dapitan version | PVE manager `9.2.5`, kernel `7.0.14-6-pve` |
| Dapitan guests | None; satisfies the empty-node join requirement |
| Storage ID collision | None for `vm-fast`; the cluster does not currently define that ID |
| Dapitan pools | `vm-fast` and `bulk18` both remained online with zero ZFS errors |

The join was initially deferred while Bulakan and Cebu were upgraded. After
both existing nodes reached PVE 9.2.5 and verified backups were available,
Dapitan joined successfully on 2026-07-23. Its `vm-fast` storage was
restored as Dapitan-only storage, Dapitan was added to the shared PNAS node
list, and `bulk18` remained host-managed.

See [Dapitan Homelab-Net Cluster Join](./Dapitan-Homelab-Net-Cluster-Join-2026-07-23.md)
for the exact rollback hashes, join command, storage merge, and validation
results.

Bulakan's earlier `pve8to9 --full` findings are retained in the dedicated
upgrade guide. Those gates were resolved before Dapitan was admitted.

Completed continuation sequence:

1. Protected the requested running Bulakan guests and archived the host and
   cluster configuration.
2. Upgraded and validated Bulakan at PVE 9.2.5.
3. Updated and validated Cebu at PVE 9.2.5.
4. Created verified pre-join Dapitan and Homelab-Net rollback archives.
5. Joined Dapitan to `VLAN 1 [MGMT]`.
6. Restored `vm-fast` as Dapitan-only storage and added Dapitan to PNAS.
7. Verified three-node quorum, certificates, ZFS pools, mounts, services,
   and the unchanged Bulakan/Cebu guest states.

### Bulakan Pre-Upgrade Backup Outcome

Bulakan's pre-upgrade backup completed successfully on 2026-07-23:

- The checksummed host and cluster configuration archive is stored on PNAS as `bulakan-host-config-20260723-074555.tar.gz`.
- Every guest that was running received a fresh protected backup: CTs 100, 104, 108, 110, 113, 115, 301, and 304; VMs 203 and 204.
- Metadata-level readability checks passed for every requested running-guest archive.
- VM 204 produced a protected 471.28 GB archive and completed without stopping Immich.
- The owner requested that stopped VM 202, CT 302, VM 305, and other stopped guests be skipped. Protected archives that had already completed for stopped CTs 102, 106, 107, and 118 were retained.
- PNAS remained online and the final targeted backup task exited successfully.

See [Bulakan Proxmox VE 8 to VE 9 Upgrade Guide](./Bulakan-Proxmox-VE8-to-VE9-Upgrade.md) for the detailed backup inventory and upgrade gates.

### Dapitan PNAS Attachment

Bulakan's `PNAS` CIFS storage definition was first tested on standalone
Dapitan and then merged into the cluster-wide configuration after the join.

Final cluster definition:

```text
cifs: PNAS
        path /mnt/pve/PNAS
        server VLAN 1 [MGMT-NAS]
        share proxmox
        content snippets,iso,rootdir,vztmpl,images,backup
        nodes cebu,Bulakan,Dapitan
        prune-backups keep-all=1
        username proxmox
```

Implementation and verification:

- Dapitan can reach `VLAN 1 [MGMT-NAS]` on TCP port 445.
- `cifs-utils` is already installed.
- The existing Synology account `proxmox` was reused. Its current password was entered locally on Dapitan so it was never exposed in chat or shell history.
- `PNAS` is active at `/mnt/pve/PNAS` over SMB 3.1.1 with read/write mount options.
- Dapitan can enumerate the existing Proxmox backup archives through `pvesm`.
- An isolated create, read, and delete test succeeded without touching any backup archive.
- PNAS reported approximately 4.60 TiB free after the pre-join archives.
- Dapitan's `vm-fast` and `bulk18` pools remained healthy, and no systemd units were failed.
- PNAS was active from all three cluster nodes after the join.

The pre-change standalone storage configuration remains under
`/root/dapitan-setup-backups/2026-07-23-pnas/`. The cluster-join rollback
archives and hashes are recorded in the dedicated join guide.

## Executive Decision

Use Proxmox as the owner of all three physical disks:

1. Install Proxmox VE on the NVMe using the default ext4/LVM layout, but reserve it for the host, ISO images, templates, and snippets.
2. Create a single-disk ZFS pool named `vm-fast` on the 1 TB SSD for VM and LXC root disks.
3. Create a separate single-disk ZFS pool named `bulk18` on the 18 TB HDD.
4. Create purpose-specific ZFS datasets on `bulk18`, mount them below `/mnt/bindmounts`, and bind-mount only the needed paths into each LXC.
5. Keep application databases, metadata, and configuration on `vm-fast`. Put large media, Immich assets, and downloads on `bulk18`.
6. Give Plex and Jellyfin read-only access to the media library. Give only the Arr/download stack write access to media and downloads. Give Immich write access only to its managed storage.

Do **not** pass the raw 18 TB disk to a VM or LXC, and do not mount the same block device independently in multiple guests. The Proxmox host should mount the filesystem once and share directories through LXC bind mounts.

## Capacity Gate

An advertised 18 TB disk provides approximately **16.37 TiB** before filesystem overhead. A practical target is to keep at least 15–20% free, so planned steady-state usage should remain below approximately **13.1–13.9 TiB**.

The existing Cebu documentation records the Immich photo dataset at approximately **9.45 TiB**. If that entire dataset is migrated, only approximately **3.6–4.4 TiB** remains within the safe operating target for:

- Movies and TV
- Downloads and import staging
- Immich growth
- ZFS snapshots
- Other shared files

Before buying or formatting the HDD, record the current used sizes of every source:

```bash
du -sh /mnt/truenas-photo
du -sh /mnt/cebu-seagate
du -sh /mnt/truenas/seagate/share/downloads
zfs list -o name,used,refer,avail,mountpoint
```

Proceed with one 18 TB disk only if:

```text
current data + 24 months expected growth + snapshot allowance <= 13 TiB
```

If the result exceeds 13 TiB, choose one of these alternatives:

1. Use the 18 TB disk only for media and keep Immich on separately protected storage.
2. Install a second large HDD and use a ZFS mirror for approximately 16.37 TiB raw usable capacity with disk-failure tolerance.
3. Use two independent disks with separate backup responsibilities, understanding that this is capacity expansion rather than redundancy.
4. Select a chassis with more drive bays instead of forcing the design into the OptiPlex SFF.

## Proposed Storage Layout

| Physical device | Proxmox storage | Filesystem | Purpose |
|---|---|---|---|
| NVMe SSD | `local` | Proxmox installer ext4/LVM | PVE OS, logs, ISO images, templates, snippets |
| 1 TB SATA SSD | `vm-fast` | Single-disk ZFS | VM/LXC root disks, databases, application metadata, configuration |
| 18 TB HDD | `bulk18` | Single-disk ZFS | Media, downloads, Immich assets, shared bulk files |

Do not store the only Proxmox backups on either the NVMe or the 1 TB SSD. A failure of this host would otherwise remove both the workload and its backup.

### Why ZFS on the Two Data Disks

ZFS supplies checksums, snapshots, compression, scrubs, and clear pool-health reporting. On a single disk, ZFS can **detect** corruption but cannot repair it because no redundant copy exists. ZFS snapshots also remain on the same disk and are not backups.

Do not add a special cache, L2ARC, or SLOG device to this small server. The workload does not justify the added complexity, and the available SSD is more valuable as primary application storage.

## Bulk Dataset Layout

Use a shallow layout that keeps downloads and the final media library in the same ZFS dataset. This permits hardlinks and atomic imports for Sonarr/Radarr.

```text
/mnt/bindmounts/
├── media-data/                   # bulk18/media-data
│   ├── downloads/
│   │   ├── incomplete/
│   │   └── complete/
│   │       ├── movies/
│   │       └── tv/
│   └── library/
│       ├── movies/
│       └── tv/
├── immich-data/                  # bulk18/immich-data
│   ├── backups/
│   ├── encoded-video/
│   ├── library/
│   ├── profile/
│   ├── thumbs/
│   └── upload/
└── shared/                       # bulk18/shared
    ├── external-photos/
    ├── documents/
    ├── exports/
    └── staging/
```

Do not create separate ZFS child datasets for `downloads` and `library`. Hardlinks cannot cross dataset/filesystem boundaries; separating them would cause imports to become full copies.

The full non-Immich `media-data` and `shared` hierarchy was created and
verified on 2026-07-23. The `immich-data` child directories shown above are
the expected application layout; allow Immich to create and manage them.
Do not manually move, rename, or delete files inside Immich's managed asset
tree.

To create any missing non-Immich directories:

```bash
install -d -m 0755 \
  /mnt/bindmounts/media-data/downloads/incomplete \
  /mnt/bindmounts/media-data/downloads/complete/movies \
  /mnt/bindmounts/media-data/downloads/complete/tv \
  /mnt/bindmounts/media-data/library/movies \
  /mnt/bindmounts/media-data/library/tv \
  /mnt/bindmounts/shared/external-photos \
  /mnt/bindmounts/shared/documents \
  /mnt/bindmounts/shared/exports \
  /mnt/bindmounts/shared/staging
```

Suggested dataset properties:

| Dataset | `recordsize` | Access pattern |
|---|---:|---|
| `bulk18/media-data` | `1M` | Large sequential media and download files |
| `bulk18/immich-data` | `1M` | Photos, videos, thumbnails, and encoded video |
| `bulk18/shared` | `128K` | Mixed general-purpose files |

Suggested common properties:

```text
compression=zstd
atime=off
xattr=sa
acltype=posixacl
```

Compression does little for already-compressed video and photos but is safe and can help metadata and other compressible files.

## Application Placement

| Service | Root disk / database | Bulk mount | Access |
|---|---|---|---|
| Plex | `vm-fast`; keep Plex database and metadata on SSD | `/data/library` | Read-only |
| Jellyfin | `vm-fast`; keep database, cache, and metadata on SSD | `/data/library` | Read-only |
| Immich | `vm-fast`; keep PostgreSQL on SSD | `/opt/immich/upload` or the path required by the installed package | Read/write to `immich-data` only |
| Arr stack | `vm-fast`; keep Docker configs on SSD | `/data` | Read/write to all of `media-data` |
| Transmission/download client | `vm-fast`; keep config on SSD | `/data/downloads` | Read/write |
| Authentik | `vm-fast` | None | None |
| Nginx Proxy Manager | `vm-fast` | None | None |
| Pi-hole | `vm-fast` | None | None |
| Cloudflared | `vm-fast` | None | None |

Immich's PostgreSQL database must remain on local SSD-backed storage. Its large asset tree can live on the HDD. Plex and Jellyfin metadata should also stay on SSD so library browsing does not depend on random HDD I/O.

## LXC Bind-Mount Policy

### Canonical Mount Map

| Workload | Host source | Container destination | Mode |
|---|---|---|---|
| Arr stack | `/mnt/bindmounts/media-data` | `/data` | Read/write |
| Download client | `/mnt/bindmounts/media-data/downloads` | `/data/downloads` | Read/write |
| Plex | `/mnt/bindmounts/media-data/library` | `/data/library` | Read-only |
| Jellyfin | `/mnt/bindmounts/media-data/library` | `/data/library` | Read-only |
| Immich managed storage | `/mnt/bindmounts/immich-data` | Installation-specific Immich upload/data path | Read/write |
| Immich external library | `/mnt/bindmounts/shared/external-photos` | `/mnt/external-photos` | Read-only |

Keep the same `/data` path convention in the Arr and download applications:

```text
Download client:
  incomplete downloads -> /data/downloads/incomplete
  completed movies     -> /data/downloads/complete/movies
  completed TV         -> /data/downloads/complete/tv

Radarr:
  root folder          -> /data/library/movies

Sonarr:
  root folder          -> /data/library/tv

Plex and Jellyfin:
  movies               -> /data/library/movies
  TV                   -> /data/library/tv
```

### Execution Commands

Stop each affected container before changing its mount points. Substitute the authoritative Dapitan CT IDs; do not reuse Cebu IDs without checking.

```bash
# Record the final IDs before applying mounts
pct list

# Plex: library is read-only
pct set <PLEX_CTID> -mp0 /mnt/bindmounts/media-data/library,mp=/data/library,ro=1

# Jellyfin: library is read-only
pct set <JELLYFIN_CTID> -mp0 /mnt/bindmounts/media-data/library,mp=/data/library,ro=1

# Arr stack: one common /data tree preserves hardlinks
pct set <ARR_CTID> -mp0 /mnt/bindmounts/media-data,mp=/data

# Download client
pct set <DOWNLOAD_CTID> -mp0 /mnt/bindmounts/media-data/downloads,mp=/data/downloads

# Confirm the correct internal Immich path from the installed package first
pct set <IMMICH_CTID> -mp0 /mnt/bindmounts/immich-data,mp=<IMMICH_DATA_PATH>

# Optional Immich external photo library; keep it read-only
pct set <IMMICH_CTID> -mp1 /mnt/bindmounts/shared/external-photos,mp=/mnt/external-photos,ro=1
```

Do not configure `/mnt/bindmounts/immich-data` as an Immich external library. Doing so can recursively scan Immich's own managed assets. Only add `/mnt/external-photos` as an external-library import path.

After applying the mounts, start each container and verify:

```bash
pct config <PLEX_CTID> | grep '^mp'
pct config <JELLYFIN_CTID> | grep '^mp'
pct config <ARR_CTID> | grep '^mp'
pct config <DOWNLOAD_CTID> | grep '^mp'
pct config <IMMICH_CTID> | grep '^mp'

pct exec <PLEX_CTID> -- findmnt /data/library
pct exec <JELLYFIN_CTID> -- findmnt /data/library
pct exec <ARR_CTID> -- findmnt /data
pct exec <DOWNLOAD_CTID> -- findmnt /data/downloads
pct exec <IMMICH_CTID> -- findmnt <IMMICH_DATA_PATH>
```

Verification requirements:

1. Arr and the download client can create files in their assigned paths.
2. Plex and Jellyfin can read media but cannot create, rename, or delete files.
3. Immich passes its storage-integrity startup checks.
4. Immich can read but not modify `/mnt/external-photos`.
5. A test completed download and imported library file have matching inode numbers:

   ```bash
   pct exec <ARR_CTID> -- stat \
     /data/downloads/complete/movies/<TEST_FILE> \
     /data/library/movies/<TEST_FILE>
   ```

   Matching inode numbers confirm a hardlink rather than a second full copy.

Proxmox does not include bind-mounted content in `vzdump` backups. The container configuration is preserved, but files on `bulk18` require their own backup workflow.

## Permissions Model

Keep the LXCs unprivileged.

For the media/download stack:

1. Use the same application UID/GID in the Arr and download containers, preferably UID/GID `1000:1000`.
2. With the default unprivileged LXC mapping, container UID/GID `1000:1000` normally maps to host UID/GID `101000:101000`.
3. Verify the actual mappings in `/etc/subuid`, `/etc/subgid`, and each CT configuration before applying ownership.
4. Use a shared media group and setgid directories so newly created files retain group access.
5. Do not use `0777` permissions as a shortcut.

Record the actual application IDs before changing host ownership:

```bash
pct exec <ARR_CTID> -- id <ARR_USER>
pct exec <DOWNLOAD_CTID> -- id <DOWNLOAD_USER>
pct exec <IMMICH_CTID> -- id <IMMICH_USER>
grep -E '^(root|<CONTAINER_USER>):' /etc/subuid /etc/subgid
grep -E '^(unprivileged|lxc.idmap)' /etc/pve/lxc/<CTID>.conf
```

Only after validating the mapping, assign the fresh media tree to the verified host-side media UID/GID and enable group inheritance:

```bash
MEDIA_HOST_UID=<VERIFIED_HOST_UID>
MEDIA_HOST_GID=<VERIFIED_HOST_GID>

chown -R "${MEDIA_HOST_UID}:${MEDIA_HOST_GID}" /mnt/bindmounts/media-data
find /mnt/bindmounts/media-data -type d -exec chmod 2775 {} +
find /mnt/bindmounts/media-data -type f -exec chmod 0664 {} +
```

Run this before migrating the large media library. Do not copy Cebu's numeric ownership values blindly.

Plex and Jellyfin only require read access, so their differing internal service UIDs do not need ownership of the media tree. Grant read/execute using ACLs or a mapped shared group.

Immich should have a dedicated dataset and ownership matching its actual unprivileged UID/GID mapping. The current Cebu guide records the Immich user mapping as host UID `100999` and GID `100991`, but this must be verified on the new CT rather than copied blindly.

## Provisional VM/LXC SSD Budget

The exact values should be adjusted after exporting actual Cebu usage.

| Workload | Initial allocation |
|---|---:|
| Plex root disk and metadata | 80–120 GB |
| Jellyfin root disk and metadata | 60–100 GB |
| Immich root disk, PostgreSQL, and ML cache | 80–150 GB |
| Arr stack and download configuration | 32–50 GB |
| Authentik | 20–32 GB |
| Nginx Proxy Manager | 8–16 GB |
| Pi-hole | 8 GB |
| Cloudflared | 4–8 GB |
| Free space / snapshots / growth | At least 20% of the SSD pool |

Do not place Immich thumbnails or encoded videos on the SSD unless the capacity audit shows ample room; large libraries can make those directories grow substantially.

## Staged Implementation Plan

### Phase 1: Hardware and Capacity Validation

1. Confirm the exact OptiPlex model supports the NVMe, 2.5-inch SSD, and 3.5-inch HDD simultaneously.
2. Confirm the PSU has the required SATA power connectors and adequate startup-current margin.
3. Confirm airflow around the 18 TB HDD; enterprise-capacity disks can run hot in SFF cases.
4. Confirm the 18 TB HDD is CMR and check its warranty/SMART state.
5. Record installed RAM. Use **32 GB minimum** for the documented Cebu-like workload; **64 GB is preferred** for Immich, two media servers, the Arr stack, and ZFS ARC.
6. Complete the capacity gate before purchasing or migrating data.

### Phase 2: Install Proxmox on NVMe

1. Back up the intended disk serial numbers before installation.
2. Install the current supported Proxmox VE release on the NVMe.
3. Use ext4/LVM for the boot device.
4. Keep guest disks off the NVMe.
5. Configure `local` for ISO images, container templates, and snippets.
6. Configure repository, updates, time sync, email/notification target, and UPS shutdown before migration.

### Phase 3: Create `vm-fast`

Destructive disk commands must use `/dev/disk/by-id/...`, never `/dev/sdX`, and only after matching the device serial number.

Provisional creation pattern:

```bash
ls -l /dev/disk/by-id/
smartctl -a /dev/disk/by-id/<SSD_ID>
zpool create -f -o ashift=12 -O compression=zstd -O atime=off vm-fast /dev/disk/by-id/<SSD_ID>
zpool set autotrim=on vm-fast
zfs create vm-fast/vmdata
```

Add `vm-fast/vmdata` to Proxmox as a ZFS storage supporting `Disk image` and `Container`.

### Phase 4: Create `bulk18`

Provisional creation pattern:

```bash
ls -l /dev/disk/by-id/
smartctl -a /dev/disk/by-id/<HDD_ID>
smartctl -t long /dev/disk/by-id/<HDD_ID>
zpool create -f -o ashift=12 \
  -O compression=zstd \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  -O mountpoint=none \
  bulk18 /dev/disk/by-id/<HDD_ID>

zfs create -o mountpoint=/mnt/bindmounts/media-data -o recordsize=1M bulk18/media-data
zfs create -o mountpoint=/mnt/bindmounts/immich-data -o recordsize=1M bulk18/immich-data
zfs create -o mountpoint=/mnt/bindmounts/shared -o recordsize=128K bulk18/shared
```

Create the media directory tree, then apply verified UID/GID ownership, setgid bits, and ACLs. Validate access using temporary test files before copying production data.

Do not add `bulk18` to Proxmox as general VM storage. Keeping bulk data outside the guest-volume allocator reduces the chance of accidentally creating VM disks on the HDD.

### Phase 5: Provision and Test Workloads

1. Export the authoritative Cebu inventory with `pct list`, `qm list`, and the relevant configuration files. Current repository documents disagree about some CT IDs and omit some active services.
2. Provision infrastructure services first: Pi-hole, Cloudflared, Nginx Proxy Manager, and Authentik.
3. Provision Plex, Jellyfin, Immich, the Arr stack, and the download client with root disks on `vm-fast`.
4. Add bind mounts while containers are stopped.
5. Validate permissions with test files.
6. Confirm Plex/Jellyfin cannot create or delete media.
7. Confirm Arr imports use hardlinks:

   ```bash
   stat /data/downloads/complete/<test-file>
   stat /data/library/movies/<test-file>
   ```

   Matching inode numbers confirm a hardlink instead of a second full copy.
8. Confirm Immich starts successfully and passes its storage integrity checks.

### Phase 6: Migrate Data

1. Perform the initial `rsync` while Cebu remains active.
2. Verify copied byte counts and sample checksums.
3. Schedule a maintenance window.
4. Stop only the writing applications: Immich server, Arr services, and the download client.
5. Run the final delta `rsync`.
6. Back up and restore application databases/configuration.
7. Start the new services and validate paths, user history, media playback, uploads, imports, and hardware transcoding.
8. Keep Cebu intact and powered off or read-only until the rollback window expires.

### Phase 7: Backups and Monitoring

1. Back up all VM/LXC root disks from `vm-fast` nightly to PBS, Synology, or another physical system.
2. Back up Immich's database and critical asset directories using a 3-2-1 policy.
3. Back up media according to replaceability and available capacity; at minimum, retain a file inventory/checksum manifest for replaceable media.
4. Create local ZFS snapshots for accidental deletion recovery, with retention constrained by capacity.
5. Run a monthly ZFS scrub.
6. Run weekly SMART short tests and monthly SMART long tests.
7. Alert on SMART errors, ZFS pool degradation, and 75%, 80%, and 85% capacity thresholds.
8. Test a VM/LXC restore and an Immich database-plus-assets restore before declaring the migration complete.

## Failure and Recovery Expectations

| Failure | Impact | Recovery |
|---|---|---|
| NVMe boot failure | Proxmox host will not boot; data pools should remain intact | Reinstall PVE, import `vm-fast` and `bulk18`, restore `/etc/pve` configuration or guest backups |
| 1 TB SSD failure | All VM/LXC root disks and databases unavailable | Replace SSD and restore guests from external backups |
| 18 TB HDD failure | Plex/Jellyfin libraries, downloads, and Immich assets unavailable | Replace HDD and restore bulk data from a separate copy |
| Accidental file deletion | Affected library content missing | Restore from a recent ZFS snapshot or backup |
| Host hardware failure | All local services offline | Move disks to compatible hardware, import pools, or restore services elsewhere |

Because the storage is local, these workloads are node-bound. Proxmox migration or HA cannot move the bind-mounted bulk data to another node automatically.

## Rollback Plan

During migration:

1. Do not delete or repurpose the Cebu source data.
2. Keep DNS, reverse-proxy, or client endpoint changes documented and reversible.
3. If validation fails, stop the new writers, point clients/proxy routes back to Cebu, and restart the original services.
4. Retain Cebu unchanged until at least one complete backup and restore test succeeds on the new host.

## Success Criteria

- Capacity audit proves at least two years of growth while staying below 80–85% bulk-pool utilization.
- The OS, guest disks, and bulk data are on separate physical devices.
- Plex and Jellyfin can read but not alter the media library.
- Arr/download services can hardlink and atomically import media.
- Immich assets are on the HDD while PostgreSQL remains on SSD.
- No service depends on a TrueNAS VM or a local SMB loopback mount.
- Guest backups and bulk-data backups reside on another physical system.
- SMART alerts, ZFS scrub scheduling, and capacity alerts are active.
- A documented restore test has succeeded.

## Outcome

This design removes the TrueNAS VM and SMB dependency from the media path while retaining filesystem checksums, snapshots, and direct host-to-LXC access. It improves boot reliability and reduces storage layers, but the single 18 TB HDD remains a single point of failure and may be undersized if the existing 9.45 TiB Immich library and the complete media library are both migrated.

## References

- [Proxmox VE Administration Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [Proxmox `pct` mount-point documentation](https://pve.proxmox.com/pve-docs/pct.1.html)
- [OpenZFS scrub and resilver documentation](https://openzfs.github.io/openzfs-docs/Basic%20Concepts/Operations/Scrub%20and%20Resilver.html)
- [Immich requirements](https://docs.immich.app/install/requirements/)
- [Immich backup and restore](https://docs.immich.app/administration/backup-and-restore/)
- [Cebu Immich LXC Setup Guide](./Cebu-Immich-LXC-Setup-Guide.md)
- [Cebu Arr Stack Setup](./Cebu-Arr-Stack-Setup.md)
- [Cebu Jellyfin Setup Guide](./Cebu-Jellyfin-Setup-Guide.md)
