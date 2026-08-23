# GitHub Actions Workflows

All infrastructure management is done through GitHub Actions. No direct SSH access needed after initial bootstrap.

---

## Workflow Overview

```
validate.yml           → Runs on every PR and push
    ├── terraform fmt + validate (Hyper-V + Proxmox)
    ├── yamllint (all YAML files)
    ├── ansible-lint
    ├── shellcheck (install.sh)
    └── gitleaks (secret scanner)

terraform-plan.yml     → Runs on PRs to main (terraform/ changes)
    └── Posts terraform plan output as PR comment

terraform-apply.yml    → Runs on push to main (terraform/ changes)
    └── terraform apply -auto-approve

ansible-bootstrap.yml  → Manual trigger only
    ├── 01_bootstrap.yml  (SSH hardening, UFW, fail2ban)
    ├── 02_install_docker.yml (Docker Engine + Compose)
    └── 04_maintenance.yml (cron jobs, watchdog)

docker-deploy.yml      → Manual trigger, service dropdown
    ├── Decrypts SOPS secrets
    ├── Requires homelab-production environment approval
    └── Runs 03_deploy_stack.yml Ansible playbook

sync-docs-to-wiki.yml  → Auto-triggered when docs/ or *.md changes
    ├── rsync docs/ to VM
    └── Pings Wiki.js git sync webhook

scheduled-maintenance.yml → Cron: 1st of month 03:00 UTC
    └── 04_maintenance.yml (updates, Docker image refresh, reboot-if-needed)

auto-remediation.yml   → Cron: every hour
    ├── server_health.py (disk/RAM/CPU/services check)
    ├── If issues: 05_remediation.yml
    └── Uploads JSON report as artifact

ssh-ping.yml           → Manual trigger
    └── SSH into VM, run a command (connectivity test)

docs-deploy.yml        → Auto-triggered when docs/ or mkdocs.yml changes
    └── mkdocs gh-deploy → GitHub Pages

build-release.yml      → Triggered on GitHub Release creation
    └── Builds Homelab-Installer.exe, attaches to release
```

---

## Secrets Reference

| Secret | Used by | Description |
|---|---|---|
| `DEBIAN_VM_IP` | All Ansible/SSH workflows | VM IP address |
| `DEBIAN_VM_USER` | All Ansible/SSH workflows | `debian` |
| `DEBIAN_SSH_PRIVATE_KEY` | All Ansible/SSH workflows | ed25519 private key |
| `WINRM_USERNAME` | Terraform (Hyper-V) | Windows username |
| `WINRM_PASSWORD` | Terraform (Hyper-V) | Windows password |
| `WINRM_CACERT_B64` | Terraform (Hyper-V) | WinRM self-signed cert |
| `PROXMOX_VE_ENDPOINT` | Terraform (Proxmox) | `https://IP:8006` |
| `PROXMOX_VE_API_TOKEN` | Terraform (Proxmox) | `user@realm!name=secret` |
| `PROXMOX_NODE` | Terraform (Proxmox) | Node name (e.g. `pve`) |
| `DEBIAN_SSH_PUBLIC_KEY` | Terraform (Proxmox cloud-init) | ed25519 public key |
| `SOPS_AGE_KEY` | docker-deploy | age private key for decryption |
| `WIKIJS_WEBHOOK_TOKEN` | sync-docs-to-wiki | Wiki.js git storage webhook |

---

## How to Trigger Workflows

### From the GitHub UI
**Actions → (select workflow) → Run workflow**

### From the command line (GitHub CLI)
```bash
# Install: https://cli.github.com
gh auth login

# Trigger workflows
gh workflow run docker-deploy.yml -f service=portainer -f action=up
gh workflow run ansible-bootstrap.yml -f target=proxmox -f playbooks=01,02,04
gh workflow run auto-remediation.yml -f remediate=true
```

---

## Adding a New Service

1. Create `docker/myservice/docker-compose.yml`
2. Create encrypted secrets: `secrets/myservice.env.enc` (if needed)
3. Add `myservice` to the options list in `docker-deploy.yml`
4. Push → PR → merge → deploy
