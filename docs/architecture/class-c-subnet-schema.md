# 🌐 Class C Subnet & IP Allocation Schema Recommendation

* **Date:** 2026-07-30
* **Objective:** Define a standardized, scalable Class C (`192.168.x.x /24`) network and IP allocation schema across the Homelab-Net homelab infrastructure (UniFi Cloud Gateway Max, USW Pro Max 16 Switch, and Proxmox cluster nodes: Bulakan, Cebu, and Dapitan).
* **Scope:** IP range conventions, VLAN mapping, service static assignments, DHCP pools, and stateful inter-VLAN firewall rules.
* **Maintainer:** Perlas

---

## 📐 Overall Network Subnet Architecture

Aligning the third octet of each Class C subnet with its corresponding **VLAN ID** creates a predictable, human-readable scheme:

| VLAN ID | Name | Subnet Range | Gateway | Target Workloads & Purpose |
|:---:|:---|:---|:---|:---|
| **10** | **MGMT** | `192.168.10.0/24` | `192.168.10.1` | Hypervisor hosts (Proxmox VE), UniFi gateway, switches, APs, Synology DSM & TrueNAS management interfaces |
| **20** | **TRUSTED** | `192.168.20.0/24` | `192.168.20.1` | Primary admin workstations, daily laptops, mobile devices, admin desktop (`Perlas-W10`) |
| **30** | **IOT** | `192.168.30.0/24` | `192.168.30.1` | Home Assistant OS (`haos-17.3`), smart TVs, IoT sensors, smart plugs, cameras |
| **40** | **STORAGE** *(Optional)* | `192.168.40.0/24` | `192.168.40.1` | High-speed dedicated storage traffic (NFS / SMB / iSCSI inter-node replication) |
| **110** | **SERVICES** | `192.168.110.0/24` *(or `192.168.42.0/24`)* | `192.168.110.1` | Internal applications (Plex, Jellyfin, Arr stack, Immich, Fileservers, Authentik) |
| **120** | **DMZ / EXTERNAL** | `192.168.120.0/24` | `192.168.120.1` | Public ingress controllers (Cloudflared tunnels, Nginx Proxy Manager) |

---

## 🔢 Predictable Host Octet Allocation Convention

Enforce a standardized host octet convention across all subnets for easy troubleshooting and maintenance:

```
 192.168. [VLAN] . [HOST]
                    │
                    ├── .1          --> Default Gateway (UniFi Cloud Gateway Max)
                    ├── .2 - .9     --> Core Network Infrastructure & DNS Resolvers (Pi-hole)
                    ├── .10 - .19   --> Physical & Virtual Storage Nodes (Synology / TrueNAS)
                    ├── .20 - .29   --> Proxmox Hypervisor Host Management Interfaces
                    ├── .30 - .99   --> Static Service IP Allocations (Containers & VMs)
                    ├── .100 - .249 --> Dynamic DHCP Pool for Client Leases
                    └── .250 - .254 --> Out-of-Band / Break-Glass Emergency Management
```

---

## 📋 Detailed Subnet Breakdown & Host Assignments

### 1. VLAN 10 — Management (`192.168.10.0/24`)
*Dedicated exclusively to hypervisor hosts, switches, and core storage web interfaces.*

| IP Address | Hostname / Device | Hardware / Platform | Notes |
|:---|:---|:---|:---|
| `192.168.10.1` | `Perlas-UnifiGW` | UniFi Cloud Gateway Max | Subnet Default Gateway |
| `192.168.10.12` | `PNAS` | Synology NAS | Storage Web DSM Interface |
| `192.168.10.13` | `PNAS2` | Synology NAS 2 | Storage Web DSM Interface |
| `192.168.10.15` | `TrueNAS-SCALE` | TrueNAS SCALE (Cebu VM 120) | Storage Web Interface |
| `192.168.10.25` | `Bulakan` | Proxmox VE Node 1 | Primary Node Host Management (PVE GUI / SSH) |
| `192.168.10.26` | `Cebu` | Proxmox VE Node 2 | Node Host Management (PVE GUI / SSH) |
| `192.168.10.27` | `Dapitan` | Proxmox VE Node 3 | Node Host Management (PVE GUI / SSH) |
| `192.168.10.141` | `USW-Pro-Max-16` | UniFi 16-Port Switch | Switch Management IP |
| `192.168.10.124` | `U7-Pro-AP` | UniFi WiFi 7 AP | Access Point Management IP |
| `192.168.10.200-249` | *DHCP Pool* | DHCP Range | Admin temporary maintenance leases |

---

### 2. VLAN 110 — Internal Homelab Services (`192.168.110.0/24` or `192.168.42.0/24`)
*Internal application servers, media platforms, indexers, and DNS resolvers.*

| IP Address | Service / Hostname | Node / Location | Purpose |
|:---|:---|:---|:---|
| `192.168.110.1` | Gateway | UniFi UCG Max | Subnet Gateway |
| `192.168.110.5` | `pihole-primary` | Bulakan (CT 301) | Primary DNS Sinkhole |
| `192.168.110.6` | `pihole-secondary` | Cebu (CT 401) | Secondary DNS Sinkhole |
| `192.168.110.41` | `jellyfin-cebu` | Cebu (CT 416) | Media Server |
| `192.168.110.42` | `arr-stack-cebu` | Cebu (CT 417) | Sonarr/Radarr/Prowlarr/Bazarr |
| `192.168.110.43` | `jellyfin-dapitan` | Dapitan (CT 510) | Media Server (Dapitan) |
| `192.168.110.44` | `plex-dapitan` | Dapitan (CT 509) | Media Server (Dapitan) |
| `192.168.110.54` | `plex-bulakan` | Bulakan (CT 104) | Media Server (Bulakan) |
| `192.168.110.71` | `torrent-box-dapitan` | Dapitan (CT 501) | Ubuntu GUI Torrent Box |
| `192.168.110.147` | `immich` | Dapitan (CT 504) | Photo Management Server |
| `192.168.110.48` | `photoview-dapitan` | Dapitan (CT 511) | Photoview Photo Gallery |
| `192.168.110.214` | `fileserver` | Cebu (CT 402/214) | Local Data Sharing LXC |
| `192.168.110.215` | `plex-cebu` | Cebu (CT 405) | Media Server (Cebu) |
| `192.168.110.225` | `authentik` | Cebu (CT 103) | Identity Provider & SSO |

---

### 3. VLAN 120 — Public DMZ / External (`192.168.120.0/24`)
*Publicly exposed proxy services and secure ingress tunnels.*

| IP Address | Service / Hostname | Location | Purpose |
|:---|:---|:---|:---|
| `192.168.120.1` | Gateway | UniFi UCG Max | Subnet Gateway |
| `192.168.120.6` | `cloudflared-bulakan` | Bulakan (CT 304) | Primary Cloudflare Tunnel |
| `192.168.120.7` | `cloudflared-cebu` | Cebu (CT 404) | Secondary Cloudflare Tunnel (ACTIVE) |
| `192.168.120.211` | `npm-proxy` | Cebu (CT 105) | Nginx Proxy Manager SSL Proxy (Active) |

---

### 4. VLAN 30 — Smart Home & IoT (`192.168.30.0/24`)
*Smart home hub, IoT sensors, cameras, and smart TVs.*

| IP Address | Service / Hostname | Location | Purpose |
|:---|:---|:---|:---|
| `192.168.30.1` | Gateway | UniFi UCG Max | Subnet Gateway |
| `192.168.30.11` | `haos-17.3` | Cebu (VM 111) | Home Assistant OS |
| `192.168.30.100-249` | *DHCP Pool* | Wireless AP (`Sampaloc-IoT`) | Smart plugs, TVs, wireless sensors |

---

## 🔒 UniFi Firewall Rules Sequence (LAN IN)

To enforce isolation between these Class C subnets, configure **UniFi Network ➡️ Settings ➡️ Security ➡️ Firewall Rules (LAN IN)** in this exact stateful order:

1. **Allow Established & Related:**
   - *Action:* Accept | *Source:* Any | *Destination:* Any | *State:* Established, Related
   - *Rationale:* Ensures response traffic can return across subnet boundaries.

2. **Allow Inter-VLAN DNS (Port 53):**
   - *Action:* Accept | *Source:* Any | *Destination:* Pi-hole IPs (`192.168.110.5`, `192.168.110.6`) | *Port:* `53` (UDP/TCP)
   - *Rationale:* Permits all isolated subnets (Services, DMZ, IoT) to resolve DNS via Pi-hole.

3. **Allow Trusted Admin to Management:**
   - *Action:* Accept | *Source:* VLAN 20 (Trusted) | *Destination:* VLAN 10 (MGMT) | *Port:* Any
   - *Rationale:* Allows admin devices to access Proxmox PVE GUIs, switch consoles, and NAS administration.

4. **Allow Media Services to Storage (SMB / NFS):**
   - *Action:* Accept | *Source:* VLAN 110 (Services) | *Destination:* Storage IPs (`192.168.10.12`, `192.168.10.15`) | *Ports:* `445` (SMB), `2049` (NFS)
   - *Rationale:* Connects media apps (Plex, Jellyfin, Arr stack) to ZFS/CIFS pools without granting full storage admin access.

5. **Block DMZ Access to Internal Network:**
   - *Action:* Drop | *Source:* VLAN 120 (DMZ) | *Destination:* VLAN 10 (MGMT) & VLAN 20 (TRUSTED)
   - *Rationale:* Prevents a compromised reverse proxy from pivoting to hypervisors or admin PCs.

6. **Drop Inter-VLAN Cross-Talk (RFC1918 Block):**
   - *Action:* Drop | *Source:* RFC1918 Group (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`) | *Destination:* RFC1918 Group
   - *Rationale:* The catch-all default drop rule preventing unauthorized inter-subnet traffic.

---

## 🔗 Related Documentation

* [Homelab VLAN Segmentation & Migration Roadmap](file:////opt/homelab-infrastructure/06-Guides/VLAN-Segmentation-Roadmap.md)
* [Cebu Proxmox Node VLAN Migration Guide](file:////opt/homelab-infrastructure/06-Guides/Cebu-VLAN-Migration-Guide-2026-07-30.md)
* [Network Overview](file:////opt/homelab-infrastructure/04-Network/Network%20Overview.md)
* [UniFi Router & Network Setup](file:////opt/homelab-infrastructure/04-Network/UniFi%20Router%20Setup.md)
* [Services Master Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
