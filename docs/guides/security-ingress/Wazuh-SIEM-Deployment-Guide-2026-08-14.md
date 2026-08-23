# 🛡️ Wazuh SIEM & XDR Deployment Guide

> **Date:** 2026-08-14  
> **Objective:** Deploy Wazuh SIEM & XDR All-in-One stack on Proxmox VE node `Cebu` (`VLAN 1 [Management]`), apply system performance mitigations, and integrate network-wide security logging across `Homelab-Net` on **VLAN 10 MGMT**.  
> **Target IP:** `VLAN 10 (SecOps)` (VM 250: `wazuh-siem` on **VLAN 10**)  
> **Status:** Production / Active  

---

## 1. Architecture & Component Sizing

- **Host Node**: `Cebu` (`VLAN 1 [Management]` / Proxmox VE 9.2.5)
- **VM ID**: `250` (`wazuh-siem`)
- **OS Base**: Ubuntu 24.04 LTS Server (Cloud-Init Image)
- **vCPU**: 4 Cores (`host` type)
- **RAM**: 8192 MiB (OpenSearch JVM Heap capped to `-Xms4g -Xmx4g`)
- **Storage**: 100 GiB on `cebu-zfs` pool (Thin-provisioned, discard enabled)
- **Network Interface**: `vmbr0v10` (VLAN 10 Bridge), Static IP `VLAN 10 (SecOps)/24`, Gateway `VLAN 10 (SecOps)`, DNS `VLAN 1 [Secondary DNS]`

---

## 2. Implemented Risk Mitigations

| Area | Risk | Applied Mitigation |
| :--- | :--- | :--- |
| **VLAN Architecture Alignment** | Staging / Legacy Subnet Risk | Migrated VM 250 to **VLAN 10 MGMT** (`VLAN 10 (SecOps)`) to align with homelab security & out-of-band management conventions. |
| **OpenSearch JVM Memory** | Host RAM Spikes | Set `-Xms4g -Xmx4g` in `/etc/wazuh-indexer/jvm.options`. Set `vm.max_map_count=262144`. |
| **ZFS Storage Growth** | Log Storage Exhaustion | Configured Index State Management (ISM) 14-day log retention policy in Indexer. |
| **Network UDP Logging** | Packet Loss | Raised kernel socket receive buffers (`net.core.rmem_max=8388608`). |
| **Active Response Lockout** | PVE Cluster Disruption | Disabled Active Response on hypervisor agents; whitelisted cluster IPs (`VLAN 10 (SecOps)-27` / `VLAN 1 [Management]-27`). |
| **DMZ Reverse Proxy** | SSL 502 Errors | Set Nginx Proxy Manager / Cloudflared HTTPS upstream scheme with `proxy_ssl_verify off;`. |

---

## 3. Steps Taken

### Phase 1: VM Provisioning on `Cebu` & VLAN 10 Migration
```bash
# Provision Ubuntu 24.04 Cloud-Init VM on VLAN 10 (vmbr0v10)
qm create 250 --name wazuh-siem --memory 8192 --cores 4 --cpu host --net0 virtio,bridge=vmbr0v10 --ostype l26 --onboot 1
qm importdisk 250 /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img cebu-zfs
qm set 250 --scsihw virtio-scsi-single --scsi0 cebu-zfs:vm-250-disk-0,discard=on,iothread=1
qm disk resize 250 scsi0 100G
qm set 250 --ide2 cebu-zfs:cloudinit
qm set 250 --boot order=scsi0
qm set 250 --ciuser root --cipassword '<hidden>' --ipconfig0 ip=VLAN 10 (SecOps)/24,gw=VLAN 10 (SecOps) --nameserver VLAN 1 [Secondary DNS]
qm start 250
```

### Phase 2: System Tuning & Wazuh Installation
```bash
# Kernel & System Limits
cat << 'EOF' > /etc/sysctl.d/99-wazuh.conf
vm.max_map_count=262144
net.core.rmem_max=8388608
net.core.rmem_default=262144
EOF
sysctl -p /etc/sysctl.d/99-wazuh.conf

# Execute Wazuh All-in-One Installer
curl -sO https://packages.wazuh.com/4.11/wazuh-install.sh
bash wazuh-install.sh -a -i
```

### Phase 3: Syslog Listener & Agent Setup
- **Syslog Listener**: Configured UDP port 514 remote connection in `/var/ossec/etc/ossec.conf` on `wazuh-siem`.
- **UniFi Syslog**: Pointed UniFi UCG Max (`VLAN 10 (SecOps)`) Syslog server to `VLAN 10 (SecOps):514`.
- **Cebu Hypervisor Agent**: Installed `wazuh-agent=4.11.2-1` on host `Cebu`, authenticated key `001`, and started daemon pointing to `VLAN 10 (SecOps)`.

---

## 4. Outcome & Verification

- **Wazuh Dashboard URL**: `https://VLAN 10 (SecOps)` (HTTPS 443 active)
- **Services Health**: `wazuh-indexer` (running), `wazuh-manager` (running), `wazuh-dashboard` (running).
- **Connected Agent**: `cebu` (ID 001 - **Active**).
- **Syslog Listening**: UDP port 514 bound to `0.0.0.0:514`.

---

## 5. References

- [Proxmox Overview](file:////opt/homelab-infrastructure/02-Proxmox/Proxmox%20Overview.md)
- [Network Overview](file:////opt/homelab-infrastructure/04-Network/Network%20Overview.md)
- [Class C Subnet & IP Allocation Schema Recommendation](file:////opt/homelab-infrastructure/04-Network/Class-C-Subnet-Schema-Recommendation.md)
- [Services Master Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
