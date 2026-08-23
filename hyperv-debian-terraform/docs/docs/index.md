# Home

!!! success "One command to rule them all"
    **Proxmox:**
    ```bash
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/hyperv-debian-terraform/main/install.sh)"
    ```
    **Windows Hyper-V:**
    ```powershell
    irm https://raw.githubusercontent.com/YOUR_USER/hyperv-debian-terraform/main/install.ps1 | iex
    ```

## What is this?

A fully automated homelab infrastructure project. Run one command on a machine, and everything else — VM creation, OS configuration, Docker service deployment, updates, and monitoring — is handled by **GitHub Actions**.

```
Your Machine                      GitHub Actions
  ├── install.sh / install.ps1        ├── terraform-apply.yml   → creates VM
  │     sets up self-hosted runner    ├── ansible-bootstrap.yml → hardens + installs Docker
  │                                   ├── docker-deploy.yml     → deploys services
  │                                   ├── auto-remediation.yml  → runs hourly health checks
  │                                   └── scheduled-maintenance.yml → monthly updates
  │
  └── After setup: NEVER SSH in manually again.
```

## Hypervisors

| | Hyper-V | Proxmox |
|---|---|---|
| **Host OS** | Windows 10/11 Pro | Proxmox VE (bare metal) |
| **Bootstrap** | `install.ps1` (PowerShell) | `install.sh` (bash) |
| **Terraform** | `rgl/hyperv` + WinRM | `bpg/proxmox` + API token |
| **OS install** | Manual (Debian netinstall) | Automatic (cloud-init) |
| **Migrate to Proxmox?** | Change Terraform target — Docker/Ansible unchanged |

## Included Services

| Service | Purpose | Port |
|---|---|---|
| Portainer | Docker management UI | 9000 |
| Nginx Proxy Manager | Reverse proxy + SSL | 80/443/81 |
| Pi-hole | Network ad blocker | 8080/53 |
| Jellyfin | Media server | host |
| Nextcloud | Self-hosted cloud storage | 8081 |
| Grafana + Prometheus | Monitoring dashboards | 3000/9090 |
| Uptime Kuma | Uptime monitoring | 3001 |
| Vaultwarden | Password manager | 8083 |
| Immich | Photo backup | 2283 |
| Wiki.js | This documentation | 3005 |
| Guacamole | Browser SSH/RDP + TOTP MFA | 8085 |
| Cloudflare Tunnel | Public HTTPS access | — |
| Tailscale | Private mesh VPN | — |
| Jupyter Lab | On-demand analysis | 8888 |
