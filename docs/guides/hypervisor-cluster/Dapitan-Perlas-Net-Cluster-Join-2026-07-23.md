# Dapitan — Homelab-Net Cluster Join

## Date

2026-07-23

## Objective

Attach the standalone Dapitan Proxmox VE host (`VLAN 1 [Management]`) to the
existing `Homelab-Net` cluster without interrupting guests on Bulakan or
Cebu, while preserving Dapitan's node-local ZFS storage and direct-mounted
18 TB datasets.

## Starting State

| Item | Verified state |
|---|---|
| Existing nodes | Bulakan (`VLAN 1 [Management]`) and Cebu (`VLAN 1 [Management]`) |
| Cluster | `Homelab-Net`, two of two votes online and quorate |
| Software | All three hosts on PVE Manager `9.2.5` and kernel `7.0.14-6-pve` |
| Dapitan guests | None |
| Dapitan VM storage | `vm-fast/vmdata`, healthy and approximately 899 GiB free |
| Dapitan bulk storage | `bulk18`, healthy and approximately 16.2 TiB free |
| Shared backup storage | PNAS active with approximately 4.60 TiB free |

The empty guest inventory was important because Proxmox replaces a joining
node's standalone `/etc/pve` configuration with the cluster configuration.

## Steps Taken

### 1. Audited cluster-join prerequisites

- Confirmed matching PVE and kernel versions.
- Confirmed Dapitan was not already clustered.
- Confirmed Dapitan had no VM or LXC configuration.
- Verified cluster quorum, network routes, node names, storage IDs, ZFS
  health, PNAS access, and failed-unit state.
- Confirmed `vm-fast` did not conflict with an existing cluster storage ID.
- Confirmed `bulk18` was host-mounted ZFS and not a Proxmox allocator
  storage, so it would not be affected by the storage configuration merge.

### 2. Created verified rollback archives

Dapitan standalone configuration:

```text
/mnt/pve/PNAS/dump/dapitan-precluster-20260723-144100.tar.gz
SHA-256: 93885eb126b182504e13a7787266100c6899ad32497e44724b344c12b0100630
```

Existing Homelab-Net cluster configuration:

```text
/mnt/pve/PNAS/dump/Homelab-Net-pre-dapitan-join-20260723-144300.tar.gz
SHA-256: 528459962ef8d1ce6659ece88b42499452c8de631c22eb2394fde67a6342273c
```

Both archives passed `tar -tzf` readability checks. The pmxcfs
extended-attribute warnings produced while archiving Dapitan were expected;
the archive contents were readable.

The original cluster SSH authorization file was also copied to:

```text
/root/authorized_keys.pre-dapitan-20260723-1445
```

### 3. Established node-to-node SSH trust

Dapitan's existing root public key was added to the cluster-wide authorized
keys after backing up the file. The expected fingerprint was verified, and
a passwordless Dapitan-to-Bulakan connection succeeded before the join.

No password or private key was copied into the documentation or shell
history.

### 4. Joined Dapitan to Homelab-Net

The join was run from Dapitan with its corosync address explicitly pinned:

```bash
pvecm add VLAN 1 [Management] \
  --use_ssh 1 \
  --link0 address=VLAN 1 [Management]
```

Proxmox backed up Dapitan's old pmxcfs database internally, replaced its
standalone cluster configuration and certificate, regenerated node files,
and restarted Dapitan's management services. The task finished with:

```text
successfully added node 'Dapitan' to cluster
```

Bulakan and Cebu guests remained online throughout the join.

### 5. Restored Dapitan-specific storage

The cluster-wide PNAS entry was extended to Dapitan:

```bash
pvesm set PNAS --nodes Bulakan,cebu,Dapitan
```

Dapitan's VM/LXC ZFS allocator was restored as node-restricted storage:

```bash
pvesm add zfspool vm-fast \
  --pool vm-fast/vmdata \
  --content images,rootdir \
  --sparse 1 \
  --nodes Dapitan
```

`bulk18` remained outside Proxmox storage allocation. Its datasets continued
to mount directly at:

```text
/mnt/bindmounts/shared
/mnt/bindmounts/media-data
/mnt/bindmounts/immich-data
```

### 6. Standardized cluster hostname resolution

Per-node backups were created before editing `/etc/hosts`. Each node now
resolves:

```text
VLAN 1 [Management] Bulakan.homelab-admin.me Bulakan
VLAN 1 [Management] cebu.homelab-admin.me cebu
VLAN 1 [Management] Dapitan.homelab-admin.me Dapitan
```

No networking service reload was required.

### 7. Validated the completed cluster

- Cluster configuration version: `3`
- Expected and total votes: `3`
- Quorum: `2`
- Bulakan, Cebu, and Dapitan: online
- Corosync link 0: all three nodes connected
- PNAS on Dapitan: active
- `vm-fast` on Dapitan: active
- `vm-fast` and `bulk18`: healthy
- All three `bulk18` child datasets: mounted read/write
- Dapitan core services: `pve-cluster`, `corosync`, `pvedaemon`,
  `pveproxy`, and `pvestatd` active
- Dapitan failed units: none
- Dapitan PVE API: responsive
- Existing Bulakan and Cebu guests: retained their pre-join states

Three transient KNET warnings occurred while node 3 was being introduced,
before Dapitan's corosync link became active. The final link state was fully
connected.

## Outcome

Dapitan is node 3 in the `Homelab-Net` cluster. The cluster is healthy and
quorate with two votes required out of three. Dapitan's PNAS and `vm-fast`
storage are visible through Proxmox, while the `bulk18` datasets remain
host-managed for future least-privilege LXC bind mounts.

No VM or LXC was stopped, restarted, migrated, created, or deleted during
the cluster join.

## Rollback

- Use the two verified PNAS archives to recover the pre-change standalone
  Dapitan configuration or the pre-join cluster configuration.
- Use the per-node `/etc/hosts` backups to reverse hostname entries if
  necessary.
- Do not manually delete a live node from Corosync or copy the old pmxcfs
  database over an active cluster. Follow the official Proxmox
  node-separation procedure if Dapitan must leave the cluster.
- Removing the `vm-fast` Proxmox storage definition does not destroy its ZFS
  data, but always verify the exact storage ID and pool before removal.

## References

- [Proxmox VE Administration Guide — Adding Nodes to the Cluster](https://pve.proxmox.com/pve-docs/pve-admin-guide.pdf)
- [OptiPlex Proxmox Direct-Attached Storage Plan](./OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22.md)
- [Proxmox Overview](../02-Proxmox/Proxmox%20Overview.md)
