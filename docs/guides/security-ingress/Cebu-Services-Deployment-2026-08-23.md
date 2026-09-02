# 🚀 Deployment Guide: fail2ban, Tailscale, Grafana & Uptime Kuma on Proxmox Cebu

* **Date:** 2026-08-23
* **Objective:** Deploy, configure, and automate the lifecycle of fail2ban multi-tier IPS, Tailscale Subnet Router/Exit Node, Prometheus & Grafana Observability Dashboard with Proxmox PVE Exporter, and Uptime Kuma monitoring stack on the Cebu Proxmox node (`192.168.1.26`).
* **Author / Maintainer:** Perlas

---

## 1. Prerequisites & Design Summary

| Service | CT ID | VLAN Segment | IP Address | Primary Role & Ingress |
|:---|:---:|:---:|:---:|:---|
| **fail2ban-cebu** | 406 | VLAN 10 (SecOps) | `192.168.10.50` | Centralized Multi-Tier IPS Dashboard (`https://fail2ban.perlasarnold.me`) |
| **tailscale-cebu** | 407 | VLAN 1 (Mgmt) | `192.168.1.246` | Subnet Router + Exit Node (`https://login.tailscale.com/admin`) |
| **grafana-cebu** | 418 | VLAN 110 (Services) | `192.168.110.60` | Prometheus Metrics & PVE Exporter (`https://grafana.perlasarnold.me`) |
| **uptime-kuma-cebu** | 419 | VLAN 110 (Services) | `192.168.110.61` | Docker uptime monitor with 27 hosts (`https://kuma.perlasarnold.me`) |

---

## 2. Step 1: Provision LXC Containers via Terraform

```powershell
cd C:\Users\Perlas\Documents\Github\homelab\iac\terraform\proxmox
terraform validate
terraform apply -target=module.fail2ban_cebu -target=module.tailscale_cebu -target=module.grafana_cebu -target=module.uptime_kuma_cebu
```

---

## 3. Step 2: Configure & Provision via Ansible

```bash
cd iac/ansible
ansible-playbook cebu_services.yml \
  --extra-vars "tailscale_oauth_client_id=YOUR_ID tailscale_oauth_client_secret=YOUR_SECRET grafana_oauth_client_secret=YOUR_GRAFANA_SECRET"
```

---

## 4. Step 3: Telemetry & Observability Setup (Prometheus + PVE Exporter)

1. **Proxmox Cluster API Token:**
   ```bash
   pveum role add PVEAuditor -privs 'VM.Audit Sys.Audit Sys.Modify Datastore.Audit'
   pveum user add prometheus@pve -comment 'Prometheus PVE Exporter'
   pveum acl modify / -user prometheus@pve -role PVEAuditor
   pveum user token add prometheus@pve prom-token -privsep 0
   ```
2. **Install `prometheus-pve-exporter` on CT 418:** Runs on port `9221` and polls Proxmox cluster API.
3. **Install `prometheus-node-exporter` on All Hypervisors:** Runs on port `9100` on Bulakan, Cebu, and Dapitan.
4. **Provisioned Dashboards:**
   - `Perlas-Net Homelab Infrastructure Overview` (`/d/homelab-overview`)
   - `Proxmox Containers & VMs Drilldown` (`/d/proxmox-guests-drilldown`)

---

## 5. Step 4: Multi-Tier Intrusion Prevention (Fail2Ban)

1. **Perimeter (NPM CT 105):** Protects ingress via `nginx-4xx` and `authentik-auth` jails.
2. **Physical Hypervisors (Bulakan, Cebu, Dapitan):** Protects Port 22 (`sshd`) and Port 8006 (`proxmox` Web GUI).
3. **Lockout Protection:** `ignoreip` configured with `127.0.0.1/8`, `192.168.1.0/24`, `192.168.20.0/24`, `192.168.110.0/24`, and `100.64.0.0/10`.
4. **Central Dashboard:** Aggregates real-time metrics across all nodes at `https://fail2ban.perlasarnold.me`.

---

## 6. Step 5: Service Availability & Monitoring (Uptime Kuma)

* Deployed `louislam/uptime-kuma:1` container with `--network=host` on CT 419.
* Pre-configured **27 comprehensive monitors** across all hypervisors, NAS, DNS, gateways, and application services.

---

## 7. Rollback Procedures

If required, tear down individual resources cleanly:

```powershell
terraform destroy -target=module.fail2ban_cebu
terraform destroy -target=module.tailscale_cebu
terraform destroy -target=module.grafana_cebu
terraform destroy -target=module.uptime_kuma_cebu
```
