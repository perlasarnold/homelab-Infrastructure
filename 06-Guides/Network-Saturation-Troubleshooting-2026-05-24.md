# 🌐 Troubleshooting: Network Saturation Investigation

* **Date**: May 24, 2026
* **Objective**: Diagnose and locate the source of heavy network traffic causing saturation in the homelab environment.
* **Status**: 🟢 Completed (Sources Identified)

---

## 1. Problem Statement

The user reported that something was saturating their local network. The goal was to identify the specific device, VM, container, or service responsible for the high traffic.

---

## 2. Investigation & Troubleshooting Steps

### Step 1: Local Client Analysis
We checked the TCP connection counts on the user's management PC to see if a local process was causing the issue:
```powershell
Get-NetTCPConnection | Group-Object -Property OwningProcess | Sort-Object Count -Descending
```
* **Result**: Connections were mostly standard browser and IDE traffic. No local process was generating unusual outbound saturation from this specific PC.

### Step 2: Proxmox Cluster Network Monitoring
We established passwordless SSH to both hypervisor nodes:
* **Bulakan** (`192.168.1.25`)
* **Cebu** (`192.168.1.26`)

We wrote a Python-based real-time network throughput monitor (`net_monitor.py`) to measure bandwidth on all virtual interfaces (`tap` and `veth`) and map them back to their Proxmox VM/LXC names using `qm list` and `pct list`.

### Step 3: Bandwidth Analysis (Multiple Iterations)
Running the monitor for multiple iterations revealed two sustained high-traffic sources:

#### Source A: Bulakan Hypervisor (`192.168.1.25`)
* **Interface**: `tap203i0` (associated with **VM 203 (Bastion)**)
* **Bandwidth**: **~340–350 Mbps** (Sustained Download/RX)
* **Physical NIC**: `bond0` / `enp1s0` showed matching RX rates of ~350 Mbps entering the host from the wire.

#### Source B: Cebu Hypervisor (`192.168.1.26`)
* **Interface**: `tap120i0` (associated with **VM 120 (TrueNAS-SCALE)**)
* **Bandwidth**: **~70–240 Mbps** of SMB traffic.
* **Local Container Spikes**: Earlier measurements showed **LXC 416 (Jellyfin-Cebu)** transferring up to **373 Mbps** to/from the TrueNAS share.

---

## 3. Root Cause & Traffic Identification

To find the exact nature of the transfers, we ran packet captures (`tcpdump`) on the Proxmox hosts:

### 1. Bastion VM (`192.168.1.222`) Traffic
```bash
tcpdump -n -i vmbr0 host 192.168.1.222 -c 50
```
* **Protocol**: **SMB (Port 445)**
* **Peer**: `192.168.1.14` (`pnas.local` — Synology NAS)
* **Secondary Traffic**: UDP traffic between the Bastion VM and `192.168.1.178` (`Perlas` client), characteristic of a remote session (RDP/Parsec).
* **Root Cause**: The user was active in the Bastion VM copying large volumes of data from the Synology NAS via SMB.

### 2. TrueNAS-SCALE VM (`192.168.1.211`) Traffic
```bash
tcpdump -n -i vmbr0 host 192.168.1.211 -c 50
```
* **Protocol**: **SMB (Port 445)**
* **Peer**: `192.168.1.205` (Local Windows Workstation)
* **Active Guest Commands**:
  ```bash
  ps aux | grep -E 'rclone|sync|rm'
  ```
  revealed:
  - `smbd: client [192.168.1.205]` consuming **10.3% CPU** (Sustained SMB access from the workstation).
  - `rm -rf /mnt/DAS2-18TB/photo/#snapshot` running in uninterruptible disk wait state (**D-state**), causing heavy disk I/O load on the ZFS storage pool.
* **Root Cause**: The workstation was reading/writing to TrueNAS shares, while TrueNAS was concurrently performing a major snapshot cleanup.

---

## 4. Outcome & Recommendations

1. **Active Transfers Identified**:
   - **~350 Mbps** is being consumed by **VM 203 (Bastion)** copying files from the **Synology NAS** (`192.168.1.14`).
   - **~70–115 Mbps** is being consumed by the **Windows Workstation** (`192.168.1.205`) interacting with **TrueNAS-SCALE** (`192.168.1.211`).
2. **Disk I/O Bottleneck**:
   - The deletion of `#snapshot` on `DAS2-18TB` is keeping disk pools busy, which can degrade SMB performance and exacerbate network wait times.

### Next Steps:
* If the file copies are intentional, the network will return to normal once they finish.
* If they are runaway tasks, the SMB connections can be closed, or the Bastion VM can be paused/stopped.
* Allow the ZFS snapshot deletion to finish to resolve disk I/O constraints on Cebu.

---

## 📚 References
* [[04-Network/Network Overview]]
* [[04-Network/UniFi Router Setup]]
* [[06-Guides/TrueNAS-System-Dataset-Deadlock-Recovery]]
