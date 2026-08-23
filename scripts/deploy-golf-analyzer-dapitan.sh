#!/usr/bin/env bash
# ==============================================================================
# ⛳ Dapitan Golf Swing Analyzer Docker Stack Automated Installer
# Node: Dapitan (VLAN 1 [MGMT]) | Host ZFS Dataset: bulk18/golf-analyzer-data
# Web URL: https://golf.homelab-admin.me (Port 8086 noVNC)
# ==============================================================================

set -euo pipefail

CT_ID="${CT_ID:-513}"
CT_NAME="${CT_NAME:-golf-analyzer-dapitan}"
MEMORY_MB="${MEMORY_MB:-4096}"
CORES="${CORES:-4}"
DISK_SIZE_GB="${DISK_SIZE_GB:-20}"
STORAGE_POOL="${STORAGE_POOL:-vm-fast}"
ZFS_BULK_POOL="${ZFS_BULK_POOL:-bulk18}"
BRIDGE="${BRIDGE:-vmbr0}"
VLAN_TAG="${VLAN_TAG:-110}"
IP_ADDR="${IP_ADDR:-VLAN 110 (Services)/24}"
GATEWAY="${GATEWAY:-VLAN 110 (Services)}"
DNS_SERVER="${DNS_SERVER:-VLAN 1 [DNS-Primary]}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/bindmounts/golf-analyzer-data}"
APP_DIR="${APP_DIR:-/opt/golf-swing-analyzer}"

RAW_IP=$(echo "$IP_ADDR" | cut -d'/' -f1)

echo "======================================================================"
echo "⛳ Dapitan Golf Swing Analyzer Deployment Setup"
echo "======================================================================"
echo "Container ID:        $CT_ID ($CT_NAME)"
echo "CPU / Memory / Disk: $CORES Cores | $MEMORY_MB MB RAM | $DISK_SIZE_GB GB ($STORAGE_POOL)"
echo "Network Config:      $IP_ADDR (GW: $GATEWAY, VLAN: $VLAN_TAG, Bridge: $BRIDGE)"
echo "DNS Server:          $DNS_SERVER"
echo "Mass Storage Dataset:$ZFS_BULK_POOL/golf-analyzer-data"
echo "======================================================================"

# 1. Provision Host ZFS Dataset
echo "📌 Step 1: Provisioning Host ZFS Dataset..."
if ! zfs list "$ZFS_BULK_POOL/golf-analyzer-data" >/dev/null 2>&1; then
    zfs create -o recordsize=128k -o compression=zstd "$ZFS_BULK_POOL/golf-analyzer-data"
    echo "✅ ZFS dataset $ZFS_BULK_POOL/golf-analyzer-data created."
else
    echo "ℹ️ ZFS dataset $ZFS_BULK_POOL/golf-analyzer-data already exists."
fi

mkdir -p "$MOUNT_POINT/input" "$MOUNT_POINT/output" "$MOUNT_POINT/drawings"
chmod -R 777 "$MOUNT_POINT"

# 2. Provision LXC Container
echo "📌 Step 2: Creating LXC Container $CT_ID ($CT_NAME)..."
if pct status "$CT_ID" >/dev/null 2>&1; then
    echo "⚠️ Container $CT_ID already exists. Skipping container creation."
else
    TEMPLATE=$(pveam list local | grep -i 'ubuntu' | head -n1 | awk '{print $1}')
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

    echo "lxc.apparmor.profile: unconfined" >> "/etc/pve/lxc/$CT_ID.conf"
    pct set "$CT_ID" -mp0 "$MOUNT_POINT,mp=/mnt/bulk18/golf-analyzer-data"
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
apt-get install -y ca-certificates curl gnupg lsb-release python3 jq git

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

# 6. Clone repository & deploy Docker Compose stack
echo "📌 Step 6: Deploying Golf Swing Analyzer Docker Compose Stack..."
pct exec "$CT_ID" -- bash -c "
set -e
mkdir -p /opt/golf-swing-analyzer
if [ ! -d /opt/golf-swing-analyzer/.git ]; then
    git clone https://github.com/greggjuri/golf-swing-analyzer.git /opt/golf-swing-analyzer
fi
"

echo "======================================================================"
echo "🎉 Golf Swing Analyzer LXC Container Provisioned Successfully!"
echo "LXC Container:       $CT_NAME (CT $CT_ID) @ $RAW_IP"
echo "Storage Path:        $MOUNT_POINT"
echo "======================================================================"
