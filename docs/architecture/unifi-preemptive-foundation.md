# 🛡️ UniFi Preemptive Foundation Setup Guide

* **Date:** 2026-07-30
* **Objective:** Lay the foundational configuration in the UniFi Cloud Gateway Max (`Perlas-UnifiGW`) and USW Pro Max 16 switch for the new Class C VLAN schema (`192.168.x.x /24`) with **zero disruption** to existing live production traffic.
* **Scope:** UniFi OS / Network Controller setup, 802.1Q port trunking, IP/Port group staging, IoT Wi-Fi SSID, and hardware failback preservation.
* **Maintainer:** Perlas

---

## ⚡ Preemptive Actions (Zero Downtime Summary)

| Step | Action | UniFi Navigation Path | Production Risk |
|:---:|:---|:---|:---:|
| **1** | Define Subnet VLANs (10, 20, 30, 110, 120) | `Settings` ➡️ `Networks` ➡️ `New Network` | **Zero Risk** |
| **2** | Enable 802.1Q Trunking on Hypervisor Ports | `Devices` ➡️ `USW Pro Max 16` ➡️ `Port Manager` | **Zero Risk** |
| **3** | Create Preemptive Firewall Groups | `Settings` ➡️ `Security` ➡️ `Firewall Rules` ➡️ `IP/Port Groups` | **Zero Risk** |
| **4** | Broadcast Isolated IoT Wi-Fi (`Sampaloc-IoT`) | `Settings` ➡️ `WiFi` ➡️ `Create New Network` | **Zero Risk** |
| **5** | Reserve Untagged Hardware Failback Port | `Devices` ➡️ `USW Pro Max 16` ➡️ Port 15 | **Zero Risk** |

---

## 🛠️ Step-by-Step Implementation Instructions

### Step 1: Create Virtual Networks (VLAN Subnets)
In UniFi Network Console, go to **Settings ➡️ Networks ➡️ Add New Network**:

1. **`MGMT` (Management Zone)**
   * **VLAN ID:** `10`
   * **Gateway IP/Subnet:** `VLAN 10 (SecOps)/24`
   * **DHCP Range:** `VLAN 10 (SecOps) - VLAN 10 (SecOps)`
2. **`TRUSTED` (Admin Workstations)**
   * **VLAN ID:** `20`
   * **Gateway IP/Subnet:** `VLAN 20 (Trusted)/24`
   * **DHCP Range:** `VLAN 20 (Trusted) - VLAN 20 (Trusted)`
3. **`IOT` (Smart Home & Devices)**
   * **VLAN ID:** `30`
   * **Gateway IP/Subnet:** `VLAN 30 [Gateway]/24`
   * **DHCP Range:** `VLAN 30 (IoT) - VLAN 30 (IoT)`
4. **`SERVICES` (Internal Applications)**
   * **VLAN ID:** `110` *(or `42` if retaining legacy `VLAN 110 (Services)/24`)*
   * **Gateway IP/Subnet:** `VLAN 110 (Services)/24`
   * **DHCP Range:** `VLAN 110 (Services) - VLAN 110 (Services)`
5. **`DMZ` (Public Facing Ingress)**
   * **VLAN ID:** `120`
   * **Gateway IP/Subnet:** `VLAN 120 (DMZ)/24`
   * **DHCP Range:** `VLAN 120 (DMZ) - VLAN 120 (DMZ)`

> [!NOTE]
> Creating these networks defines the subnet gateway IPs on the gateway router. It does **not** force existing devices off VLAN 1 until switch ports or virtual interfaces are tagged.

---

### Step 2: Configure 802.1Q Switch Port Trunking
In UniFi Network Console, go to **Devices ➡️ USW Pro Max 16 ➡️ Port Manager**:

1. Select ports connected to hypervisor nodes:
   * **Bulakan** (Port 7 / Bond)
   * **Cebu** (Port connected to `VLAN 1 [Management]`)
   * **Dapitan** (Port connected to `VLAN 1 [Management]`)
2. Configure Port Settings:
   * **Native Network (Untagged):** `Default (VLAN 1)` *(remains active for current host IPs)*
   * **Tagged VLAN Management / Traffic Restriction:** Set to **Allow All** (or check VLANs 10, 20, 30, 110, 120).
3. Click **Apply Changes**.

> [!TIP]
> This allows untagged traffic to continue running on `192.168.1.x` while permitting Proxmox LXCs and VMs to send tagged 802.1Q traffic immediately as they are migrated.

---

### Step 3: Pre-Create Firewall Groups (IP & Port Groups)
In UniFi Network Console, go to **Settings ➡️ Security ➡️ Firewall ➡️ Groups**:

1. **IP Group: `RFC1918 Private Subnets`**
   * Types: IPv4 Subnet / CIDR
   * Addresses: `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`
2. **IP Group: `Storage Hosts`**
   * Addresses: `VLAN 1 [Management]`, `VLAN 1 [Management]`, `VLAN 1 (Management)`, `VLAN 10 (SecOps)`, `VLAN 10 (SecOps)`
3. **IP Group: `DNS Resolvers`**
   * Addresses: `VLAN 1 [Secondary DNS]`, `VLAN 1 (Management)`, `VLAN 110 (Services)`, `VLAN 110 (Services)`
4. **Port Group: `Storage Shares`**
   * Ports: `445` (SMB), `139` (NetBIOS), `2049` (NFS)
5. **Port Group: `DNS`**
   * Ports: `53` (UDP/TCP)

---

### Step 4: Broadcast Isolated IoT Wi-Fi (`Sampaloc-IoT`)
In UniFi Network Console, go to **Settings ➡️ WiFi ➡️ Add New WiFi Network**:

* **Name (SSID):** `Sampaloc-IoT`
* **Password:** *[Secure WPA2 Password]*
* **Network:** Select **`IOT (VLAN 30)`**
* **Advanced Configuration:** Manual ➡️ **Broadcasting Bands:** Select **2.4 GHz only**
* Click **Apply Changes**.

---

### Step 5: Reserve Hardware Failback Access Port
In UniFi Network Console, select **USW Pro Max 16 ➡️ Port 15**:

* **Native Network:** Lock strictly to **`Default (VLAN 1)`**.
* **Traffic Restriction:** Block All Tagged VLANs.
* **Label:** `FAILBACK-ADMIN-PORT`

> [!IMPORTANT]
> If a configuration error ever breaks Proxmox web access over VLANs, plugging an admin laptop directly into Port 15 guarantees instant untagged access to `192.168.1.x`.

---

## 🔗 Related Documentation

* [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
* [UniFi Router & Network Setup](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
* [Cebu Proxmox Node VLAN Migration Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-VLAN-Migration-Guide-2026-07-30.md)
