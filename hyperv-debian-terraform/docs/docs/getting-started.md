# Getting Started

This guide walks through the full setup from zero to a running homelab. Everything after the first bootstrap command is managed via GitHub Actions.

## Prerequisites

=== "Proxmox"
    - A desktop/server with Proxmox VE installed ([proxmox.com/downloads](https://www.proxmox.com/en/downloads))
    - Basic network setup: static IP assigned to the Proxmox host
    - Internet access from the Proxmox machine

=== "Hyper-V (Windows)"
    - Windows 10/11 Pro, Enterprise, or Education
    - Virtualization enabled in BIOS
    - Internet access

## Step 1 — Create a GitHub Repo

1. Fork or create a new repo from this template on GitHub
2. Name it whatever you like (e.g., `my-homelab`)

## Step 2 — Bootstrap the Machine

Run this from the machine that will host your VMs. It only needs to be run **once**.

=== "Proxmox"
    Open the Proxmox shell (host shell — not inside a VM):
    ```bash
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/REPO/main/install.sh)"
    ```
    The script will ask for:

    - Your GitHub repo URL
    - A runner registration token ([get it here](https://github.com/YOUR_USER/REPO/settings/actions/runners/new))
    - Your Proxmox API token ID and secret

=== "Windows Hyper-V"
    Open PowerShell **as Administrator**:
    ```powershell
    irm https://raw.githubusercontent.com/YOUR_USER/REPO/main/install.ps1 | iex
    ```

After the script completes, a **self-hosted GitHub Actions runner** is registered and running as a service. You will not need to touch this machine again.

## Step 3 — Generate SSH Key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab-actions"
```

Keep the private key secure. **Never commit it to the repo.**

## Step 4 — Add GitHub Secrets

Go to **your repo → Settings → Secrets and variables → Actions → New repository secret**.

=== "Proxmox"
    | Secret | Value |
    |---|---|
    | `PROXMOX_VE_ENDPOINT` | `https://YOUR_PROXMOX_IP:8006` |
    | `PROXMOX_VE_API_TOKEN` | `root@pam!terraform=YOUR_SECRET` |
    | `PROXMOX_NODE` | `pve` (your node name) |
    | `DEBIAN_SSH_PUBLIC_KEY` | contents of `~/.ssh/homelab_ed25519.pub` |
    | `DEBIAN_SSH_PRIVATE_KEY` | contents of `~/.ssh/homelab_ed25519` |
    | `DEBIAN_VM_USER` | `debian` |
    | `DEBIAN_VM_IP` | IP of the VM after creation |
    | `SOPS_AGE_KEY` | contents of your age private key |

=== "Hyper-V"
    | Secret | Value |
    |---|---|
    | `WINRM_USERNAME` | Your Windows username |
    | `WINRM_PASSWORD` | Your Windows password |
    | `WINRM_CACERT_B64` | Printed by `01_enable_hyperv_winrm.ps1` |
    | `DEBIAN_SSH_PRIVATE_KEY` | contents of `~/.ssh/homelab_ed25519` |
    | `DEBIAN_VM_USER` | `debian` |
    | `DEBIAN_VM_IP` | IP of the VM after creation |
    | `SOPS_AGE_KEY` | contents of your age private key |

## Step 5 — Create the VM (Terraform)

Push any change to `terraform/` on main, or trigger `terraform-apply.yml` manually:

**Actions → Terraform Apply → Run workflow**

=== "Proxmox"
    Terraform clones the Debian 12 cloud-init template. VM is ready in ~2 minutes with SSH key pre-installed. **No manual OS install needed.**

=== "Hyper-V"
    Terraform creates the VM shell. You need to:

    1. Open Hyper-V Manager → Connect to `debian-server`
    2. Complete Debian installation (select **SSH server**, no desktop)
    3. Note the VM's IP from `ip addr show`
    4. Update the `DEBIAN_VM_IP` secret

## Step 6 — Bootstrap the Debian VM (Ansible)

**Actions → Ansible Bootstrap VM → Run workflow** (select playbooks: `01,02,04`)

This runs:

1. `01_bootstrap.yml` — SSH hardening, UFW firewall, fail2ban
2. `02_install_docker.yml` — Official Docker Engine + Compose plugin
3. `04_maintenance.yml` — Installs cron jobs + Docker watchdog

## Step 7 — Deploy Services

**Actions → Docker Deploy → Run workflow** → pick a service from the dropdown.

Start with:

1. **portainer** — gives you a Docker web UI
2. **wikijs** — deploys this documentation on your server
3. **uptime-kuma** — monitor all your services

## Step 8 — Set Up Networking

See [Docker Services](docker-services.md) for port reference, then:

- **Tailscale**: deploy the `tailscale` container → access all services via Tailscale IP
- **Cloudflare Tunnel**: deploy `cloudflared` → expose selected services publicly via your domain

See [Remote Access](remote-access.md) for Guacamole browser SSH setup.

## You're Done

From this point forward, **all changes go through GitHub**:

- Edit a Terraform file → PR → plan comment → merge → VM updated
- Click Docker Deploy → choose service → deployed
- Auto-remediation runs every hour — it fixes itself
- Monthly maintenance runs automatically on the 1st of each month
