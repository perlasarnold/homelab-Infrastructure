#!/usr/bin/env bash
# ==============================================================================
# 📚 Dapitan BookOrbit Server Deployment Script
# Node: Dapitan (192.168.1.27) | Host Storage Mount: /mnt/bindmounts/ebooks
# Network: SERVICES VLAN 110 (192.168.110.50/24) | Reverse Proxy: bookorbit.homelab-admin.me
# Default Admin Credentials: user: homelab-admin | pass: Jiggu1ot!@#
# ==============================================================================

set -euo pipefail

CT_ID="${CT_ID:-514}"
CT_NAME="${CT_NAME:-bookorbit-dapitan}"
MEMORY_MB="${MEMORY_MB:-2048}"
CORES="${CORES:-2}"
DISK_SIZE_GB="${DISK_SIZE_GB:-16}"
STORAGE_POOL="${STORAGE_POOL:-vm-fast}"
BRIDGE="${BRIDGE:-vmbr0}"
VLAN_TAG="${VLAN_TAG:-110}"
IP_ADDR="${IP_ADDR:-192.168.110.50/24}"
GATEWAY="${GATEWAY:-192.168.110.1}"
DNS_SERVER="${DNS_SERVER:-1.1.1.1 192.168.1.5}"
SYNOLOGY_SHARE="${SYNOLOGY_SHARE:-//192.168.1.12/Media/Ebooks}"
HOST_MOUNT_POINT="${HOST_MOUNT_POINT:-/mnt/bindmounts/ebooks}"
CONTAINER_EBOOKS_PATH="${CONTAINER_EBOOKS_PATH:-/mnt/ebooks}"
APP_DIR="${APP_DIR:-/opt/bookorbit}"

RAW_IP=$(echo "$IP_ADDR" | cut -d'/' -f1)

echo "======================================================================"
echo "📚 Dapitan BookOrbit Deployment & Provisioning Setup"
echo "======================================================================"
echo "Node:                Dapitan (192.168.1.27)"
echo "Container ID:        $CT_ID ($CT_NAME)"
echo "Resources:           $CORES Cores | $MEMORY_MB MB RAM | $DISK_SIZE_GB GB ($STORAGE_POOL)"
echo "Network Config:      $IP_ADDR (GW: $GATEWAY, VLAN: $VLAN_TAG, Bridge: $BRIDGE)"
echo "DNS Server:          $DNS_SERVER"
echo "NAS Ebook Source:    $SYNOLOGY_SHARE"
echo "Host Mount Point:    $HOST_MOUNT_POINT"
echo "Public Domain:       https://bookorbit.homelab-admin.me"
echo "======================================================================"

# ------------------------------------------------------------------------------
# Step 1: Ensure Persistent Synology SMB Mount on Dapitan Host
# ------------------------------------------------------------------------------
echo "📌 Step 1: Configuring Synology SMB Mount ($SYNOLOGY_SHARE)..."
mkdir -p "$HOST_MOUNT_POINT"

if [ ! -f /root/.pnascredentials ]; then
    echo "Creating /root/.pnascredentials on Dapitan host..."
    cat << 'EOF' > /root/.pnascredentials
username=homelab-admin
password=Jiggu1ot!@#
EOF
    chmod 600 /root/.pnascredentials
fi

FSTAB_LINE="$SYNOLOGY_SHARE $HOST_MOUNT_POINT cifs credentials=/root/.pnascredentials,iocharset=utf8,vers=3.0,uid=0,gid=0,file_mode=0775,dir_mode=0775,noperm,nobrl,_netdev,nofail,x-systemd.automount 0 0"

if ! grep -qs "$HOST_MOUNT_POINT" /etc/fstab; then
    echo "Adding mount entry to /etc/fstab..."
    echo "$FSTAB_LINE" >> /etc/fstab
    systemctl daemon-reload
fi

if ! mountpoint -q "$HOST_MOUNT_POINT"; then
    echo "Mounting $HOST_MOUNT_POINT..."
    mount "$HOST_MOUNT_POINT" || true
fi

if mountpoint -q "$HOST_MOUNT_POINT"; then
    echo "✅ $HOST_MOUNT_POINT is mounted successfully."
else
    echo "⚠️ Notice: Mount did not attach immediately. Automount will engage on demand."
fi

# ------------------------------------------------------------------------------
# Step 2: Provision LXC Container
# ------------------------------------------------------------------------------
echo "📌 Step 2: Provisioning LXC Container $CT_ID ($CT_NAME)..."
if pct status "$CT_ID" >/dev/null 2>&1; then
    echo "ℹ️ Container $CT_ID already exists. Skipping container creation."
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
    pct set "$CT_ID" -mp0 "$HOST_MOUNT_POINT,mp=$CONTAINER_EBOOKS_PATH"
    echo "✅ Container $CT_ID created successfully."
fi

# ------------------------------------------------------------------------------
# Step 3: Start Container
# ------------------------------------------------------------------------------
echo "📌 Step 3: Starting LXC Container $CT_ID..."
pct start "$CT_ID" || true
sleep 5

# ------------------------------------------------------------------------------
# Step 4: Install Docker CE & Dependencies inside LXC Guest
# ------------------------------------------------------------------------------
echo "📌 Step 4: Installing Docker CE & Dependencies inside Container..."
pct exec "$CT_ID" -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release python3 jq openssl git

if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

cat << "EOF" > /usr/sbin/apparmor_parser
#!/bin/sh
exit 0
EOF
chmod +x /usr/sbin/apparmor_parser

systemctl enable --now docker
'

# ------------------------------------------------------------------------------
# Step 5: Install OCI runc AppArmor Wrapper for nested container stability
# ------------------------------------------------------------------------------
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
    target_files = []
    if os.path.isdir(arg):
        for fname in ["config.json", "process.json"]:
            p = os.path.join(arg, fname)
            if os.path.isfile(p):
                target_files.append(p)
    elif os.path.isfile(arg) and (arg.endswith("config.json") or arg.endswith("process.json") or "process" in arg):
        target_files.append(arg)

    for config_file in target_files:
        try:
            with open(config_file, "r") as f:
                data = json.load(f)
            modified = False
            if "process" in data and isinstance(data["process"], dict):
                if data["process"].get("apparmorProfile") != "unconfined":
                    data["process"]["apparmorProfile"] = "unconfined"
                    modified = True
            if "apparmorProfile" in data and data["apparmorProfile"] != "unconfined":
                data["apparmorProfile"] = "unconfined"
                modified = True
            if modified:
                with open(config_file, "w") as f:
                    json.dump(data, f, indent=2)
        except Exception:
            pass

os.execv(real_runc, [real_runc] + args)
EOF

chmod +x /usr/bin/runc
'

# ------------------------------------------------------------------------------
# Step 6: Deploy BookOrbit Docker Stack
# ------------------------------------------------------------------------------
echo "📌 Step 6: Deploying BookOrbit Application & Postgres Stack..."

pct exec "$CT_ID" -- bash -c "
set -e
mkdir -p $APP_DIR/data/app $APP_DIR/data/postgres

# Generate secrets if .env does not exist
if [ ! -f $APP_DIR/.env ]; then
    DB_PASSWORD=\$(openssl rand -hex 16)
    JWT_SECRET=\$(openssl rand -hex 32)
    SETUP_TOKEN=\$(openssl rand -hex 24)

    cat << EOF > $APP_DIR/.env
APP_IMAGE=ghcr.io/bookorbit/bookorbit:latest
APP_PORT=3000
PORT=3000
BOOKS_HOST_PATH=$CONTAINER_EBOOKS_PATH

PUID=0
PGID=0

POSTGRES_USER=bookorbit
POSTGRES_PASSWORD=\${DB_PASSWORD}
POSTGRES_DB=bookorbit
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

JWT_SECRET=\${JWT_SECRET}
SETUP_BOOTSTRAP_TOKEN=\${SETUP_TOKEN}

APP_URL=https://bookorbit.homelab-admin.me
CLIENT_URL=https://bookorbit.homelab-admin.me
NODE_MAX_OLD_SPACE_SIZE=2048
EOF
fi

cat << 'EOF' > $APP_DIR/docker-compose.yml
name: bookorbit

services:
  app:
    container_name: bookorbit-app
    image: \${APP_IMAGE:-ghcr.io/bookorbit/bookorbit:latest}
    restart: unless-stopped
    init: true
    env_file:
      - .env
    ports:
      - \"\${APP_PORT:-3000}:\${PORT:-3000}\"
    environment:
      NODE_ENV: production
      PORT: \${PORT:-3000}
      DATABASE_URL: \${DATABASE_URL:-}
      POSTGRES_HOST: \${POSTGRES_HOST:-postgres}
      POSTGRES_PORT: \${POSTGRES_PORT:-5432}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
      JWT_SECRET: \${JWT_SECRET}
      SETUP_BOOTSTRAP_TOKEN: \${SETUP_BOOTSTRAP_TOKEN}
      APP_URL: \${APP_URL}
      CLIENT_URL: \${CLIENT_URL:-\${APP_URL}}
      PUID: \${PUID:-0}
      PGID: \${PGID:-0}
      NODE_MAX_OLD_SPACE_SIZE: \${NODE_MAX_OLD_SPACE_SIZE:-2048}
    volumes:
      - \${BOOKS_HOST_PATH:-/mnt/ebooks}:/books:ro
      - $APP_DIR/data/app:/app/data
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    container_name: bookorbit-postgres
    image: pgvector/pgvector:pg17
    restart: unless-stopped
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - $APP_DIR/data/postgres:/var/lib/postgresql/data
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}\"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

cd $APP_DIR
docker compose pull
docker compose up -d
"

echo "======================================================================"
echo "🎉 BookOrbit Container & Services Successfully Deployed!"
echo "======================================================================"
echo "Container:       $CT_NAME (CT $CT_ID) @ $RAW_IP:3000"
echo "Reverse Proxy:   https://bookorbit.homelab-admin.me"
echo "Ebooks Mount:    $SYNOLOGY_SHARE -> $CONTAINER_EBOOKS_PATH"
echo ""
echo "To retrieve the SETUP_BOOTSTRAP_TOKEN for initial setup wizard:"
echo "pct exec $CT_ID -- grep 'SETUP_BOOTSTRAP_TOKEN' $APP_DIR/.env"
echo ""
echo "Admin Credentials for setup wizard:"
echo "  Username / Email: homelab-admin (or homelab-admin@homelab-admin.me)"
echo "  Password:         Jiggu1ot!@#"
echo "======================================================================"
