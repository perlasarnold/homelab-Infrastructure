# Guide: TrueNAS SCALE on Proxmox (JBOD Setup)

This guide documents the high-performance deployment of TrueNAS SCALE (VM 120) on the Proxmox node `cebu`, utilizing a JBOD strategy for 18TB DAS drives.

## Environment Overview

- **Node**: `cebu` (192.168.1.26)
- **TrueNAS VM**: ID 120 (192.168.1.211)
- **Host Pools**: `das-18tb-1`, `das-18tb-2`, `das-18tb-3`, `das-6tb`
- **Target Storage**: ~60TB raw capacity presented via SMB/NFS.

---

## 1. VM Hardware Configuration

Performance for ZFS-on-ZFS depends on passing through CPU instructions and using efficient disk controllers.

### CPU Settings
Select **Host** as the CPU Model. This allows TrueNAS to utilize native instruction sets:
- **AES-NI**: Hardware acceleration for encryption.
- **AVX**: Faster parity calculations and data processing.

### SCSI Controller
Use `VirtIO SCSI single`. This controller is optimized for high-throughput storage and supports advanced flags like Discard and IO Threads.

### Disk Flags
For every high-capacity drive attached, ensure the following are enabled in the **Advanced** hardware settings:
- **Discard**: `on` (Enables TRIM support for ZFS space reclamation).
- **IO Thread**: `on` (Assigns a dedicated thread to the disk to prevent latency spikes).
- **Async IO**: `io_uring` (The fastest modern Linux I/O interface).

---

## 2. Storage Strategy: The "Storage Sandwich"

We opted for **Virtual Disks on Host Pools** rather than hardware passthrough (HBA) to maintain Proxmox's management capabilities.

### The 10% Slop Space Rule
When creating virtual disks on a ZFS host pool, **never allocate 100% of the space**. ZFS requires roughly 10% of the pool to be free for metadata, snapshots, and administrative overhead. 

- **Physical Drive**: 18TB (~16.3 TiB)
- **Virtual Disk**: 16000 GiB (~15.6 TiB)

> [!WARNING]
> Attempting to allocate the full pool capacity will result in `Error 500: Out of space` or host instability if the pool hits 100% utilization.

### Data Flow
1. **Physical Layer**: 18TB SAS/SATA drives connected to `cebu`.
2. **Host Layer**: Proxmox manages drives via ZFS pools (e.g., `das-18tb-1`).
3. **Virtual Layer**: A `.raw` disk image (16000 GiB) is created on the host pool.
4. **Guest Layer**: TrueNAS (VM 120) sees the virtual disk as a local SCSI drive and formats it with its own ZFS pool.
5. **Network Layer**: TrueNAS shares the storage via SMB (Windows) or NFS (Linux).

---

## 3. Troubleshooting & Gotchas

### Disk Visibility in Proxmox
If your DAS pools do not appear in the "Add Hard Disk" dropdown:
1. Go to **Datacenter > Storage**.
2. Edit the ZFS pool entry.
3. Ensure **Disk Image** is selected in the **Content** dropdown.

### Resizing Virtual Disks
To adjust a disk size (e.g., if you accidentally typed `1600G` instead of `16000G`):
1. Highlight the disk in the **Hardware** tab.
2. Click **Disk Action > Resize**.
3. Enter the **Increment** needed to reach the target size (e.g., `14400` to go from 1600 to 16000).

---

## 4. Post-Install: JBOD Configuration

To treat the drives as independent volumes (JBOD) while benefiting from TrueNAS management:

1. **Create Individual Pools**: In TrueNAS, create a separate pool for each virtual disk (e.g., `DAS1-18TB`).
2. **VDEV Layout**: Select **Stripe** for the Data VDEV. 
   - *Note: TrueNAS will warn about lack of redundancy. This is acceptable as the Proxmox host pools already provide the physical redundancy layer.*
3. **Datasets**: Create a dataset (e.g., `data`) within each pool to manage permissions and quotas.
4. **Network Shares**: Configure **Windows (SMB)** shares for each dataset to make them accessible across the `Homelab-Net` datacenter.

---

## 5. Actionable Takeaways

- Use **io_uring** and **Discard** flags for all virtual storage.
- Maintain **10% free space** on the Proxmox host pools.
- Use **NFS** for Linux containers (LXC) and **SMB** for Windows VMs.
- Link the TrueNAS SMB shares back to Proxmox via **Datacenter > Storage > Add > SMB/CIFS** for a unified sidebar view.
