# 🚀 Floci Multi-Cloud Stack Deployment & Troubleshooting Guide

- **Date:** August 20, 2026
- **Objective:** Provision a persistent, LAN-only, multi-cloud emulator stack (`floci`, `floci-az`, `floci-gcp`, `floci-ui`) on Proxmox node **Dapitan** (`VLAN 1 [Management]`) with mass storage on ZFS pool `bulk18`, HTTPS SSL reverse proxying via Nginx Proxy Manager (`VLAN 120 (DMZ)`), and Single Sign-On authentication via Authentik (`https://auth.homelab-admin.me`).
- **Outcome:** Successfully deployed, persistent across container restarts, SSO-protected for web browser users, and programmatic header-bypassed for AWS/Azure/GCP SDKs and CLI tools.

---

## 🏗️ Architecture & Component Inventory

| Component | Node / Location | IP / Port | Function & Configuration |
| :--- | :--- | :--- | :--- |
| **Proxmox Node** | `Dapitan` | `VLAN 1 [Management]` | Proxmox VE host running ZFS pool `bulk18` & `vm-fast` |
| **LXC Guest (CT 512)** | `floci-dapitan` | `VLAN 110 (Services)` | Privileged Ubuntu 24.04 LXC (`nesting=1,keyctl=1`, 4 vCPU, 4GB RAM) |
| **Mass Storage Mount** | `bulk18/floci-data` | `/mnt/floci-data` | Host ZFS dataset (`recordsize=128k`, `zstd`) mounted into CT 512 |
| **Floci AWS Core** | CT 512 Docker | Port `4566` | Emulates 69 AWS services (S3, SQS, SNS, DynamoDB, Lambda, RDS, etc.) |
| **Floci Azure** | CT 512 Docker | Port `4577` | Emulates Azure Blob, Queue, Table, Functions, Cosmos DB |
| **Floci GCP** | CT 512 Docker | Port `4588` | Emulates GCP Pub/Sub, Firestore, Datastore, GCS, Secret Manager |
| **Floci UI (Console)** | CT 512 Docker | Port `4500` | Single Page React Application management dashboard |
| **Pi-hole Local DNS** | Bulakan (`CT 301`) | `VLAN 1 [Primary DNS]` | Maps `*.homelab-admin.me` subdomains to NPM (`VLAN 120 (DMZ)`) |
| **Nginx Proxy Manager** | Cebu (`CT 105`) | `VLAN 120 (DMZ)` | Reverse proxy & SSL termination (`*.homelab-admin.me`) |
| **Authentik IdP** | Cebu (`CT 103`) | `VLAN 110 (Services):9000` | Forward Auth Proxy Outpost for Single Sign-On |

---

## 🛠️ Step-by-Step Implementation

### 1. ZFS Dataset & LXC Container Provisioning
- Created ZFS dataset `bulk18/floci-data` on host Dapitan:
  ```bash
  zfs create -o recordsize=128k -o compression=zstd bulk18/floci-data
  mkdir -p /mnt/bindmounts/floci-data
  ```
- Created LXC Container 512 (`floci-dapitan`) on `vm-fast` SSD with `nesting=1,keyctl=1` and bind mount:
  ```bash
  pct create 512 local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
    --hostname floci-dapitan --memory 4096 --cores 4 \
    --rootfs vm-fast:32 --net0 name=eth0,bridge=vmbr0,tag=110,ip=VLAN 110 (Services)/24,gw=VLAN 110 (Services) \
    --nameserver VLAN 1 [Primary DNS] --features nesting=1,keyctl=1 --unprivileged 0 --onboot 1

  echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/512.conf
  pct set 512 -mp0 /mnt/bindmounts/floci-data,mp=/mnt/floci-data
  pct start 512
  ```

### 2. Docker CE Engine & OCI Runtime Wrapper Setup
- Installed Docker CE 29.7 and Docker Compose v5.5 inside CT 512.
- Installed **Python OCI runc AppArmor Wrapper** (`/usr/bin/runc`) inside CT 512 (see Troubleshooting Section 2 below).

### 3. Floci Stack Configuration & Deployment (`/opt/floci`)
- Created `/opt/floci/.env` (`chmod 600`):
  ```env
  AWS_ACCESS_KEY_ID=homelab-admin
  AWS_SECRET_ACCESS_KEY=Jiggu1ot!@#
  AWS_DEFAULT_REGION=us-east-1
  FLOCI_AZ_ACCOUNT_NAME=homelab-admin
  FLOCI_AZ_ACCOUNT_KEY=SmlnZ3Uxb3QhQCM=
  GOOGLE_CLOUD_PROJECT=homelab-admin
  ```
- Deployed `/opt/floci/docker-compose.yml`:
  ```yaml
  services:
    floci:
      image: floci/floci:latest
      container_name: floci
      restart: unless-stopped
      env_file: [.env]
      environment:
        - FLOCI_STORAGE_MODE=persistent
        - FLOCI_STORAGE_PERSISTENT_PATH=/app/data
        - FLOCI_HOSTNAME=VLAN 110 (Services)
        - DOCKER_HOST=unix:///var/run/docker.sock
      ports:
        - "4566:4566"
        - "6379-6399:6379-6399"
        - "7001-7099:7001-7099"
        - "9200-9299:9200-9299"
      volumes:
        - /mnt/floci-data/floci:/app/data
        - /var/run/docker.sock:/var/run/docker.sock
      security_opt: [- apparmor:unconfined]

    floci-az:
      image: floci/floci-az:latest
      container_name: floci-az
      restart: unless-stopped
      env_file: [.env]
      environment:
        - FLOCI_AZ_STORAGE_MODE=persistent
        - FLOCI_AZ_PERSISTENT_PATH=/app/data
        - DOCKER_HOST=unix:///var/run/docker.sock
      ports: ["4577:4577"]
      volumes:
        - /mnt/floci-data/floci-az:/app/data
        - /var/run/docker.sock:/var/run/docker.sock
      security_opt: [- apparmor:unconfined]

    floci-gcp:
      image: floci/floci-gcp:latest
      container_name: floci-gcp
      restart: unless-stopped
      env_file: [.env]
      environment:
        - FLOCI_GCP_STORAGE_MODE=persistent
        - FLOCI_GCP_PERSISTENT_PATH=/app/data
        - DOCKER_HOST=unix:///var/run/docker.sock
      ports: ["4588:4588"]
      volumes:
        - /mnt/floci-data/floci-gcp:/app/data
        - /var/run/docker.sock:/var/run/docker.sock
      security_opt: [- apparmor:unconfined]
  ```

---

## 🔍 Comprehensive Troubleshooting Log & Root Causes

### Issue 1: Docker Container Startup Failure inside LXC (`apparmor_parser: Access denied`)
- **Symptom:** Running `docker compose up -d` failed with `apparmor_parser: Access denied. You need policy admin privileges to manage profiles.`
- **Investigation:** Inspecting `/var/log/syslog` revealed Docker daemon attempted to load `/etc/apparmor.d/docker-default` profile into the host kernel via `apparmor_parser`. LXC guests cannot reload host kernel security profiles.
- **Root Cause:** Proxmox default AppArmor profile restricts LXC guests from invoking `apparmor_parser -Kr`.
- **Resolution:** Added `lxc.apparmor.profile: unconfined` to `/etc/pve/lxc/512.conf` on Proxmox host Dapitan and added `security_opt: [- apparmor:unconfined]` to all compose services.

---

### Issue 2: Floci UI unavailable with Status 500 / 400 (`apparmor_parser exit status 243`)
- **Symptom:** Accessing `/_floci/ui` presented a red error page:
  > *Could not start the Floci UI from image 'floci/floci-ui:latest': Status 500: apparmor_parser: Access denied (exit status 243)*
- **Investigation:** Floci dynamically spawns Docker sidecars (`floci/floci-ui:latest`, Lambda functions, RDS proxies, ECS tasks) directly via `/var/run/docker.sock`. Because Floci calls the Docker API without passing `security_opt: apparmor:unconfined`, the OCI container runtime (`runc`) defaulted to loading `docker-default` profile. `runc` then failed when writing to `/proc/thread-self/attr/apparmor/exec`.
- **Root Cause:** OCI runtime `runc` checks sysfs `/sys/module/apparmor/parameters/enabled` (returns `Y` from host kernel). When `"apparmorProfile"` is missing from OCI `config.json` specs, `runc` enforces `docker-default` and fails inside unprivileged procfs mounts.
- **Resolution:** Installed an automated OCI runtime wrapper at `/usr/bin/runc` inside CT 512 that intercepts container creation calls and injects `"process.apparmorProfile": "unconfined"` into OCI `config.json` specs:
  ```python
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
  ```

---

### Issue 3: Nginx Proxy Manager 500 Error during Authentik `auth_request`
- **Symptom:** Visiting `https://aws.homelab-admin.me` returned `HTTP 500 Internal Server Error`.
- **Investigation:** Inspected Nginx fallback log `/data/logs/fallback_error.log` in NPM CT 105:
  > *auth request unexpected status: 302 while sending to client*
- **Root Cause:** Nginx `auth_request` subrequests treat HTTP `302 Found` as an invalid status code unless the proxy host routes browser requests directly to the Authentik Proxy Outpost or handles the redirect payload.
- **Resolution:** Updated Nginx Proxy Manager hosts to forward browser requests directly to Authentik Outpost (`http://VLAN 110 (Services):9000`), allowing Authentik to handle 302 SSO redirects and session cookies natively, while maintaining an `if ($http_authorization != "")` map check for programmatic SDK/CLI traffic.

---

### Issue 4: Floci UI displaying `🔴 Not connected` & Azure / GCP `Runtime unavailable`
- **Symptom:** Opening `https://aws.homelab-admin.me/console/azure` rendered the UI framework, but reported `Runtime unavailable: Cannot reach Floci-AZ at http://localhost:4577`.
- **Investigation:** Floci UI container `floci-ui` was relying on default endpoint values (`http://localhost:4577` and `http://localhost:4588`), which fail inside the containerized environment.
- **Root Cause:** The `floci-ui` container requires explicit environment variables `FLOCI_AZ_ENDPOINT` and `FLOCI_GCP_ENDPOINT` pointing to `http://VLAN 110 (Services):4577` and `http://VLAN 110 (Services):4588`.
- **Resolution:** Defined `floci-ui` as a static service in `docker-compose.yml` with explicit endpoints:
  - `FLOCI_ENDPOINT=http://VLAN 110 (Services):4566`
  - `FLOCI_AZ_ENDPOINT=http://VLAN 110 (Services):4577`
  - `FLOCI_GCP_ENDPOINT=http://VLAN 110 (Services):4588`
  - Also added location blocks in `floci_azure.conf` and `floci_gcp.conf` mapping `/api/`, `/console`, and `/assets/` to port `4500`. All cloud runtime toggles (AWS, Azure, GCP) now report `🟢 Connected` (`availability: available`).

---

## ⚡ Reproduction & Interactive Installer Script

To reproduce or redeploy this complete environment on any Proxmox VE host, run the interactive deployment script included in the homelab repository:

```bash
# Script location:
/mnt/pve/homelab/scripts/deploy-floci-stack.sh
```

### Interactive & Non-Interactive Usage Modes:

#### 1. Interactive Mode (Prompts for custom configs with defaults):
Simply execute the script without arguments. It will prompt for each infrastructure parameter (CT ID, Hostname, IPs, VLANs, Storage Pools, Credentials) and show defaults in brackets `[default]`:
```bash
chmod +x /mnt/pve/homelab/scripts/deploy-floci-stack.sh
/mnt/pve/homelab/scripts/deploy-floci-stack.sh
```

#### 2. Non-Interactive / Unattended Mode (Pre-set environment variables):
Override specific variables via command line environment flags for scripted/unattended deployments:
```bash
NON_INTERACTIVE=1 CT_ID=513 CT_NAME="floci-bulakan" IP_ADDR="VLAN 110 (Services)/24" /mnt/pve/homelab/scripts/deploy-floci-stack.sh
```

---

## ✅ Verification & Outcome

- **Web Browsers:** Accessing `https://aws.homelab-admin.me/_floci/ui` or `https://ui.homelab-admin.me` redirects to Authentik SSO login (`https://auth.homelab-admin.me`), sets session cookies, and loads the live management dashboard (`🟢 Connected aws`).
- **AWS CLI:** `aws s3 ls --endpoint-url https://aws.homelab-admin.me` bypasses browser SSO and returns `200 OK`.
- **Data Persistence:** Restarting containers (`docker compose restart`) preserves state in `/mnt/bindmounts/floci-data` on `bulk18`.

---

## 📚 References
- Floci Documentation: [https://github.com/floci-io](https://github.com/floci-io)
- Proxmox LXC AppArmor Guide: [Proxmox Overview](file:////opt/homelab-infrastructure/02-Proxmox/Proxmox%20Overview.md)
- Automated Deployment Script: [deploy-floci-stack.sh](file:////opt/homelab-infrastructure/scripts/deploy-floci-stack.sh)
