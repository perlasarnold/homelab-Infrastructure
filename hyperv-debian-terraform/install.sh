#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Homelab Bootstrap — Proxmox Edition
#  Usage (run from Proxmox shell or any Debian/Ubuntu host):
#
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/hyperv-debian-terraform/main/install.sh)"
#
#  What this does:
#    1. Installs prerequisites (git, terraform, ansible, gh CLI, jq)
#    2. Creates a Proxmox API token for Terraform
#    3. Downloads Debian 12 cloud-init image and creates a VM template
#    4. Clones this repo  
#    5. Registers a self-hosted GitHub Actions runner (as a systemd service)
#    6. All future VM/Docker operations are driven by GitHub Actions pushes — 
#       you never need to SSH into this machine again.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ "
  echo "  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗"
  echo "  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝"
  echo "  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗"
  echo "  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝"
  echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ "
  echo -e "${RESET}"
  echo -e "${BOLD}  Homelab Bootstrap — Proxmox + GitHub Actions + Terraform${RESET}"
  echo -e "  github.com/YOUR_USER/hyperv-debian-terraform\n"
}

step()  { echo -e "\n${CYAN}[$(date +%H:%M:%S)]${RESET} ${BOLD}$*${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
fail()  { echo -e "  ${RED}✗${RESET} $*"; exit 1; }
ask()   { echo -en "  ${BOLD}$1${RESET} "; read -r "$2"; }
askpw() { echo -en "  ${BOLD}$1${RESET} "; read -rs "$2"; echo; }

require_root() { [[ $EUID -eq 0 ]] || fail "Run as root (or with sudo)."; }

# ── Detect environment ────────────────────────────────────────────────────────
detect_env() {
  if command -v pvesh &>/dev/null; then
    ENV_TYPE="proxmox"
    ok "Detected: Proxmox VE host"
  elif grep -qi "debian\|ubuntu" /etc/os-release 2>/dev/null; then
    ENV_TYPE="debian"
    ok "Detected: Debian/Ubuntu host (Proxmox VM or standalone)"
  else
    ENV_TYPE="unknown"
    warn "Unknown environment — continuing anyway"
  fi
}

# ── Install prerequisites ─────────────────────────────────────────────────────
install_prereqs() {
  step "Installing prerequisites…"
  apt-get update -qq

  # Core tools
  apt-get install -y -qq curl wget git jq unzip gnupg lsb-release ca-certificates software-properties-common

  # Terraform
  if ! command -v terraform &>/dev/null; then
    wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list
    apt-get update -qq && apt-get install -y -qq terraform
    ok "Terraform $(terraform -version -json | jq -r .terraform_version) installed"
  else
    ok "Terraform already installed: $(terraform version -json | jq -r .terraform_version)"
  fi

  # Ansible
  if ! command -v ansible &>/dev/null; then
    apt-get install -y -qq ansible
    ok "Ansible $(ansible --version | head -1) installed"
  else
    ok "Ansible already installed"
  fi

  # GitHub CLI
  if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
      https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list
    apt-get update -qq && apt-get install -y -qq gh
    ok "GitHub CLI installed"
  else
    ok "GitHub CLI already installed"
  fi

  # Docker (for the runner to be able to test locally if needed)
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    ok "Docker installed"
  fi
}

# ── Proxmox: create API token for Terraform ───────────────────────────────────
setup_proxmox_api() {
  [[ "$ENV_TYPE" != "proxmox" ]] && return

  step "Setting up Proxmox API token for Terraform…"
  echo ""
  echo -e "  ${YELLOW}Open Proxmox UI → Datacenter → API Tokens → Add${RESET}"
  echo -e "  Or run: pveum user token add root@pam terraform --privsep=0"
  echo ""
  ask "Proxmox API Token ID (e.g., root@pam!terraform):" PROXMOX_TOKEN_ID
  askpw "Proxmox API Token Secret:" PROXMOX_TOKEN_SECRET
  ask "Proxmox host name/IP (e.g., VLAN 1 (Mgmt)):" PROXMOX_HOST
  ask "Proxmox node name (e.g., pve):" PROXMOX_NODE

  # Store for the runner's environment
  mkdir -p /etc/homelab
  cat > /etc/homelab/proxmox.env <<EOF
PROXMOX_VE_ENDPOINT=https://${PROXMOX_HOST}:8006
PROXMOX_VE_API_TOKEN="${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}"
PROXMOX_NODE=${PROXMOX_NODE}
EOF
  chmod 600 /etc/homelab/proxmox.env
  ok "Proxmox API credentials saved to /etc/homelab/proxmox.env"
}

# ── Proxmox: Download Debian cloud image and create VM template ───────────────
setup_proxmox_template() {
  [[ "$ENV_TYPE" != "proxmox" ]] && return

  step "Creating Debian 12 cloud-init VM template (ID 9000)…"

  local DEBIAN_IMG="debian-12-genericcloud-amd64.qcow2"
  local DEBIAN_URL="https://cloud.debian.org/images/cloud/bookworm/latest/${DEBIAN_IMG}"
  local STORAGE="local-lvm"
  local TEMPLATE_ID=9000

  if pvesh get /nodes/${PROXMOX_NODE}/qemu/${TEMPLATE_ID}/status/current &>/dev/null 2>&1; then
    warn "Template VM ${TEMPLATE_ID} already exists — skipping."
    return
  fi

  cd /tmp
  if [[ ! -f "$DEBIAN_IMG" ]]; then
    echo "  Downloading Debian 12 cloud image (~400 MB)…"
    wget -q --show-progress "$DEBIAN_URL"
  fi

  # Create template VM
  qm create $TEMPLATE_ID --name "debian-12-template" --memory 2048 --cores 2 \
    --net0 virtio,bridge=vmbr0 --ostype l26 --agent enabled=1 \
    --serial0 socket --vga serial0

  # Import disk
  qm importdisk $TEMPLATE_ID "$DEBIAN_IMG" $STORAGE
  qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0
  qm set $TEMPLATE_ID --boot c --bootdisk scsi0
  qm set $TEMPLATE_ID --ide2 ${STORAGE}:cloudinit
  qm set $TEMPLATE_ID --ipconfig0 ip=dhcp
  qm set $TEMPLATE_ID --ciuser debian --cipassword "changeme"

  # Convert to template
  qm template $TEMPLATE_ID
  ok "Template VM $TEMPLATE_ID created from Debian 12 cloud image"
}

# ── Clone repo ─────────────────────────────────────────────────────────────────
clone_repo() {
  step "Cloning homelab repo…"
  ask "GitHub repo URL (e.g., https://github.com/YOU/hyperv-debian-terraform):" REPO_URL
  REPO_DIR="/opt/homelab"

  if [[ -d "$REPO_DIR/.git" ]]; then
    warn "Repo already exists at $REPO_DIR — pulling latest."
    git -C "$REPO_DIR" pull
  else
    git clone "$REPO_URL" "$REPO_DIR"
  fi
  ok "Repo ready at $REPO_DIR"
}

# ── Install self-hosted GitHub Actions runner ─────────────────────────────────
install_runner() {
  step "Installing self-hosted GitHub Actions runner…"

  echo ""
  echo -e "  Get your registration token from:"
  echo -e "  ${YELLOW}${REPO_URL}/settings/actions/runners/new${RESET}"
  echo ""
  ask "Runner registration token:" RUNNER_TOKEN

  RUNNER_DIR="/opt/actions-runner"
  RUNNER_VERSION="2.325.0"
  RUNNER_ARCH="linux-x64"

  mkdir -p "$RUNNER_DIR"
  cd "$RUNNER_DIR"

  if [[ ! -f "config.sh" ]]; then
    curl -sfLo runner.tar.gz \
      "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
    tar xzf runner.tar.gz
    rm runner.tar.gz
  fi

  RUNNER_NAME="$(hostname)-homelab-runner"

  # Load Proxmox env into runner if available
  EXTRA_ENV=""
  [[ -f /etc/homelab/proxmox.env ]] && EXTRA_ENV="EnvironmentFile=/etc/homelab/proxmox.env"

  ./config.sh \
    --url "$REPO_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "self-hosted,Linux,homelab,proxmox" \
    --runnergroup "Default" \
    --work "_work" \
    --unattended \
    --replace

  # Install as systemd service
  ./svc.sh install
  ./svc.sh start

  # Inject Proxmox env into the service unit if needed
  if [[ -f /etc/homelab/proxmox.env ]]; then
    SERVICE=$(./svc.sh status 2>/dev/null | grep -oP 'actions\.runner\.[^\s]+\.service' || true)
    if [[ -n "$SERVICE" ]]; then
      sed -i "/\[Service\]/a EnvironmentFile=/etc/homelab/proxmox.env" "/etc/systemd/system/${SERVICE}"
      systemctl daemon-reload
      systemctl restart "$SERVICE"
    fi
  fi

  ok "Runner '${RUNNER_NAME}' installed and running as systemd service"
  ok "Labels: self-hosted, Linux, homelab, proxmox"
}

# ── Summary ────────────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}  ✅  Bootstrap complete!${RESET}"
  echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${BOLD}Next steps (all done from GitHub — no SSH needed):${RESET}"
  echo ""
  echo -e "  1. Add GitHub Secrets to your repo:"
  echo -e "     ${YELLOW}${REPO_URL}/settings/secrets/actions${RESET}"
  echo -e "     • PROXMOX_VE_ENDPOINT   → https://${PROXMOX_HOST:-YOUR_IP}:8006"
  echo -e "     • PROXMOX_VE_API_TOKEN  → (from /etc/homelab/proxmox.env)"
  echo -e "     • PROXMOX_NODE          → ${PROXMOX_NODE:-pve}"
  echo -e "     • DEBIAN_SSH_PUBLIC_KEY → your public SSH key"
  echo ""
  echo -e "  2. Push to 'main' branch → Terraform creates Debian VMs"
  echo -e "  3. Trigger 'Ansible Bootstrap' workflow → Docker installed on VM"  
  echo -e "  4. Trigger 'Docker Deploy' workflow → select a service to deploy"
  echo ""
  echo -e "  ${BOLD}Runner status:${RESET}"
  echo -e "  ${YELLOW}${REPO_URL}/settings/actions/runners${RESET}"
  echo ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  banner
  require_root
  detect_env
  install_prereqs
  setup_proxmox_api
  setup_proxmox_template
  clone_repo
  install_runner
  print_summary
}

main "$@"
