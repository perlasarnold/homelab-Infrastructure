# 🌐 Tailscale Mesh VPN & Subnet Router

* **Category:** Networking / Zero-Trust VPN
* **Node:** Cebu (`192.168.1.26`)
* **LXC ID:** CT 407
* **VLAN Segment:** VLAN 1 (Management)
* **IP Address:** `192.168.1.246`
* **Access Portal:** [Tailscale Admin Console](https://login.tailscale.com/admin)
* **Managed By:** Ansible (`roles/tailscale`) & Terraform (`cebu.tf`)

---

## 🎯 Architecture & Roles

1. **Subnet Router:** Advertises homelab CIDRs to the Tailnet:
   - `192.168.1.0/24` (VLAN 1 Default / Management)
   - `192.168.10.0/24` (VLAN 10 MGMT / SecOps)
   - `192.168.110.0/24` (VLAN 110 Services)
   - `192.168.120.0/24` (VLAN 120 DMZ)

2. **Exit Node:** Allows remote clients to securely route all external internet traffic out through the Cebu homelab WAN gateway.

3. **Authentication:** Uses Tailscale OAuth Clients for non-expiring headless node provisioning.

---

## 🔒 UniFi Firewall Requirements

To allow inter-VLAN routing for clients connecting through CT 407 (`192.168.1.246`), configure these **LAN IN** rules in UniFi:
* Accept from `192.168.1.246` to `192.168.110.0/24`
* Accept from `192.168.1.246` to `192.168.10.0/24`
* Accept from `192.168.1.246` to `192.168.120.0/24`
* Outbound UDP port 41641 enabled for WireGuard/Tailscale encapsulation.

---

## 🛠️ Management via Ansible

```bash
cd iac/ansible
ansible-playbook cebu_services.yml --tags tailscale --extra-vars "tailscale_oauth_client_id=... tailscale_oauth_client_secret=..."
```
