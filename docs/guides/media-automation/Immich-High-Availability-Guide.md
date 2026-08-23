# 🖼️ Immich High Availability (HA) Architecture & Migration Guide

- **Date:** May 16, 2026
- **Objective:** Establish a resilient, highly available failover strategy for the Immich photo management server (VM 204) across the 2-node Proxmox cluster (`Bulakan` & `Cebu`), while offloading massive storage to external shares to rescue `Bulakan-ZFS` from its **86% capacity limit**.
- **Status:** Proposed / Architectural Blueprint
- **Target Node Failover:** Proxmox Bulakan (`VLAN 1 [Management]`) ➡️ Proxmox Cebu (`VLAN 1 [Management]`)

---

## 🔍 Current Architecture Analysis & Challenges

Your active Immich server runs inside **VM 204 (Immich-UbuntuLTS)** on the primary Proxmox node **Bulakan**.

### 1. The Bottleneck: Local Monolithic Storage
* **State:** VM 204 has a **600GB virtual disk** stored entirely on local ZFS storage (`Bulakan-ZFS`).
* **Impact:** This single virtual disk is the primary reason Bulakan's local SSD pool is **86% full** (1.65 TiB of 1.91 TiB used).
* **HA Obstacle:** You cannot easily perform live migrations or automatic failover of a 600GB virtual disk without shared network storage. Replicating 600GB of active changes over the network frequently will saturate your network and SSD write endurance.

### 2. Stateless vs. Stateful Immich Components
Immich is composed of several distinct services, each with different HA characteristics:
* **Stateless:** `immich-server` (web/API/background tasks) and `immich-machine-learning` (face/CLIP recognition). These can run anywhere.
* **Stateful (Metadata):** `immich-postgres` (database storing albums, relations, metadata, vectors). Requires low-latency storage.
* **Stateful (Assets):** The actual photo/video files (`/usr/src/app/upload`). This represents the **600GB** mass of data, which is high-capacity but mostly write-once-read-many (WORM).

---

## 🏛️ Evaluated Architectural Options

We analyzed two primary pathways to achieve High Availability for your Immich setup:

```mermaid
graph TD
    subgraph Client Traffic Ingress
        A[Nginx Proxy Manager <br> Bulakan/Cebu - VLAN 1 [Management]] -->|Reverse Proxy / SSL| B[Immich VM 204]
    end

    subgraph Primary Node: BULAKAN
        B -->|Local SSD I/O| C[(PostgreSQL & Redis)]
        B -->|Fast LAN Mount| D[Synology PNAS / TrueNAS SCALE]
    end

    subgraph Secondary Node: CEBU
        E[Standby Immich VM 204] -->|Local ZFS Replication| C
        E -->|Fast LAN Mount| D
    end

    classDef primary fill:#2d3748,stroke:#ed8936,stroke-width:2px,color:#fff;
    classDef storage fill:#1a202c,stroke:#4299e1,stroke-width:2px,color:#fff;
    class B,C primary;
    class D storage;
```

### Option 1: Hypervisor-Level HA with ZFS Replication & NAS Offloading (Recommended 🌟)
Instead of trying to cluster the Immich application itself (which is complex and unsupported officially for active-active homelab write operations), we leverage **Proxmox VE's native High Availability (HA) Manager** with a hybrid storage model.

* **Database & OS:** Remain on the local ZFS SSD pool (`Bulakan-ZFS`) for blazing-fast indexing and facial recognition. The virtual disk size is shunk from **600GB to ~40GB**.
* **Photos & Videos:** Mounted inside the VM via **SMB/CIFS** directly from your centralized **TrueNAS SCALE photo share (`\\TRUENAS\photo\Immich\`)** hosted at `VLAN 1 (Management)`.
* **Replication:** Proxmox automated ZFS replication (`pvesr`) syncs the small 40GB VM disk from Bulakan to Cebu (`cebu-zfs`) every 5 to 15 minutes.
* **Pros:** 
  - Frees up **~550GB** of SSD space on Bulakan instantly.
  - Centralizes your entire photo library into a single directory share (`\\TRUENAS\photo\Immich\`) that benefits from TrueNAS ZFS snapshot protection and easy automated renaming tools.
  - Maintains fast database and ML speeds (local ZFS SSD read/write speeds).
  - Simple, robust, and automated failover via Proxmox.
* **Cons:** Requires a Proxmox Quorum Device (QDevice) to prevent split-brain on your 2-node cluster.

### Option 2: Active-Active Application Clustering (Multi-Instance Immich)
In this model, you run two concurrent Immich instances: Instance A on Bulakan and Instance B on Cebu.

* **Implementation:** Both instances connect to a single external PostgreSQL cluster (running pgvector) and a single external Redis instance, with both sharing the NAS asset folder.
* **Pros:** True zero-downtime application-level load balancing.
* **Cons:** 
  - **Single Point of Failure (SPOF):** If your external database VM or Redis goes down, both Immich instances crash. Making PostgreSQL + `pgvector` highly available in a 2-node cluster is highly resource-intensive and fragile.
  - **Job Queue Conflicts:** Immich background workers rely heavily on Redis queues; concurrent writes from multi-instance servers can occasionally cause sync issues in non-k8s environments.

---

## 🛠️ Step-by-Step Implementation Roadmap (Option 1)

### Phase 1: Storage Offloading (Rescuing Bulakan-ZFS)
Before we can enable replication or failover, we must shrink the VM's footprint by moving the photos directly to your centralized TrueNAS SMB share at **`\\TRUENAS\photo\Immich\`**.

1. **Prepare the Network Share**:
   - Log into **TrueNAS SCALE** (`VLAN 1 (Management)`).
   - Inside your `photo` dataset, create an `Immich` folder (resulting in `\\TRUENAS\photo\Immich\`).
   - Create a dedicated TrueNAS system service user (e.g., `immich-svc`) or use your existing credentials that have Full Read/Write access to the `photo` share.

2. **Mount the SMB Share inside VM 204 securely**:
   - SSH into `Immich-UbuntuLTS` (`VLAN 1 (Management)`).
   - Stop your active Immich containers:
     ```bash
     cd /path/to/immich/docker
     docker compose down
     ```
   - Install the Linux CIFS client utility:
     ```bash
     sudo apt update && sudo apt install cifs-utils -y
     ```
   - Create an encrypted credentials file to avoid putting plain-text passwords in `/etc/fstab` (aligning with your repo secrets policy):
     ```bash
     sudo nano /etc/immich-truenas-credentials
     ```
     *Add the following contents:*
     ```text
     username=immich-svc
     password=YOUR_TRUENAS_USER_PASSWORD
     domain=WORKGROUP
     ```
     *Secure the credentials file from non-root reading:*
     ```bash
     sudo chmod 600 /etc/immich-truenas-credentials
     ```

   - Create a temporary mount point to transfer existing photo data:
     ```bash
     sudo mkdir -p /mnt/immich-truenas-temp
     sudo mount -t cifs -o credentials=/etc/immich-truenas-credentials,iocharset=utf8,uid=1000,gid=1000,file_mode=0777,dir_mode=0777 //VLAN 1 (Management)/photo/Immich /mnt/immich-truenas-temp
     ```

3. **Migrate the Photo Assets**:
   - Copy the existing photos from your local VM disk to TrueNAS:
     ```bash
     sudo rsync -avh --progress /data/immich/upload/ /mnt/immich-truenas-temp/
     ```
   - *Rationale:* Running rsync preserves timestamps and permissions, ensuring Immich doesn't re-index or think photos were newly added.

4. **Update the permanent Mount Configuration**:
   - Once the sync completes, make the mount permanent in `/etc/fstab` using optimized CIFS mapping (UID/GID `1000` corresponds to the Docker host runner to ensure correct write permissions):
     ```bash
     sudo nano /etc/fstab
     ```
     *Append the following line at the end of the file:*
     ```text
     //VLAN 1 (Management)/photo/Immich /data/immich/upload cifs credentials=/etc/immich-truenas-credentials,iocharset=utf8,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,nofail,soft,bg 0 0
     ```
   - Unmount the temporary share and mount the new permanent upload path:
     ```bash
     sudo umount /mnt/immich-truenas-temp
     sudo mount -a
     ```
   - Verify the photos are fully accessible under `/data/immich/upload`:
     ```bash
     ls -l /data/immich/upload
     ```

5. **Restart Immich**:
   - Start the containers back up: `docker compose up -d`
   - Verify that your photos load, and the admin interface is fully functional.

6. **Reclaim local disk space on VM 204**:
   - You can now safely shrink the virtual disk size of VM 204 in Proxmox. Or better, create a new compact virtual disk (e.g., 40GB) on Bulakan, migrate the OS/database, and delete the original bloated 600GB virtual disk.

---

### Phase 2: Setup a Corosync QDevice (For 2-Node Cluster Quorum)
Because your Proxmox cluster is 2 nodes (`Bulakan` & `Cebu`), if one node dies, the surviving node will only have **1 out of 2 votes (50%)**, which is not a majority. Proxmox HA will disable itself to prevent split-brain corruption. We must add a **Quorum Device (QDevice)** as a tie-breaker.

1. **Choose a QDevice Host**:
   - A QDevice can be any lightweight Linux instance outside the Proxmox cluster (e.g., a Raspberry Pi, an always-on mini PC, or a tiny VM/LXC running on another system). It only needs to run `corosync-qnetd`.

2. **Install QNetd on the QDevice Host**:
   ```bash
   sudo apt update
   sudo apt install corosync-qnetd -y
   ```

3. **Configure the QDevice on Proxmox Nodes**:
   - Log into **Bulakan** or **Cebu** via SSH.
   - Install the client utility on **both** Proxmox nodes:
     ```bash
     apt update
     apt install corosync-qdevice -y
     ```
   - Initialize the QDevice integration from your primary node:
     ```bash
     pvecm qdevice setup <QDEVICE_IP_ADDRESS>
     ```
   - Verify cluster status: `pvecm status`
   - *Outcome:* You will now see **3 total votes** in `pvecm status`, meaning if either Bulakan or Cebu goes offline, the survivor + QDevice represents **2 out of 3 votes (66%)**, retaining quorum and allowing HA to trigger!

---

### Phase 3: Enable Proxmox ZFS Replication (pvesr)
Since VM 204's OS and database disk are now small (~40GB), we can easily replicate it to Cebu's local ZFS storage (`cebu-zfs`) over the local network.

1. **Configure Replication**:
   - Go to the Proxmox VE Web UI.
   - Select **VM 204** ➡️ **Replication** ➡️ **Add**.
   - **Target Node:** `Cebu`
   - **Schedule:** `*/15` (runs every 15 minutes) or `*/5` (runs every 5 minutes).
   - Click **Create**.
   - *Rationale:* This uses ZFS snapshots to incremental-sync changes. Because the database is the only active local writer, replication runs in seconds, using minimal bandwidth.

---

### Phase 4: Configure Proxmox HA Manager
Now we tell Proxmox to automatically boot Immich on Cebu if Bulakan crashes.

1. **Create an HA Group**:
   - Go to **Cluster** ➡️ **HA** ➡️ **Groups** ➡️ **Create**.
   - **Name:** `HA-Immich-Group`
   - **Nodes:** `Bulakan:2` (Priority 2), `Cebu:1` (Priority 1).
   - **nofailback:** Checked (prevents the VM from flapping back immediately when Bulakan recovers).

2. **Add VM 204 to HA**:
   - Go to **Cluster** ➡️ **HA** ➡️ **Resources** ➡️ **Add**.
   - **VMID:** `204`
   - **Group:** `HA-Immich-Group`
   - **Max Restart:** `3`
   - **Max Relocate:** `1`
   - **State:** `started`

---

## 🔄 Failover & Recovery Behavior

In the event of a physical hardware failure on **Bulakan**:
1. The Corosync cluster detects the node failure within ~10-15 seconds.
2. Because the **QDevice** is active, **Cebu** maintains quorum (2/3 votes).
3. Proxmox HA Manager changes the status of VM 204 to "relocating".
4. Cebu registers the replicated ZFS disk image and powers on **VM 204**.
5. VM 204 boots up, auto-mounts the photo folder from the Synology NAS (`PNAS`), and starts the Immich Docker container stack.
6. **Nginx Proxy Manager** (which is already configured with a standby on Cebu!) detects that VM 204's IP is active and routing traffic, ensuring external access via Cloudflare or Authentik remains seamless.
7. **Maximum Downtime:** **~2 to 3 minutes** (completely automated, zero manual intervention).

---

## ⚠️ Rollback & Risk Analysis

### Risks
* **Data Loss Window:** If Bulakan crashes, any photos uploaded *between* the last ZFS replication snapshot and the crash (up to 15 minutes) will not be in the database on Cebu. 
  - *Mitigation:* Immich's mobile app will simply detect that the photos are missing from the server database during the next background sync and re-upload them automatically. No files are lost.
* **Network Mount Latency:** If the Synology NAS (`PNAS`) is rebooted, the NFS mount inside VM 204 might hang.
  - *Mitigation:* The `nofail,bg,intr` mount flags ensure that the VM doesn't crash during boot if the NAS is temporarily offline, and will gracefully reconnect once available.

### Rollback Plan
If the network mount performance is unacceptable or replication fails:
1. Stop the Immich container on the network mount: `docker compose down`
2. Remove/Comment out the `/etc/fstab` network mount line.
3. Remount the local directory or restore the VM from a Proxmox backup taken prior to the migration.
4. Scale up the local virtual disk back to 600GB.

---

## 🧪 Zero-Downtime Staging & Testing Protocol

Before you make any changes to your active production Immich instance (VM 204), you can fully stage, test, and validate every component of this high availability setup with **zero service disruption**. Follow this phased staging pipeline:

### Stage 1: The "Mock Mount" & Permissions Stage (Zero Downtime)
* **Objective:** Ensure your TrueNAS SCALE SMB share has correct permissions for Linux CIFS write operations before running the production sync.
* **Procedure:**
  1. Create a temporary folder on your TrueNAS share: `\\TRUENAS\photo\Immich_Staging_Test\`.
  2. On **Cebu** (where you have plenty of SSD space), create a lightweight test LXC container or a dummy VM (e.g., `VM 999`).
  3. Install CIFS client utilities and mount the staging share inside the test machine:
     ```bash
     sudo apt update && sudo apt install cifs-utils -y
     sudo mkdir -p /mnt/immich-test
     sudo mount -t cifs -o username=immich-svc,password=TEST_PASSWORD,iocharset=utf8,uid=1000,gid=1000,file_mode=0777,dir_mode=0777 //VLAN 1 (Management)/photo/Immich_Staging_Test /mnt/immich-test
     ```
  4. Run a tiny test Docker Compose stack (even just a simple busybox write container or a fresh Immich trial) pointing to `/mnt/immich-test`.
  5. **Validation:** Verify you can write, edit, and delete files from the container. Check that the GIDs/UIDs and write parameters on the TrueNAS SMB share map correctly without permission errors.

### Stage 2: Safe QDevice Cluster Integration (Online, Zero Downtime)
* **Objective:** Join the 3rd quorum vote to the live cluster without taking down Bulakan or Cebu.
* **Procedure:**
  1. Provision `corosync-qnetd` on your lightweight external device (e.g., a Pi, active VM, or secondary server).
  2. Install client tools and run `pvecm qdevice setup <IP>` from Bulakan.
  3. **Validation:** Run `pvecm status`. This process runs dynamically. Corosync reloads its config live—**no VMs are restarted, no nodes are rebooted, and no services are interrupted.** You will immediately see the vote count jump to 3.

### Stage 3: Live "Dummy" HA Failover Auditing (Zero Downtime for VM 204)
* **Objective:** Verify that Proxmox HA group priority, virtual bridge networking, and standby storage failovers function exactly as designed using a sandbox VM.
* **Procedure:**
  1. Clone an existing small test VM or create a tiny 10GB Debian VM (e.g., `VM 900 - HA-Staging`) on Bulakan.
  2. Enable **ZFS replication** for `VM 900` to target Cebu every 5 minutes.
  3. Add `VM 900` to the `HA-Immich-Group` in the HA Resource manager.
  4. **Test 1 (Zero-Downtime Live Migration):** Perform a manual live migration of `VM 900` from Bulakan to Cebu. Proxmox will transfer the active RAM state seamlessly using the replicated ZFS baseline. Verify that the VM remains pingable throughout the migration.
  5. **Test 2 (Simulated Crash Failover):** Log into `VM 900` and run a shutdown command (to simulate VM death) OR temporarily simulate a network disconnect on its interface. Watch Proxmox HA automatically register the event and coordinate restart parameters on Cebu.

### Stage 4: Background Pre-Migration Storage Sync (Zero Downtime)
* **Objective:** Copy 600GB of photos to the network share without locking Immich or causing hours of service outage.
* **Procedure:**
  1. **Do not stop Immich yet.** 
  2. Mount the destination NAS upload folder to a temporary mount point inside your active VM 204 (e.g., `/mnt/immich-nas-migration`).
  3. Run a **live background rsync** while Immich is actively running:
     ```bash
     sudo rsync -avh --progress --exclude='thumbs' /data/immich/upload/ /mnt/immich-nas-migration/
     ```
  4. *Rationale:* This will migrate 99% of your 600GB library in the background while users are actively viewing and uploading photos. This background copy can run for hours or days with zero impact.
  5. **The Final Cut-Over (Only 3 minutes of downtime):** Only when the giant initial sync is complete, schedule a brief 3-minute maintenance window. Stop the Immich container, run a final quick rsync catch-up (which will only take seconds to copy any newly uploaded images), adjust the `/etc/fstab` path, and bring the container back up!

---

## 📚 References
- [Immich Official Documentation on Database/Asset Storage](https://immich.app/docs/features/custom-folder)
- [Proxmox VE High Availability Cluster Guide](https://pve.proxmox.com/pve-docs/chapter-ha-manager.html)
- [Proxmox VE Corosync QDevice Setup Guide](https://pve.proxmox.com/wiki/Cluster_Manager#pve-qdevice)
