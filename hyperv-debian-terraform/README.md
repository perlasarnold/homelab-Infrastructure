# Hyper-V Debian via Terraform + GitHub Actions

A learning project that provisions a **Debian 12 (Bookworm) VM in Windows Hyper-V** using the [`rgl/hyperv`](https://registry.terraform.io/providers/rgl/hyperv/latest) Terraform provider, automated through a **self-hosted GitHub Actions runner** on the Windows host.

```
GitHub Actions (PR/push)
        │
        │  runs on self-hosted runner (your Windows machine)
        ▼
Terraform (rgl/hyperv provider)
        │
        │  WinRM HTTPS → localhost:5986
        ▼
Windows Hyper-V → Debian Server VM
```

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| Windows 10/11 Pro or Enterprise | Hyper-V host | — |
| Hyper-V feature | Virtualisation | `setup\01_enable_hyperv_winrm.ps1` |
| Terraform ≥ 1.5 | IaC | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| Git | Version control | [git-scm.com](https://git-scm.com/download/win) |
| GitHub account + repo | CI/CD | [github.com](https://github.com) |

---

## First-Time Setup (run once, in order)

### Step 1 — Enable Hyper-V and configure WinRM HTTPS

```powershell
# Run PowerShell as Administrator
cd C:\Github\hyperv-debian-terraform\setup
.\01_enable_hyperv_winrm.ps1
```

This will:
- Enable the Hyper-V Windows feature (reboot if prompted)
- Start and configure WinRM with HTTPS on port 5986
- Create a self-signed TLS certificate
- Export the cert as `setup\winrm_cacert.pem`
- Print the base64 value you'll need for the `WINRM_CACERT_B64` GitHub secret

> **If a reboot was needed**, re-run the script after restarting.

### Step 2 — Download Debian 12 ISO

```powershell
.\02_download_debian_iso.ps1
# Downloads to C:\ISOs\debian-12-amd64-netinst.iso (~700 MB) and verifies checksum
```

### Step 3 — Configure Terraform

```powershell
cd C:\Github\hyperv-debian-terraform\terraform
Copy-Item terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars   # Fill in winrm_username, winrm_password
```

Test locally:

```powershell
terraform init
terraform validate
terraform plan
```

### Step 4 — Apply Terraform (creates the VM)

```powershell
terraform apply
```

This creates the VM in Hyper-V Manager. The Debian ISO is attached and boot order set to DVD first.

### Step 5 — Install Debian (manual, one-time)

1. Open **Hyper-V Manager** → find `debian-server` → **Connect**
2. Follow the Debian installer prompts:
   - Choose **Guided – use entire disk**
   - **Uncheck** all desktop environments; **check** `SSH server` and `standard system utilities`
   - Set root password and create a user
3. After installation completes and the VM reboots → log in → get the IP:
   ```bash
   ip addr show eth0
   ```
4. Note the IP — store it as the `DEBIAN_VM_IP` GitHub secret.

### Step 6 — Generate SSH key pair for GitHub Actions

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\debian_actions" -C "github-actions"
# Copy public key to Debian VM:
ssh-copy-id -i "$env:USERPROFILE\.ssh\debian_actions.pub" user@<VM-IP>
```

Store the **private key** content as the `DEBIAN_SSH_PRIVATE_KEY` GitHub secret.

### Step 7 — Install self-hosted GitHub Actions runner

```powershell
# Get token from: https://github.com/YOUR-USERNAME/hyperv-debian-terraform/settings/actions/runners/new
.\setup\03_install_github_runner.ps1 `
    -RepoUrl "https://github.com/YOUR-USERNAME/hyperv-debian-terraform" `
    -Token   "AXXXXXXXXXXXXXXXXX"
```

### Step 8 — Set GitHub Secrets

Go to `Settings → Secrets and variables → Actions → New repository secret`:

| Secret | Value |
|---|---|
| `WINRM_USERNAME` | Your Windows username |
| `WINRM_PASSWORD` | Your Windows password |
| `WINRM_CACERT_B64` | Base64 string printed by `01_enable_hyperv_winrm.ps1` |
| `DEBIAN_SSH_PRIVATE_KEY` | Contents of `~\.ssh\debian_actions` (private key) |
| `DEBIAN_VM_USER` | Debian username (e.g., `debian`) |
| `DEBIAN_VM_IP` | IP address of the VM (e.g., `172.28.144.10`) |

---

## GitHub Actions Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `terraform-plan.yml` | Pull Request to `main` | Runs `terraform plan`, comments output on PR |
| `terraform-apply.yml` | Push to `main` / manual | Runs `terraform apply -auto-approve` |
| `ssh-ping.yml` | Manual only | SSHes into Debian VM, runs a command |

---

## Project Layout

```
C:\Github\hyperv-debian-terraform\
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml      # PR check
│       ├── terraform-apply.yml     # Deploy on merge
│       └── ssh-ping.yml            # Manual SSH test
├── setup/
│   ├── 01_enable_hyperv_winrm.ps1  # Hyper-V + WinRM HTTPS
│   ├── 02_download_debian_iso.ps1  # Debian 12 ISO download
│   └── 03_install_github_runner.ps1# Self-hosted runner
├── terraform/
│   ├── main.tf                     # VM + VHDX + provider
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example    # Copy → terraform.tfvars
├── .gitignore
└── README.md
```

---

## Day-to-Day Usage

### Start/stop the VM via the runner

Create a simple `workflow_dispatch` workflow that calls:
```powershell
Start-VM -Name "debian-server"
Stop-VM  -Name "debian-server" -Force
```

### Make Terraform changes

1. Edit `terraform/main.tf` (e.g., increase `vm_cpus`)
2. Open a Pull Request → Actions runs `terraform plan` and comments the diff
3. Merge → Actions runs `terraform apply`

---

## Troubleshooting

### WinRM connection refused
```powershell
# Check listener is present
winrm enumerate winrm/config/listener
# Should show an HTTPS listener on port 5986
```

### Terraform provider auth fails
```powershell
# Test WinRM manually
Test-WSMan -ComputerName localhost -UseSSL -Credential (Get-Credential)
```

### VM doesn't get an IP
The "Default Switch" IP is assigned dynamically and changes on host reboot. To find it:
```powershell
Get-VM "debian-server" | Get-VMNetworkAdapter | Select-Object IPAddresses
```
Consider reserving the IP in the VM's `/etc/network/interfaces` for stability.
