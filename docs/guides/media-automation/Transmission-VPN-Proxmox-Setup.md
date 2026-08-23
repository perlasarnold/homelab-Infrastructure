# Guide: Transmission with Surfshark VPN and SMB Storage on Proxmox

* **Date:** May 19, 2026  
* **Objective:** Establish a highly secure, leak-proof BitTorrent download server running Transmission, routed exclusively through a Surfshark VPN using Gluetun. All completed downloads are directly saved to the Synology NAS SMB share (`\\PNAS\Seagate\Share\Downloads\`), and the service is seamlessly integrated into the active Arr stack (Radarr, Sonarr, Prowlarr).
* **Maintainer:** Perlas  

---

## 1. Architectural Design Overview

To build a robust, high-performance, and secure download client, we avoid running a basic naked service. Instead, we implement a **Docker inside Proxmox LXC** architecture with a sidecar VPN gateway.

```mermaid
graph TD
    subgraph Synology NAS [Synology PNAS]
        SMB["SMB Share (\\PNAS\Seagate\Share\Downloads)"]
    end

    subgraph Proxmox Host [Bulakan Node - VLAN 1 [Management]]
        Mount["CIFS Mount (/mnt/pve/PNAS-Downloads)"]
        
        subgraph LXC ["LXC Container 112 (Transmission)"]
            Bind["Bind Mount (/downloads)"]
            
            subgraph Docker Compose Stack ["Docker Compose Engine"]
                VPN["Gluetun Container (VPN Client)"]
                Trans["Transmission Container"]
            end
        end
        
        Radarr["Radarr CT 105"]
        Sonarr["Sonarr CT 106"]
        Prowlarr["Prowlarr CT 103"]
    end

    %% Network Routing %%
    Trans -->|network_mode: service:vpn| VPN
    VPN -->|Encrypted WireGuard/OpenVPN| Internet((WAN / Surfshark VPN))
    
    %% Storage Mounting %%
    SMB <-->|Natively Mounted| Mount
    Mount <-->|Resource mapped| Bind
    Bind <-->|Volume Bind| Trans
    
    %% Control Flow %%
    Radarr & Sonarr & Prowlarr <-->|RPC Port 9091| VPN
```

### Why This Design is Superior:
1. **Bulletproof Kill-Switch (Gluetun):** Gluetun is the gold standard for VPN containerization. If the VPN connection drops, Gluetun instantly blocks all internet traffic via its internal firewall (kill-switch), preventing any BitTorrent downloads from leaking your home WAN IP.
2. **Proxmox-Native SMB Mounting:** Unprivileged LXCs cannot mount SMB/CIFS shares directly without elevated security privileges (which is a risk). Instead, we mount the SMB share on the **Proxmox Host** and map it as an **LXC Bind Mount**. This yields maximum I/O performance and keeps the container secure and lightweight.
3. **Simplified Infrastructure Management:** Docker Compose encapsulates the entire service, making updates, credentials changes, and protocol adjustments a matter of modifying simple environment variables.

---

## 2. Step-by-Step Provisioning Workflow

### Step 1: Mount the SMB Share on the Proxmox Host

We must mount the Synology SMB share (`\\PNAS\Seagate\Share\Downloads\`) to the Proxmox host (`bulakan`) so it can be passed down to LXC 112.

1. SSH into the Proxmox host (`VLAN 1 [Management]`) or use the Host Shell in the Proxmox Web GUI.
2. Create a mount directory:
   ```bash
   mkdir -p /mnt/pve/PNAS-Downloads
   ```
3. Open `/etc/fstab` to make the mount persistent:
   ```bash
   nano /etc/fstab
   ```
4. Add the following line to the bottom, mapping the credentials and setting permissions for the local non-root user (`uid=1000,gid=1000` is the default standard for Docker containers):
   ```text
   //VLAN 1 [Management]/Seagate/Share/Downloads /mnt/pve/PNAS-Downloads cifs credentials=/root/.pnascredentials,iocharset=utf8,uid=1000,gid=1000,file_mode=0775,dir_mode=0775,nofail 0 0
   ```
   > [!NOTE]
   > Replacing `VLAN 1 [Management]` with PNAS's static IP ensures reliable DNS-independent mounting.
5. Create the credentials file securely:
   ```bash
   nano /root/.pnascredentials
   ```
   Add your Synology credentials:
   ```text
   username=YOUR_NAS_USERNAME
   password=YOUR_NAS_PASSWORD
   ```
   Secure the permissions:
   ```bash
   chmod 600 /root/.pnascredentials
   ```
6. Mount the share:
   ```bash
   mount -a
   ```
   Verify that the mount is active and writable:
   ```bash
   ls -la /mnt/pve/PNAS-Downloads
   touch /mnt/pve/PNAS-Downloads/test.txt && rm /mnt/pve/PNAS-Downloads/test.txt
   ```

---

### Step 2: Create / Reconfigure LXC 112 with Nesting and Bind Mounts

To run Docker inside LXC 112, the container must be configured with **Nesting** and **Keyctl** enabled, and we must bind-mount the host downloads path.

#### Option A: Using Terraform (Recommended)
Add the bind-mount and nesting options in your `terraform/proxmox/lxc.tf` configuration:
```hcl
module "transmission" {
  source       = "./modules/lxc"
  node_name    = var.proxmox_node
  vm_id        = 112
  hostname     = "transmission"
  description  = "Transmission BitTorrent client with VPN"
  tags         = ["proxmox-helper-scripts", "downloads"]
  template_id  = var.lxc_template
  datastore_id = var.bulakan_datastore
  memory       = 2048
  cores        = 2
  nesting      = true  # Crucial for running Docker inside LXC
}
```

#### Option B: Manual Proxmox Configuration
If configuring directly on Proxmox:
1. Stop LXC 112 if it is currently running.
2. Edit the container's configuration file on the Proxmox host:
   ```bash
   nano /etc/pve/lxc/112.conf
   ```
3. Ensure nesting is enabled and append the bind mount line:
   ```text
   features: keyctl=1,nesting=1
   mp0: /mnt/pve/PNAS-Downloads,mp=/downloads
   ```
4. Start LXC 112. The host's SMB path `/mnt/pve/PNAS-Downloads` is now mapped natively inside the LXC container under `/downloads`.

---

### Step 3: Install Docker & Docker Compose inside LXC 112

Log into the LXC 112 console (via SSH or Proxmox GUI console) and run:

```bash
# Update system repositories
apt update && apt upgrade -y

# Install Docker dependencies
apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Plugins
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

---

### Step 4: Deploy the Gluetun + Transmission Stack

We will now assemble a cohesive Docker Compose configuration inside the LXC.

1. Create a project directory:
   ```bash
   mkdir -p /opt/torrent-vpn
   cd /opt/torrent-vpn
   ```
2. Create the `docker-compose.yml` file:
   ```bash
   nano docker-compose.yml
   ```
3. Paste the following configuration:

```yaml
services:
  vpn:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    # sysctls are required for Wireguard/OpenVPN protocol operations
    sysctls:
      - net.ipv4.conf.all.src_route_localnet=1
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "9091:9091"      # Transmission Web UI RPC Port (LAN access)
      - "51413:51413"    # Torrent Peer Listening (TCP)
      - "51413:51413/udp" # Torrent Peer Listening (UDP)
    environment:
      - VPN_SERVICE_PROVIDER=surfshark
      - VPN_TYPE=openvpn # You can also use 'wireguard' if you fetch your WG config keys
      # WARNING: Use your Surfshark Service Credentials here (NOT your account email/password!)
      # Get these from Surfshark Dashboard -> VPN -> Manual Setup -> Credentials
      - OPENVPN_USER=YOUR_SURFSHARK_SERVICE_USER
      - OPENVPN_PASSWORD=YOUR_SURFSHARK_SERVICE_PASSWORD
      # Set your target VPN location (e.g. Netherlands, United States, Germany)
      - SURFSHARK_COUNTRY=Netherlands
      # FIREWALL_OUTBOUND_SUBNETS enables LAN nodes (Arr stack) to connect to the exposed RPC port
      - FIREWALL_OUTBOUND_SUBNETS=VLAN 1 (Management)/24
      - TZ=America/Los_Angeles
    restart: always

  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    # Crucial: Forces Transmission network stack to route through Gluetun
    network_mode: "service:vpn"
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
      # Transmission configurations
      - USER=admin  # Change to your chosen Web UI Username
      - PASS=supersecretpassword # Change to your chosen Web UI Password
    volumes:
      # Local LXC config storage
      - /opt/torrent-vpn/config:/config
      # Mount the mapped SMB share into the Transmission container
      - /downloads:/downloads
    depends_on:
      vpn:
        condition: service_started
    restart: always
```

4. Launch the stack:
   ```bash
   docker compose up -d
   ```
5. Monitor log initialization to verify that Surfshark connects successfully:
   ```bash
   docker compose logs -f vpn
   ```
   You should see outputs concluding with `[healthcheck] healthy!` and successful tunneling confirmations.

---

## 3. Integration with the Arr Stack

Since your Arr stack (Radarr, Sonarr, Prowlarr) is running as separate LXC containers on the local `VLAN 1 (Management)/24` network, they need to communicate with Transmission's RPC API.

### Step 1: Verify Direct LAN Accessibility
Because we defined `FIREWALL_OUTBOUND_SUBNETS=VLAN 1 (Management)/24` in Gluetun and exposed the `9091` port on the host, other LAN machines can communicate directly with Transmission.
* Open a browser on your computer and navigate to: `http://VLAN 1 (Management):9091`
* Enter the credentials configured (`admin` / `supersecretpassword`).
* If you see the Transmission Web UI, local port routing is perfectly operational!

---

### Step 2: Configure Radarr and Sonarr
To map Radarr and Sonarr to the new VPN-secured Transmission container:

1. Open your Radarr (`http://VLAN 1 (Management):7878` or similar) / Sonarr Web UI.
2. Navigate to **Settings** -> **Download Clients** -> Click **+ Add**.
3. Select **Transmission**.
4. Configure the settings:
   * **Name:** `Transmission-VPN`
   * **Host:** `VLAN 1 (Management)` (The IP of the Transmission LXC)
   * **Port:** `9091`
   * **Username:** `admin` (Or your custom user)
   * **Password:** `supersecretpassword` (Or your custom password)
   * **Category:** `radarr` (in Radarr) / `sonarr` (in Sonarr)
5. Click **Test**. If successful, click **Save**.

#### Important Gotcha: Remote Path Mappings
If Radarr/Sonarr are running in containers or separate LXCs that access the SMB share using different paths, you **MUST** map them so Sonarr/Radarr can find the downloaded files.
* **Problem:** Transmission reports a finished torrent path as `/downloads/completed/MovieName`. However, Sonarr/Radarr might have mapped the Synology downloads share to `/mnt/downloads/completed/MovieName`.
* **Solution (Remote Path Mapping):**
  1. In Radarr/Sonarr, go to **Settings** -> **Download Clients** -> Scroll to the bottom to **Remote Path Mappings**.
  2. Click **+ Add**.
  3. Configure:
     * **Host:** `VLAN 1 (Management)`
     * **Remote Path:** `/downloads/` (The path Transmission uses)
     * **Local Path:** `/mnt/downloads/` (The path Radarr/Sonarr uses to view the SAME Synology directory)
  4. Save.

---

### Step 3: Configure Prowlarr (Indexer Manager)
Prowlarr manages your indexers and feeds them into Radarr/Sonarr. If you want indexer proxies routed through the VPN or are passing torrent download tasks directly, ensure Transmission is set up as a download client in Prowlarr:
1. Open **Prowlarr** (`http://VLAN 1 (Management):9696`).
2. Go to **Settings** -> **Download Clients** -> Click **+ Add**.
3. Select **Transmission** and configure it with Host `VLAN 1 (Management)` and Port `9091` just as you did above.

---

## 4. Operational Testing & IP Verification

To guarantee that your IP address is protected and files are saving seamlessly, run the following verification checks:

### 1. Verify Public IP of Transmission
Run this command from inside the `transmission` container to verify it is using a Surfshark IP address:
```bash
docker compose exec transmission curl https://ipinfo.io
```
Compare the output against the native Proxmox host public IP:
```bash
# On the Proxmox host:
curl https://ipinfo.io
```
* **Expected Result:** The `transmission` container must show a completely different public IP (Surfshark's server IP) and country than your home physical ISP.

### 2. Verify Kill-Switch Functionality
Test that no traffic leaks if the VPN is dropped:
1. Stop the `vpn` container:
   ```bash
   docker compose stop vpn
   ```
2. Verify that Transmission is completely cut off from the network:
   ```bash
   docker compose exec transmission curl -m 5 https://ipinfo.io
   ```
   * **Expected Result:** The command must timeout or fail immediately with no connectivity. This confirms the kill-switch is working.

---

## Outcomes & Performance Goals
* **Leak-Proof Operations:** All outbound download traffic is encrypted via Surfshark with automated hard kill-switch rules.
* **Storage Consolidation:** Direct download writes to `\\PNAS\Seagate\Share\Downloads\`, preventing the local Proxmox LXC SSD from running out of space.
* **Automation:** Fully integrated with Radarr and Sonarr for hands-free searching, queueing, downloading, and automatic importing.

---

## References & Additional Resources
1. **Gluetun Wiki / Surfshark Setup:** `https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/surfshark.md`  
2. **Proxmox Bind Mount Docs:** `https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points`  
3. [[05-Services/Services Index]] — Overview of CT ID allocations (Transmission CT 112).
4. [[06-Guides/Guides Index]] — Index of step-by-step documentation.
