#!/usr/bin/env bash
# ==============================================================================
# Floci Multi-Cloud Stack Automated Interactive Deployment Script
# Target Node: Proxmox VE Host (e.g. Dapitan / Bulakan / Cebu)
# ==============================================================================
# Description:
# Interactively prompts for custom infrastructure parameters (CT ID, IP, Pools,
# VLANs, Credentials) with sensible defaults, then provisions a complete Floci 
# multi-cloud stack in an LXC container with ZFS mass-storage persistence and 
# automated OCI runc AppArmor wrapping for nested Docker execution.
# ==============================================================================

set -euo pipefail

# Helper function for interactive prompts with defaults
prompt_var() {
    local var_name="$1"
    local prompt_text="$2"
    local default_val="$3"

    if [ -t 0 ] && [ "${NON_INTERACTIVE:-0}" != "1" ]; then
        read -rp "$prompt_text [$default_val]: " user_val
        eval "$var_name=\"\${user_val:-$default_val}\""
    else
        eval "$var_name=\"\${!var_name:-$default_val}\""
    fi
}

echo "======================================================================"
echo "🚀 Floci Multi-Cloud Stack Interactive Deployment Setup"
echo "======================================================================"
echo "Press ENTER to accept default values, or enter custom values."
echo "----------------------------------------------------------------------"

# Interactive Infrastructure Inputs
prompt_var CT_ID "Container ID" "${CT_ID:-512}"
prompt_var CT_NAME "Container Hostname" "${CT_NAME:-floci-dapitan}"
prompt_var MEMORY_MB "Memory (MB)" "${MEMORY_MB:-4096}"
prompt_var CORES "CPU Cores" "${CORES:-4}"
prompt_var DISK_SIZE_GB "OS Disk Size (GB)" "${DISK_SIZE_GB:-32}"
prompt_var STORAGE_POOL "Proxmox OS Storage Pool" "${STORAGE_POOL:-vm-fast}"
prompt_var ZFS_BULK_POOL "ZFS Mass Storage Pool" "${ZFS_BULK_POOL:-bulk18}"
prompt_var BRIDGE "Network Bridge" "${BRIDGE:-vmbr0}"
prompt_var VLAN_TAG "VLAN Tag" "${VLAN_TAG:-110}"
prompt_var IP_ADDR "Container IP Address (CIDR)" "${IP_ADDR:-192.168.110.49/24}"
prompt_var GATEWAY "Network Gateway" "${GATEWAY:-192.168.110.1}"
prompt_var DNS_SERVER "DNS Server" "${DNS_SERVER:-192.168.1.4}"

echo "----------------------------------------------------------------------"
prompt_var FLOCI_USER "Default Floci Admin Username" "${FLOCI_USER:-homelab-admin}"
prompt_var FLOCI_PASS "Default Floci Admin Password" "${FLOCI_PASS:-Jiggu1ot!@#}"

# Extract IP without subnet for hostname configuration
RAW_IP=$(echo "$IP_ADDR" | cut -d'/' -f1)

echo "======================================================================"
echo "📋 Confirmed Provisioning Target Parameters:"
echo "Container ID:        $CT_ID ($CT_NAME)"
echo "CPU / Memory / Disk: $CORES Cores | $MEMORY_MB MB RAM | $DISK_SIZE_GB GB ($STORAGE_POOL)"
echo "Network Config:      $IP_ADDR (GW: $GATEWAY, VLAN: $VLAN_TAG, Bridge: $BRIDGE)"
echo "DNS Server:          $DNS_SERVER"
echo "Mass Storage Dataset:$ZFS_BULK_POOL/floci-data"
echo "Stack Admin User:    $FLOCI_USER"
echo "======================================================================"

if [ -t 0 ] && [ "${NON_INTERACTIVE:-0}" != "1" ]; then
    read -rp "Proceed with provisioning? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        echo "❌ Deployment aborted by user."
        exit 0
    fi
fi

# 1. Create Host ZFS Dataset for Mass Storage Persistence
echo "📌 Step 1: Provisioning Host ZFS Dataset..."
if ! zfs list "$ZFS_BULK_POOL/floci-data" >/dev/null 2>&1; then
    zfs create -o recordsize=128k -o compression=zstd "$ZFS_BULK_POOL/floci-data"
    echo "✅ ZFS dataset $ZFS_BULK_POOL/floci-data created."
else
    echo "ℹ️ ZFS dataset $ZFS_BULK_POOL/floci-data already exists."
fi

mkdir -p /mnt/bindmounts/floci-data
chmod 777 /mnt/bindmounts/floci-data

# 2. Provision LXC Container
echo "📌 Step 2: Creating LXC Container $CT_ID ($CT_NAME)..."
if pct status "$CT_ID" >/dev/null 2>&1; then
    echo "⚠️ Container $CT_ID already exists. Skipping container creation."
else
    # Download Ubuntu 24.04 template if not present
    TEMPLATE=$(pveam list local | grep -i 'ubuntu-24.04' | head -n1 | awk '{print $2}')
    if [ -z "$TEMPLATE" ]; then
        echo "Downloading Ubuntu 24.04 LXC template..."
        pveam update
        pveam download local ubuntu-24.04-standard_24.04-2_amd64.tar.zst
        TEMPLATE="local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
    fi

    pct create "$CT_ID" "$TEMPLATE" \
        --ostype ubuntu \
        --hostname "$CT_NAME" \
        --memory "$MEMORY_MB" \
        --swap 1024 \
        --cores "$CORES" \
        --rootfs "$STORAGE_POOL:$DISK_SIZE_GB" \
        --net0 "name=eth0,bridge=$BRIDGE,tag=$VLAN_TAG,ip=$IP_ADDR,gw=$GATEWAY,type=veth" \
        --nameserver "$DNS_SERVER" \
        --features "nesting=1,keyctl=1" \
        --unprivileged 0 \
        --onboot 1

    # Apply AppArmor unconfined profile required for Docker-in-LXC
    echo "lxc.apparmor.profile: unconfined" >> "/etc/pve/lxc/$CT_ID.conf"
    
    # Add ZFS Dataset bind mount
    pct set "$CT_ID" -mp0 "/mnt/bindmounts/floci-data,mp=/mnt/floci-data"
    echo "✅ Container $CT_ID created successfully."
fi

# 3. Start Container
echo "📌 Step 3: Starting LXC Container $CT_ID..."
pct start "$CT_ID" || true
sleep 5

# 4. Install Docker CE inside Guest LXC
echo "📌 Step 4: Installing Docker CE & Dependencies inside Container..."
pct exec "$CT_ID" -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release python3 jq

if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable --now docker
'

# 5. Install OCI runc AppArmor Python Wrapper
echo "📌 Step 5: Installing OCI runc AppArmor Wrapper inside Container..."
pct exec "$CT_ID" -- bash -c '
set -e
if [ -f /usr/bin/runc ] && [ ! -f /usr/bin/runc.real ]; then
    mv /usr/bin/runc /usr/bin/runc.real
fi

cat << "EOF" > /usr/bin/runc
#!/usr/bin/python3
import os, sys, json

real_runc = "/usr/bin/runc.real"
args = sys.argv[1:]

for arg in args:
    config_file = None
    if os.path.isdir(arg) and os.path.isfile(os.path.join(arg, "config.json")):
        config_file = os.path.join(arg, "config.json")
    elif os.path.isfile(arg) and arg.endswith("config.json"):
        config_file = arg

    if config_file:
        try:
            with open(config_file, "r") as f:
                data = json.load(f)
            if "process" in data and isinstance(data["process"], dict):
                data["process"]["apparmorProfile"] = "unconfined"
            with open(config_file, "w") as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

os.execv(real_runc, [real_runc] + args)
EOF

chmod +x /usr/bin/runc
'

# 6. Configure Storage Directories & Docker Compose Stack
echo "📌 Step 6: Deploying Floci Docker Compose Stack..."
pct exec "$CT_ID" -- bash -c "
set -e
mkdir -p /mnt/floci-data/floci /mnt/floci-data/floci-az /mnt/floci-data/floci-gcp /opt/floci

# Generate .env credentials file
cat << EOF > /opt/floci/.env
AWS_ACCESS_KEY_ID=$FLOCI_USER
AWS_SECRET_ACCESS_KEY=$FLOCI_PASS
AWS_DEFAULT_REGION=us-east-1
FLOCI_AZ_ACCOUNT_NAME=$FLOCI_USER
FLOCI_AZ_ACCOUNT_KEY=SmlnZ3Uxb3QhQCM=
GOOGLE_CLOUD_PROJECT=$FLOCI_USER
FLOCI_GCP_PROJECT=$FLOCI_USER
EOF
chmod 600 /opt/floci/.env

# Generate docker-compose.yml
cat << EOF > /opt/floci/docker-compose.yml
services:
  floci:
    image: floci/floci:latest
    container_name: floci
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - FLOCI_STORAGE_MODE=persistent
      - FLOCI_STORAGE_PERSISTENT_PATH=/app/data
      - FLOCI_HOSTNAME=$RAW_IP
      - DOCKER_HOST=unix:///var/run/docker.sock
    ports:
      - \"4566:4566\"
      - \"6379-6399:6379-6399\"
      - \"7001-7099:7001-7099\"
      - \"9200-9299:9200-9299\"
    volumes:
      - /mnt/floci-data/floci:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    security_opt:
      - apparmor:unconfined

  floci-az:
    image: floci/floci-az:latest
    container_name: floci-az
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - FLOCI_AZ_STORAGE_MODE=persistent
      - FLOCI_AZ_PERSISTENT_PATH=/app/data
      - DOCKER_HOST=unix:///var/run/docker.sock
    ports:
      - \"4577:4577\"
    volumes:
      - /mnt/floci-data/floci-az:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    security_opt:
      - apparmor:unconfined

  floci-gcp:
    image: floci/floci-gcp:latest
    container_name: floci-gcp
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - FLOCI_GCP_STORAGE_MODE=persistent
      - FLOCI_GCP_PERSISTENT_PATH=/app/data
      - DOCKER_HOST=unix:///var/run/docker.sock
    ports:
      - \"4588:4588\"
    volumes:
      - /mnt/floci-data/floci-gcp:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    security_opt:
      - apparmor:unconfined

  floci-ui:
    image: floci/floci-ui:latest
    container_name: floci-ui
    restart: unless-stopped
    env_file:
      - .env
    environment:
      - FLOCI_ENDPOINT=http://$RAW_IP:4566
      - FLOCI_AZ_ENDPOINT=http://$RAW_IP:4577
      - FLOCI_GCP_ENDPOINT=http://$RAW_IP:4588
      - PORT=4500
    ports:
      - \"4500:4500\"
    security_opt:
      - apparmor:unconfined
EOF

cd /opt/floci
docker compose pull
docker compose up -d
"

# 7. Verification
echo "📌 Step 7: Verifying Floci Stack Health..."
sleep 10
pct exec "$CT_ID" -- bash -c '
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
curl -s http://127.0.0.1:4566/_floci/health || echo "AWS health check failed"
curl -s http://127.0.0.1:4500/api/clouds || echo "UI health check failed"
'

echo "======================================================================"
echo "🎉 Floci Multi-Cloud Stack Interactive Deployment Complete!"
echo "LXC Container:       $CT_NAME (CT $CT_ID) @ $RAW_IP"
echo "Floci UI Dashboard:  http://$RAW_IP:4500"
echo "AWS Wire Protocol:   http://$RAW_IP:4566"
echo "Azure Emulator:      http://$RAW_IP:4577"
echo "GCP Emulator:        http://$RAW_IP:4588"
echo "Mass Storage Path:   /mnt/bindmounts/floci-data ($ZFS_BULK_POOL)"
echo "Admin Credentials:   Username: $FLOCI_USER | Password: $FLOCI_PASS"
echo "======================================================================"
