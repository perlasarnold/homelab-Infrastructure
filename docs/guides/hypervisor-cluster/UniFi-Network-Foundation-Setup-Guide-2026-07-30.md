# 🛡️ UniFi Network Foundation Setup Guide

* **Date:** 2026-07-30
* **Objective:** Establish the foundational Class C VLAN network architecture (`192.168.x.x /24`), switch port trunking, firewall groups, and isolated IoT wireless network on the UniFi Cloud Gateway Max (`Perlas-UnifiGW`) and USW Pro Max 16 switch with zero disruption to live production traffic.
* **Scope:** UniFi OS / Network Controller setup, 802.1Q switch trunking, declarative Terraform IaC code, and hardware break-glass failback reservation.
* **Maintainer:** Perlas

---

## 🎯 Target Architecture & Subnet Allocations

| VLAN ID | Name | Subnet Range | Gateway | DHCP Pool | Target Workloads & Purpose |
|:---:|:---|:---|:---|:---|:---|
| **10** | **MGMT** | `VLAN 10 (MGMT/SecOps)/24` | `VLAN 10 (MGMT/SecOps)` | `VLAN 10 (MGMT/SecOps) - 249` | Proxmox hypervisors, UniFi gateway, switches, APs, Synology DSM & TrueNAS web GUIs |
| **20** | **TRUSTED** | `VLAN 20 (Trusted)/24` | `VLAN 20 (Trusted)` | `VLAN 20 (Trusted) - 249` | Admin workstations (`Perlas-W10`), daily laptops, mobile devices |
| **30** | **IOT** | `192.168.30.0/24` | `192.168.30.1` | `192.168.30.100 - 249` | Home Assistant OS (`haos-17.3`), smart TVs, IoT sensors, cameras |
| **110** | **SERVICES** | `VLAN 110 (Services)/24` | `VLAN 110 (Services)` | `VLAN 110 (Services) - 249` | Internal homelab services (Plex, Jellyfin, Arr stack, Immich, Fileserver, Authentik) |
| **120** | **DMZ** | `VLAN 120 (DMZ)/24` | `VLAN 120 (DMZ)` | `VLAN 120 (DMZ) - 249` | Public ingress controllers (Cloudflared tunnels, Nginx Proxy Manager) |

---

## 📋 Steps Taken & Technical Rationale

### Step 1: Preemptive Virtual Network Creation
* **Action:** Created Virtual Network definitions in UniFi Network Controller (`Settings` ➡️ `Networks` ➡️ `New Network`) for VLANs 10, 20, 30, 110, and 120.
* **Rationale:** Establishes the gateway IP addresses on the UCG Max router without affecting active hosts on native VLAN 1 (`192.168.1.0/24`).

### Step 2: 802.1Q Switch Port Trunking Enablement
* **Action:** Configured Port Profiles on **USW Pro Max 16** (`Devices` ➡️ `Port Manager`) for Ports connected to hypervisor nodes:
  * **Bulakan** (Port 7 / Bond)
  * **Cebu** (Port 11)
  * **Dapitan** (Port 12)
  * **Native Network:** `Default (VLAN 1)`
  * **Tagged VLAN Management:** Set to **Allow All** (`Traffic Restriction` disabled).
* **Rationale:** Ensures untagged `192.168.1.x` management traffic continues to flow while enabling Proxmox virtual bridges (`vmbr0`) to trunk tagged VLAN traffic as containers and VMs are migrated.

### Step 3: Firewall Group Staging
* **Action:** Created stateful Firewall Groups in UniFi (`Settings` ➡️ `Security` ➡️ `Firewall Rules` ➡️ `IP/Port Groups`):
  * **IP Group `RFC1918 Private Subnets`:** `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`
  * **IP Group `Storage Hosts`:** Synology (`VLAN 1 [MGMT-NAS]`, `.13`) & TrueNAS (`VLAN 1 (Mgmt)`)
  * **IP Group `DNS Resolvers`:** Pi-hole Primary (`VLAN 1 [DNS-Secondary]` / `VLAN 110 (Services)`) & Secondary (`VLAN 1 (Mgmt)` / `VLAN 110 (Services)`)
  * **Port Group `Storage Shares`:** `445` (SMB), `139` (NetBIOS), `2049` (NFS)
  * **Port Group `DNS Ports`:** `53` (UDP/TCP)
* **Rationale:** Pre-positions security objects required for stateful inter-VLAN firewall policies without locking down access prematurely.

### Step 4: Isolated IoT Wireless Network (`Sampaloc-IoT`)
* **Action:** Created a new Wireless Network SSID (`Settings` ➡️ `WiFi` ➡️ `Add New WiFi Network`):
  * **SSID:** `Sampaloc-IoT`
  * **VLAN Mapping:** `IOT (VLAN 30)`
  * **Bands:** 2.4 GHz only
* **Rationale:** Restricts smart home equipment to 2.4 GHz WiFi mapped directly to isolated VLAN 30, preventing wireless IoT devices from communicating with hypervisors or storage web interfaces.

### Step 5: Failback Out-of-Band Hardware Port Lock
* **Action:** Configured Switch Port 15 on **USW Pro Max 16**:
  * **Native Network:** Strictly locked to `Default (VLAN 1)`
  * **Tagged Traffic:** `Block All`
  * **Label:** `FAILBACK-ADMIN-PORT`
* **Rationale:** Provides guaranteed physical break-glass access to native `192.168.1.x` network for admin laptops if a misconfiguration ever isolates hypervisor management.

### Step 6: Terraform Infrastructure as Code Setup
* **Action:** Created declarative UniFi Terraform module files under `terraform/unifi/`:
  * `main.tf`: Declaratively defines networks, WLAN, and firewall groups.
  * `variables.tf`: Parameterizes controller URL, credentials, site, and CIDRs.
* **Rationale:** Ensures the UniFi network foundation can be tracked, validated, and deployed reproducibly via Infrastructure as Code.

---

## 📊 Outcome & Verification

1. **Zero Disruption Verified:** Active production services on `192.168.1.x` (Plex, Pi-hole, Cloudflared, Synology NAS) experienced zero interruption during network staging.
2. **Switch Trunking Verified:** USW Pro Max 16 ports 9 (Bulakan), 14 (Cebu), and 4 (Dapitan) carry untagged VLAN 1 native traffic alongside tagged VLANs 10, 20, 30, 110, and 120.
3. **Hypervisor VLAN Awareness:** Proxmox nodes **Bulakan**, **Cebu**, and **Dapitan** have successfully enabled `VLAN aware` on `vmbr0` (`bridge-vlan-aware yes`).
4. **DMZ Ingress Isolation:** Primary `cloudflared` (Bulakan CT 304 — `VLAN 120 (DMZ)`), secondary `cloudflared-cebu` (Cebu CT 404 — `VLAN 120 (DMZ)`), and Nginx Proxy Manager instances are active in **DMZ (VLAN 120)**.
5. **Services Zone Integration:** Primary `immich-dapitan` (Dapitan CT 504 — `VLAN 110 (Services)`) is active in **SERVICES (VLAN 110)** with verified external Cloudflare Tunnel routing.
6. **Failback Access Verified:** Switch Port 12 is isolated as native VLAN 1 emergency administrative failback (`FAILBACK-ADMIN-PORT`).
7. **Documentation & IaC Alignment:** UniFi Router Setup, Network Overview, and Terraform configuration files match the Class C 5-VLAN specification.




---

## 🔄 Rollback Plan

If switch port trunking or network definitions affect any live device:
1. Open UniFi Network Controller (`https://VLAN 1 [Gateway]`).
2. Go to **Devices** ➡️ **USW Pro Max 16** ➡️ **Port Manager**.
3. Select the affected port and set **Traffic Restriction** to **Block All** or restore to single untagged Native VLAN 1.
4. If web access to UniFi is lost, plug admin workstation directly into **Port 15** (`FAILBACK-ADMIN-PORT`) to regain immediate untagged access on `192.168.1.x`.

---

## 🔗 References

* [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
* [UniFi Preemptive Foundation Setup Guide](file:////opt/homelab-infrastructure/04-Network/UniFi-Preemptive-Foundation-Setup.md)
* [UniFi Router & Network Setup](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
* [Network Overview](file:////opt/homelab-infrastructure/04-Network/Network%20Overview.md)
* [Cebu Proxmox Node VLAN Migration Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-VLAN-Migration-Guide-2026-07-30.md)
