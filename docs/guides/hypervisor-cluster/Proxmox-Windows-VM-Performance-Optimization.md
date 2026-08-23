# ⚡ Proxmox Windows VM Performance Optimization Guide

> **Date:** May 19, 2026  
> **Objective:** Safely diagnose and resolve severe slowness on the Windows 10 guest VM (`Perlas-W10` / ID 101) on Proxmox node `cebu` (192.168.1.26), improve response times, and reduce host CPU load.  
> **Target VM:** ID 101 (`Perlas-W10`) on Cebu  
> **Maintainer:** Perlas  

---

## 1. Problem Statement
The daily-use Windows 10 VM hosted on the Cebu Proxmox node was experiencing severe latency, slow boot times, and laggy UI interactions. Diagnostics on the Cebu host revealed that the KVM process representing the VM was pinning 4 cores, consuming over **415% host CPU** and pushing the host load average above **11.60** (on a 6-core / 12-thread Intel i5-10500T).

---

## 2. Root Cause Analysis
An audit of the VM's hardware configuration (`qm config 101`) revealed several massive bottlenecks:
1. **Emulated IDE Disk Controller (`ide0`)**: Windows was booting from an emulated IDE hard drive. IDE lacks native command queueing, operates synchronously, and bottlenecked Cebu's high-speed local ZFS NVMe/SSD pool.
2. **Emulated Intel E1000 Network Card (`net0`)**: The virtual network card simulated a physical E1000 adapter in software, requiring extensive QEMU emulation overhead.
3. **Generic CPU Type (`kvm64`)**: The CPU was set to the default compatibility profile. This hid the native Intel Core i5-10500T instruction sets (such as `AVX`, `AVX2`, and `AES-NI`) from Windows, forcing generic software execution paths.
4. **QEMU Guest Agent Disabled**: Proxmox had no coordination with the guest OS for clean shutdowns, filesystem freeze/trim, or RAM ballooning.

---

## 3. Steps Taken (with Rationale)

### Step 3.1: Download and Upload VirtIO Drivers ISO
To avoid Fedora's notoriously slow project servers (which were downloading at ~400 KB/s on Cebu), the stable VirtIO drivers ISO was downloaded locally to the Windows workstation and uploaded to Cebu via LAN SCP:
* **Local Download Path:** `/opt/homelab-infrastructure\scratch\virtio-win.iso`
* **Remote Proxmox Path:** `/var/lib/vz/template/iso/virtio-win.iso`
* **Rationale:** Local download hit **30MB/s**, completing in 30 seconds, and SCP over gigabit LAN transferred the 754MB ISO in under 10 seconds.

### Step 3.2: Configure Staging Hardware (Safe Driver Injection)
> [!WARNING]
> Swapping a Windows boot disk from IDE to SCSI immediately will crash the OS on boot with an `INACCESSIBLE_BOOT_DEVICE` Blue Screen of Death (BSOD) because Windows does not load storage drivers it hasn't seen during active boot.

To inject the SCSI storage driver safely before switching the boot controller:
1. **Add Dummy SCSI Disk**: Created and attached a temporary 1GB VirtIO SCSI disk while the VM was running:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --scsi1 cebu-zfs:1"
   ```
2. **Mount Driver ISO**: Loaded the VirtIO ISO in the CD-ROM drive:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --ide2 local:iso/virtio-win.iso,media=cdrom"
   ```
3. **Rationale**: This forced running Windows to detect the VirtIO SCSI controller hardware and prompt for a driver without breaking the boot disk.

### Step 3.3: Guest-Side Driver and Tools Installation
Within the Windows guest (accessed via noVNC console):
1. Opened **File Explorer** and navigated to the mounted CD-ROM drive.
2. Ran **`virtio-win-gt-x64.msi`** (the Guest Tools installer).
3. **Rationale**: This single installer automatically installs all official, digitally-signed Red Hat VirtIO drivers (including the `viostor` SCSI storage driver, `NetKVM` network driver, and `balloon` memory driver) and registers/starts the **QEMU Guest Agent** service.

### Step 3.4: Perform Hardware Migration
Once the guest finished driver installations, the VM was powered down cleanly:
```bash
ssh root@192.168.1.26 "qm stop 101"
```

The final high-performance settings were applied to the VM:
1. **Detach IDE Disk**: Unlinked the main 200GB disk from `ide0` (moving it to `unused0` safety zone):
   ```bash
   ssh root@192.168.1.26 "qm set 101 --ide0 none"
   ```
2. **Reattach as SCSI with Write-Back Cache**: Reattached the main disk as SCSI0, enabling ZFS optimization and high-speed write caching:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --scsi0 cebu-zfs:vm-101-disk-0,discard=on,ssd=1,cache=writeback"
   ```
   * *discard=on*: Enables TRIM support on ZFS SSD storage.
   * *ssd=1*: Tells Windows to optimize its indexing/IO scheduling for SSD.
   * *cache=writeback*: Employs host-level RAM caching for huge write IOPS gains.
3. **Purge Dummy Volume**: Deleted the temporary 1GB dummy volume to keep the ZFS pool clean:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --delete unused0"
   ```
4. **Upgrade Network**: Swapped the emulated network card to the lightweight VirtIO adapter:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --net0 virtio=00:11:22:33:44:55,bridge=vmbr0,firewall=1"
   ```
5. **Optimize CPU**: Set CPU type to `host` to expose native instruction sets:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --cpu host"
   ```
6. **Enable Guest Agent**:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --agent enabled=1"
   ```
7. **Correct Boot Order**: Quoted/escaped the order string to prevent Bash semicolon errors:
   ```bash
   ssh root@192.168.1.26 "qm set 101 --boot order=scsi0\;ide2\;net0"
   ```

---

## 4. Outcome
* **Successful Boot**: The virtual machine booted instantly on SCSI0 without any BSOD or errors.
* **Premium Performance**: Windows 10 now feels extremely snappy, boot times are reduced to seconds, and storage/network operations are highly responsive.
* **Host Resource Relief**: Host CPU load average decreased dramatically, as hardware-emulation overhead is eliminated.
* **Clean Environment**: All temporary/dummy volumes were successfully deleted.

---

## 5. Maintenance & Guest Agent Check
If the QEMU Guest Agent does not immediately report online in Proxmox (due to service startup order in Windows):
1. Log in to Windows.
2. Press `Win + R`, type **`services.msc`**, and press Enter.
3. Locate **QEMU Guest Agent** in the list.
4. If it is stopped, right-click and click **Start**.
5. Ensure its **Startup type** is set to **Automatic**.

---

## 6. References
* [Proxmox VE Administration Guide: Windows Guest Installation](https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_guests_windows)
* [Fedora Project VirtIO Windows Drivers Wiki](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/)
