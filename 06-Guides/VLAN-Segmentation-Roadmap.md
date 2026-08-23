# 🛡️ Homelab VLAN Segmentation & Migration Roadmap

* **Date:** 2026-05-16
* **Objective:** Establish a highly secure, performant, and structured Virtual LAN (VLAN) architecture for the Homelab-Net / Core Homelab, isolating public-facing services, trusted clients, internal servers, and IoT gear while preserving low-latency access to shared Synology/TrueNAS storage.
* **Scope:** Tailored for UniFi Cloud Gateway Max (UCG Max), USW Pro Max 16 Switch, U7 Pro AP, and Proxmox (Bulakan & Cebu) hypervisors.

---

## 🏗️ The Problem: The "Flat Network" Risk

Currently, most of the Homelab-Net hypervisors, VM storage interfaces, Pi-hole servers, media stack (Radarr, Sonarr, Plex, Jellyfin), and daily-use devices sit directly on the native **VLAN 1 (`192.168.1.0/24`)**. 
If a single container (e.g. an internet-exposed reverse proxy or a torrent client) is compromised, an attacker can immediately pivot to:
1. **Hypervisor Hosts:** Direct access to Proxmox Bulakan/Cebu GUI, SSH, and cluster synchronization.
2. **Core Storage:** Unrestricted mounting and admin access to Synology PNAS/PNAS2 and TrueNAS SCALE ZFS pools.
3. **Core Network Gear:** Direct web access to the UniFi UCG Max gateway and USW switches.

---

## 🗺️ Target VLAN Architecture Design

To achieve robust security without breaking communications, we will partition the homelab into logical zones:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               Homelab-Net VLANS                                  │
├───────┬──────────────┬───────────────────┬──────────────────────────────────────┤
│ VLAN  │ Name         │ Subnet            │ Target Devices                       │
├───────┼──────────────┼───────────────────┼──────────────────────────────────────┤
│ 10    │ MGMT         │ VLAN 10 (MGMT/SecOps)/24   │ Proxmox Hosts, UniFi GW, switches,   │
│       │              │                   │ Synology/TrueNAS Web UI, IPMI/iDRAC  │
├───────┼──────────────┼───────────────────┼──────────────────────────────────────┤
│ 20    │ TRUSTED      │ VLAN 20 (Trusted)/24   │ Admin PCs, trusted laptops, phones   │
├───────┼──────────────┼───────────────────┼──────────────────────────────────────┤
│ 30    │ IOT          │ 192.168.30.0/24   │ Smart TVs, cameras, switches, bulbs  │
├───────┼──────────────┼───────────────────┼──────────────────────────────────────┤
│ 110   │ SERVICES     │ 192.168.42.0/24   │ Plex, Jellyfin, Arr stack, Immich,   │
│       │              │                   │ TrueNAS/Synology SMB storage links   │
├───────┼──────────────┼───────────────────┼──────────────────────────────────────┤
│ 120   │ DMZ/EXTERNAL │ VLAN 120 (DMZ)/24  │ Nginx Proxy Manager, Cloudflared     │
└───────┴──────────────┴───────────────────┴──────────────────────────────────────┘
```

---

## 🛠️ Phase-by-Phase Migration Blueprint

To prevent service disruption (per ECC safety guidelines), we divide this transition into **5 safe phases**.

---

### 🚀 Phase 1: Proxmox & Physical Switch Trunking
*Before moving any virtual interface, the physical switch and Proxmox virtual switch must be prepared to carry multiple tags (IEEE 802.1Q).*

```
                     ┌────────────────────────┐
                     │ USW Pro Max 16 Switch  │
                     └───────────┬────────────┘
                                 │ Trunk Port (Passes VLAN 10, 20, 30, 110, 120)
                                 ▼
                   ┌───────────────────────────┐
                   │  Proxmox Physical NIC/Bond│ (enp1s0 + USB NIC)
                   └─────────────┬─────────────┘
                                 ▼
                   ┌───────────────────────────┐
                   │    vmbr0 (VLAN-Aware)     │
                   └──────┬─────────────┬──────┘
                          │ Tag 120     │ Tag 110
                          ▼             ▼
                     ┌───────────┐ ┌───────────┐
                     │ NPM LXC   │ │ Plex LXC  │
                     └───────────┘ └───────────┘
```

1. **Enable VLAN Awareness in Proxmox:**
   * Log into the Proxmox Bulakan and Cebu GUIs.
   * Go to **Node** ➡️ **System** ➡️ **Network** ➡️ double-click on `vmbr0`.
   * Check **VLAN Aware** ➡️ click **OK** ➡️ click **Apply Configuration**.
   * *This allows Proxmox to direct specific tagged VLAN traffic straight to individual LXC/VM virtual interfaces (`vnetX`).*
2. **Configure USW Switch Ports:**
   * Open the UniFi Network Controller.
   * Select your **USW Pro Max 16**. Go to the ports connected to **Bulakan** (Port 7/Bond) and **Cebu**.
   * Under **Port Manager**, set the Port Profile/Native Network to **VLAN 1** or **VLAN 10** (Management).
   * Ensure that **Traffic Restriction** is **Disabled** (meaning all tagged VLANs are allowed to trunk/pass through).

---

### 🔒 Phase 2: Isolating public-facing DMZ/External Services (VLAN 120)
*This is the highest security win with the lowest risk of breaking local inter-app workflows.*

1. **Define VLAN 120 on UniFi:**
   * Go to `Settings` ➡️ `Networks` ➡️ `New Network`.
   * **Name:** `ExternalServices` | **VLAN ID:** `120` | **Gateway IP/Subnet:** `VLAN 120 (DMZ)/24`.
   * Enable the **DHCP Server** on this VLAN.
2. **Migrate Cloudflared and Nginx Proxy Manager:**
   * In Proxmox Bulakan, shut down Nginx Proxy Manager (CT 502) and Cloudflared (CT 304).
   * Go to the container ➡️ **Hardware** ➡️ **Network Device (eth0)** ➡️ click **Edit**.
   * Enter **120** in the **VLAN Tag** field. Click **Save**.
   * Power on the container. It will automatically request a DHCP lease from the `192.168.120.x` subnet.
3. **Establish Initial Firewall Rules:**
   * *NPM and Cloudflared only need to talk outward to the internet and downward to your local reverse proxy targets (like Plex on VLAN 110). They do NOT need access to your Proxmox management or Synology interfaces.*
   * Create a firewall rule in UniFi (`Internet Local` / `LAN In`):
     * Allow **VLAN 120** ➡️ **Plex IP** on port `32400`.
     * Allow **VLAN 120** ➡️ **Jellyfin IP** on port `8096`.
     * Block **VLAN 120** ➡️ **VLAN 1 / VLAN 10** (Complete Management Isolation).

---

### 📺 Phase 3: The Services Zone Integration (VLAN 110)
*Migrating the Arr stack, Immich, and Plex. These apps need local communication with each other and fileserver mount access.*

1. **Define VLAN 110 on UniFi:**
   * **Name:** `InternalServices` | **VLAN ID:** `110` | **Gateway IP/Subnet:** `192.168.42.1/24`.
2. **Move Media Containers to VLAN 110:**
   * Add the `110` VLAN tag to the Network Device settings of Plex (CT 104), Sonarr (CT 106), Radarr (CT 105), Bazarr (CT 107), Transmission (CT 112), and Immich (VM 204).
   * Re-assign static IPs within the `192.168.42.x` range if desired, or let DHCP hand out mappings.
3. **Configure Storage Access across Boundaries (Synology / TrueNAS):**
   * *Storage servers (Synology PNAS and TrueNAS SCALE VM) should ideally live in the Management or a dedicated Storage VLAN for safety.*
   * To allow the media stack on VLAN 110 to mount ZFS/SMB shares on your storage nodes:
     * In UniFi, create a **Port Group** containing the SMB ports (`445`, `139`) and NFS ports (`2049`).
     * Create a **LAN In Rule**: Allow **VLAN 110** ➡️ **Storage IPs (TrueNAS `VLAN 1 (Mgmt)` / Synology `VLAN 1 [MGMT-NAS]`)** on the **Storage Port Group**.
     * Block all other general TCP/UDP access from the media stack to the storage web interfaces (ports `80`, `443`, `5001`, `81`).

---

### 🔌 Phase 4: IoT Smart Home Isolation (VLAN 30)
*Smart TVs, thermostats, cameras, and hubs represent high security risks and must be isolated.*

1. **Define VLAN 30 on UniFi:**
   * **Name:** `IoT` | **VLAN ID:** `30` | **Gateway IP/Subnet:** `192.168.30.1/24`.
2. **Broadcast Isolated Wireless Network:**
   * Create a new WiFi Network in UniFi.
   * **SSID:** `Sampaloc-IoT` | **Security:** WPA2-Personal | **Network:** select `IoT (VLAN 30)`.
   * Restrict to **2.4 GHz Band only** (for maximum smart-device compatibility).
3. **Lock Down IoT Access:**
   * Create a firewall rule blocking all traffic from **VLAN 30 (IoT)** ➡️ **All Other Subnets**.
   * *Smart bulbs and TVs can access the internet to pull updates but can never touch your NAS or hypervisors.*

---

### 👑 Phase 5: Hypervisor Management & Gateway Isolation (VLAN 10)
*Once all services and clients are placed in their respective zones, we restrict the management interface.*

1. **Establish the VLAN 10 Subnet:**
   * **Name:** `Management` | **VLAN ID:** `10` | **Gateway IP/Subnet:** `VLAN 10 (MGMT/SecOps)/24`.
2. **Map Switch ports & Hypervisor Interfaces:**
   * Move your Proxmox Bulakan/Cebu management IPs, UniFi Switch/AP IPs, and Synology DSM IP over to VLAN 10.
   * Update client configurations.
3. **Secure Inter-VLAN DNS (Crucial):**
   * Since your Pi-hole servers (`VLAN 1 [DNS-Secondary]` / `VLAN 1 (Mgmt)`) provide DNS for the entire cluster:
     * Create a rule: **Allow All Networks** ➡️ **Pi-Hole IPs** on Port `53` (UDP/TCP).
     * This guarantees that devices on VLAN 110, 120, and 30 can resolve external sites, even though they cannot touch other management services.

---

## 🔒 Standard UniFi Firewall Rules Layout

To enforce the segmentation, you must configure the rules under **UniFi Network ➡️ Settings ➡️ Security ➡️ Firewall Rules ➡️ LAN IN** in this specific sequence (stateful order of operations):

```
       LAN IN Traffic Ingress
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 1: Allow Established/Related │ ◄── Enables reply traffic to pass
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 2: Drop Invalid Connections  │ ◄── Prunes corrupted packets
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 3: Allow Inter-VLAN DNS (53) │ ◄── Allows all VLANs to query Pi-hole
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 4: Allow Trusted LAN (V20)   │ ◄── Allows your admin PC to access MGMT
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 5: Allow Media Storage (445) │ ◄── Allows VLAN 110 stack -> SMB shares
└─────────────────┬─────────────────┘
                  │
                  ▼
┌───────────────────────────────────┐
│ Rule 6: Drop RFC1918 Inter-VLAN   │ ◄── Blocks all other Inter-VLAN cross-talk!
└───────────────────────────────────┘
```

### 1. Standard "LAN IN" Firewall Rules Details

| Rule Name | Action | Source | Destination | Port/Protocol | Purpose |
|:---|:---:|:---|:---|:---:|:---|
| **Allow Established/Related** | `Accept` | Any | Any | Any | Permits active sessions to communicate backward |
| **Drop Invalid** | `Drop` | Any | Any | Any | Filters out malformed traffic |
| **Allow VLAN DNS** | `Accept` | Any | Pi-hole IPs | `53` (TCP/UDP) | Lets isolated subnets query your active DNS resolvers |
| **Allow Admin MGMT** | `Accept` | VLAN 20 (Trusted) | VLAN 10 (MGMT) | Any | Permits admin devices to access Proxmox, USW, and NAS GUIs |
| **Allow SMB Storage**| `Accept` | VLAN 110 (Services) | Storage IPs | `445` (TCP) | Connects your Plex and Arr stack to ZFS shared directories |
| **Block Inter-VLAN** | `Drop` | Any (RFC1918 Group) | Any (RFC1918 Group) | Any | The core rule that blocks all undefined traffic between subnets |

---

## 💡 Operational Best Practices & Safety

* **Take Proxmox Backups First:** Take snapshots and full backups of the container filesystems (`PBS` or locally) before changing bridge settings.
* **Keep a Failback Port:** Configure Port 16 (or any spare port) on the USW Switch to remain statically locked to **VLAN 1 / Native**. If you accidentally locked yourself out of Proxmox while configuring VLANs, you can plug your admin laptop directly into this port to regain immediate access.
* **Gradual DNS Transitions:** When migrating subnets, update the DHCP settings first to let clients naturally acquire lease mappings before severing older routes.

---

## 🔗 References
* [Network Subnet Indices](file:////opt/homelab-infrastructure/04-Network/Network%20Overview.md)
* [UniFi UCG Max Hardware Port Map](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
* [Active Proxmox Container List](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
