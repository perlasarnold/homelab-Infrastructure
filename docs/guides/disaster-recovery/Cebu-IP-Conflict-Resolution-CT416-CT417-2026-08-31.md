# 🔍 Proxmox Cluster IP Collision Resolution Runbook (CT 416 & CT 417)

- **Date:** 2026-08-31
- **Objective:** Diagnose and resolve inter-VLAN connection refusal (`ECONNREFUSED`) affecting Homepage widgets, identify the duplicate IP assignment on VLAN 110 between CT 416 (Standby Jellyfin) and CT 417 (Arr Stack), reallocate CT 416 to `192.168.110.46`, and restore cluster routing.
- **Maintainer:** Homelab Admin

---

## 🔍 Problem Statement
On 2026-08-31, the Homepage dashboard (`home.perlasarnold.me` on Bulakan CT 116) displayed `API Error Information` badges for **Sonarr** and **qBittorrent**.
- **Container Logs:** `Error: connect ECONNREFUSED 192.168.110.42:8989` and `ECONNREFUSED 192.168.110.42:8080`.
- **Symptom:** ICMP ping to `192.168.110.42` succeeded in 0.3ms, but all TCP ports on `192.168.110.42` failed immediately with `Connection refused`.

---

## 🔬 Root Cause Investigation

### 1. ARP Cache Inspection on Homepage Host (CT 116)
Checking the neighbor table via `ip neigh` showed:
```bash
192.168.110.42 dev eth0 lladdr bc:24:11:50:de:fa REACHABLE
```

### 2. Proxmox Cluster MAC Audit
Searching all container network configurations in `/etc/pve/nodes/` revealed an IP collision:
* `/etc/pve/nodes/cebu/lxc/416.conf`: `hwaddr=BC:24:11:50:DE:FA, ip=192.168.110.42/24` (Standby Jellyfin)
* `/etc/pve/nodes/cebu/lxc/417.conf`: `hwaddr=BC:24:11:83:E9:0B, ip=192.168.110.42/24` (Arr Stack)

CT 416 and CT 417 were both configured with the same static IP address (`192.168.110.42`). CT 416 answered ARP requests from CT 116, intercepting traffic destined for Sonarr and qBittorrent and rejecting the connections.

---

## 🛠️ Resolution Applied

### Step 1: Reassign CT 416 (Standby Jellyfin)
Audited the `192.168.110.0/24` subnet schema. Allocated the clean, unassigned IP `192.168.110.46/24`:
```bash
pct set 416 -net0 name=eth0,bridge=vmbr0,gw=192.168.110.1,hwaddr=BC:24:11:50:DE:FA,ip=192.168.110.46/24,tag=110,type=veth
pct reboot 416
```

### Step 2: Flush Stale ARP Cache on Homepage Host (CT 116)
```bash
pct exec 116 -- ip neigh flush all
```

### Step 3: Restart Homepage Container
```bash
pct exec 116 -- docker restart homepage
```

---

## ✅ Verification
- `curl -I http://192.168.110.42:8989/` from CT 116: `HTTP 401 Unauthorized` (Sonarr reachable).
- `curl -I http://192.168.110.42:8080/` from CT 116: `HTTP 200 OK` (qBittorrent reachable).
- Homepage dashboard at [https://home.perlasarnold.me](https://home.perlasarnold.me) shows live real-time statistics with **0 API errors**.
