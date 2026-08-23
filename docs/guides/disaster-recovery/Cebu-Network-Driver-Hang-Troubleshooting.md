# Cebu Network Driver Hang Troubleshooting

- **Date:** 2026-05-24
- **Objective:** Resolve unexpected network connectivity loss on the Proxmox Cebu hypervisor node (`VLAN 1 [MGMT]`).

---

## Problem Statement

The Cebu server was periodically losing all network connectivity, isolating it from the local network and disrupting hosted LXCs and VMs. While local hypervisor processes remained running, the management interface and all virtual machines lost external access.

---

## Investigation & Root Cause

1. **System Log Audit**:
   Inspecting the kernel logs on Cebu (`journalctl -t kernel`) revealed repeated Hardware Unit Hang messages immediately prior to the connectivity loss:
   ```text
   May 24 13:55:03 cebu kernel: e1000e 0000:00:1f.6 nic0: Detected Hardware Unit Hang:
   May 24 13:55:05 cebu kernel: e1000e 0000:00:1f.6 nic0: Detected Hardware Unit Hang:
   ...
   May 24 13:57:56 cebu kernel: e1000e 0000:00:1f.6 nic0: NIC Link is Down
   May 24 13:57:56 cebu kernel: vmbr0: port 1(nic0) entered disabled state
   ```

2. **Analysis**:
   - **NIC Details**: The interface `nic0` is an onboard Intel Gigabit network adapter (Intel I219-V, PCIe address `0000:00:1f.6`) running the `e1000e` driver.
   - **Bug Mechanism**: The Linux `e1000e` driver is known to suffer from a driver/hardware hang under heavy bridged loads (common on Proxmox virtualization hosts). During packet segmentation offloading (TSO/GSO/GRO), the NIC hardware fails to process descriptors quickly enough, causing the driver to flag a "Hardware Unit Hang", reset the adapter, and temporarily drop the link.

---

## Resolution Applied

We disabled TCP Segmentation Offload (TSO), Generic Segmentation Offload (GSO), and Generic Receive Offload (GRO) both at runtime and persistently. This shifts packet segmentation processing from the NIC hardware to the system CPU, preventing the driver locks.

### Step 1: Backup Current Configuration
Created a backup of `/etc/network/interfaces` on Cebu:
```bash
cp /etc/network/interfaces /etc/network/interfaces.bak
```

### Step 2: Apply Persistent Fix
Modified `/etc/network/interfaces` to add a `post-up` hook on `nic0` that disables offloading when the interface initializes:
```text
iface nic0 inet manual
    post-up /usr/sbin/ethtool -K nic0 tso off gso off gro off
```

### Step 3: Apply Runtime Fix (No Downtime)
Applied the settings immediately at runtime without restarting network interfaces or disrupting active services:
```bash
ethtool -K nic0 tso off gso off gro off
```

---

## Outcome

### Verification
1. Running the offload query confirms the offloading capabilities are disabled:
   ```bash
   ethtool -k nic0 | grep -E 'tcp-segmentation-offload|generic-segmentation-offload|generic-receive-offload'
   ```
   **Output:**
   ```text
   tcp-segmentation-offload: off
   generic-segmentation-offload: off
   generic-receive-offload: off
   ```
2. Validated `/etc/network/interfaces` syntax parsing using `ifquery`:
   ```bash
   ifquery nic0
   ```
   **Output:**
   ```text
   iface nic0 inet manual
       post-up /usr/sbin/ethtool -K nic0 tso off gso off gro off
   ```
3. Network connectivity is fully restored and stable, and no further "Detected Hardware Unit Hang" entries have been logged in `journalctl`.

---

## References
- Proxmox Forums: [Intel e1000e NIC reset bug workarounds](https://forum.proxmox.com)
- Debian/Ubuntu Bug Reports: [e1000e Hardware Unit Hang with bridged networking](https://bugs.debian.org)
