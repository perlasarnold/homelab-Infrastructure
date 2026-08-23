# 🛡️ Cebu Proxmox Node VLAN & Subnet Migration Guide

* **Date:** 2026-07-30
* **Objective:** Configure 802.1Q Virtual LAN (VLAN) tagging and subnet isolation for the Proxmox **Cebu** hypervisor node (`VLAN 1 [Management]`), segmenting its workloads across Management (VLAN 10), Internal Services (VLAN 110), DMZ (VLAN 120), IoT (VLAN 30), and Trusted Workstations (VLAN 20).
* **Scope:** Proxmox VE 9.2.5 (`Cebu`), UniFi Cloud Gateway Max (`Perlas-UnifiGW`), USW Pro Max 16 Switch, and Terraform configuration code.
* **Maintainer:** Perlas

---

## 🎯 Target Network Architecture Matrix

| VLAN | Subnet Name | Subnet Range | Gateway | Cebu Workloads & Service Targets |
|:---:|:---|:---|:---|:---|
| **10** | **MGMT** | `VLAN 10 (SecOps)/24` | `VLAN 10 (SecOps)` | Hypervisor Management Interface (`VLAN 10 (SecOps)`), TrueNAS Web UI (`VLAN 10 (SecOps)`) |
| **20** | **TRUSTED** | `VLAN 20 (Trusted)/24` | `VLAN 20 (Trusted)` | Admin Desktop `Perlas-W10` (VM 101) |
| **30** | **IOT** | `VLAN 30 (IoT)/24` | `VLAN 30 [Gateway]` | Smart Home Controller `haos-17.3` (VM 111) |
| **110** | **SERVICES** | `VLAN 110 (Services)/24` | `VLAN 110 [Gateway]` | `pihole-cebu` (CT 401 — `pihole-cebu.homelab.internal (VLAN 110)`), `jellyfin-cebu` (CT 416 — `jellyfin-cebu.homelab.internal (VLAN 110)`), `plex-cebu` (CT 405 — `plex-cebu.homelab.internal (VLAN 110)`), `arr-stack-cebu` (CT 417 — `arr-stack.homelab.internal (VLAN 110)`), `fileserver` (CT 402/214 — `fileserver.homelab.internal (VLAN 110)`), `authentik` (CT 103 — `auth.homelab.internal (VLAN 110)`) |
| **120** | **DMZ / EXTERNAL** | `VLAN 120 (DMZ)/24` | `VLAN 120 (DMZ)` | `cloudflared-cebu` (CT 404 — `VLAN 120 (DMZ)`), `npm-cebu` (CT 105 — `VLAN 120 (DMZ)`) |

---

## 📋 Steps Taken & Rationale

### Step 1: UniFi Switch Port Trunking
* **Action:** In UniFi Network Controller, locate the port on **USW Pro Max 16** assigned to Cebu's primary network card (`vmbr0`).
* **Configuration:**
  * **Native Network:** VLAN 1 (Management default)
  * **Tagged VLAN Management:** Allow All (Trunk mode enabled; `Traffic Restriction` disabled).
* **Rationale:** Allows 802.1Q frames carrying tags 10, 20, 30, 110, and 120 to pass across the physical ethernet cable directly to the Proxmox bridge without being dropped by the switch hardware.

### Step 2: Proxmox Bridge VLAN Awareness (`vmbr0`)
* **Action:** 
  1. Open Proxmox Cebu Web Console (`https://VLAN 1 [Management]:8006`).
  2. Select **Cebu** ➡️ **System** ➡️ **Network** ➡️ **vmbr0**.
  3. Check **VLAN Aware** ➡️ Click **OK** ➡️ Click **Apply Configuration**.
* **CLI Rationale:** This updates `/etc/network/interfaces` on Cebu so that `bridge-vlan-aware yes` is appended to `vmbr0`. Individual guest interfaces (`vnetX`) can now attach 802.1Q tags dynamically.

### Step 3: Phase 1 Container Migration (DMZ - VLAN 120)
* **Action:**
  * For **CT 404 (`cloudflared-cebu`)**: Set `vlan=120`, static IP `VLAN 120 (DMZ)/24`, Gateway `VLAN 120 (DMZ)`. **[VERIFIED ACTIVE - Healthy Tunnel Replica]**
  * For **CT 105 (`npm-cebu`)**: Set `vlan=120`, static IP `VLAN 120 (DMZ)/24`, Gateway `VLAN 120 (DMZ)`. **[VERIFIED ACTIVE - DMZ Ingress Proxy]**
* **Rationale:** Isolates external ingress points into a DMZ subnet. If an internet attack succeeds against Cloudflared or Nginx Proxy Manager, the attacker cannot reach local Proxmox management or SMB shares.



### Step 4: Phase 2 Container Migration (Internal Services - VLAN 110)
* **Action:**
  * For **CT 401 (`pihole-cebu`)**: Set `vlan=110`, IP `pihole-cebu.homelab.internal (VLAN 110)/24`, Gateway `VLAN 110 [Gateway]`.
  * For **CT 416 (`jellyfin-cebu`)** & **CT 405 (`plex-cebu`)**: Set `vlan=110`, IPs `jellyfin-cebu.homelab.internal (VLAN 110)` / `plex-cebu.homelab.internal (VLAN 110)`.
  * For **CT 417 (`arr-stack-cebu`)** & **CT 402 (`fileserver`)**: Set `vlan=110`, IPs `arr-stack.homelab.internal (VLAN 110)` / `fileserver.homelab.internal (VLAN 110)`.
* **Rationale:** Groups internal application servers into `VLAN 110 (Services)/24`, keeping inter-service traffic local while protecting hypervisor infrastructure.

### Step 5: Terraform Infrastructure Code Synchronization
* **Action:** Updated `terraform/proxmox/modules/lxc/variables.tf`, `main.tf`, and `terraform/proxmox/cebu.tf` to incorporate `vlan_id` parameters and updated IP allocations.
* **Rationale:** Preserves Terraform code reproducibility for Cebu as the active testbed for multi-node Proxmox automation.

### Step 6: UniFi Firewall Security Rules (LAN IN)
* **Action:** Configured stateful firewall rules under **UniFi ➡️ Settings ➡️ Security ➡️ Firewall Rules (LAN IN)**:
  1. `Allow Established/Related`: Permits return packets for active connections.
  2. `Allow Inter-VLAN DNS`: Grants ALL subnets UDP/TCP Port 53 access to Pi-hole (`pihole-cebu.homelab.internal (VLAN 110)`).
  3. `Allow Media to Storage`: Permits VLAN 110 access to SMB (`445`) and NFS (`2049`) on TrueNAS/Synology storage IPs.
  4. `Drop Inter-VLAN Cross-Talk`: Blocks all RFC1918 cross-subnet traffic not explicitly allowed above.

---

## 📊 Outcome & Verification

1. **VLAN Tagging Verification:** Verified `vmbr0` in Proxmox Cebu processes tagged frames without hypervisor interface dropping.
2. **DNS & Connectivity:** Confirmed cross-VLAN DNS queries to Pi-hole (`pihole-cebu.homelab.internal (VLAN 110)`) succeed across VLAN boundaries.
3. **DMZ Isolation:** Confirmed DMZ containers on `192.168.120.x` are blocked from accessing Proxmox management GUI (`VLAN 1 [Management]` / `VLAN 10 (SecOps)`) and storage administration.
4. **Terraform Integrity:** Terraform definitions in `cebu.tf` pass validation with matching network tags.

---

## 🔄 Rollback Plan

If network communication to a container fails after applying a VLAN tag:
1. Access the Proxmox Cebu web GUI or console.
2. Select the container ➡️ **Hardware** ➡️ **Network Device (eth0)** ➡️ **Edit**.
3. Clear the **VLAN Tag** field (restoring native untagged behavior on VLAN 1).
4. Reset the container IPv4 address back to `192.168.1.x/24` with Gateway `VLAN 1 [Gateway]`.
5. Restart container networking (`pct restart <CTID>`).

---

## 🔗 References

* [VLAN Segmentation & Migration Roadmap](file:////opt/homelab-infrastructure/06-Guides/VLAN-Segmentation-Roadmap.md)
* [Cebu Proxmox Terraform Definitions](file:////opt/homelab-infrastructure/terraform/proxmox/cebu.tf)
* [Services Master Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
* [Network Overview](file:////opt/homelab-infrastructure/04-Network/Network%20Overview.md)
