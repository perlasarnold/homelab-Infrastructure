# 🎓 Complete Terraform Walkthrough: Deploying Netboot.xyz

> **For:** New Terraform/Ansible users  
> **Goal:** Understand every step of the deployment process  
> **Estimated Time:** 30-45 minutes

---

## Phase 1: Understanding Our Project Structure

Let's start by examining what we have:

```
/opt/homelab-infrastructure\terraform\proxmox\
├── main.tf                    ← Provider configuration (Proxmox API)
├── variables.tf               ← Input variables (placeholders)
├── lxc.tf                     ← Container definitions (19 containers!)
├── vms.tf                     ← VM definitions (5 VMs)
├── outputs.tf                 ← Output values (IDs, IPs, etc.)
├── terraform.tfvars           ← Secret values (API tokens)
├── terraform.tfvars.example   ← Example template
├── .terraform.lock.hcl        ← Version lock file
├── .terraform\                ← Provider plugins cache
├── COMMANDS.md                ← Command reference
└── DEPLOYMENT_STATUS.md       ← Our deployment notes
```

### Key Concept: Why These Files?

| File | Purpose | Analogy |
|------|---------|---------|
| **main.tf** | Says "Connect to Proxmox at this URL" | Like entering server address in a game |
| **variables.tf** | Says "I accept endpoint, token, bridge names" | Like a form with blank fields |
| **terraform.tfvars** | Fills in the form with real values | Your actual password, server IP |
| **lxc.tf** | Describes each container's specs | Blueprint for building a house |
| **.tfstate** | Tracks what was created | Inventory list of what exists |

#### Why separate secrets into .tfvars?

Imagine you share your Terraform code on GitHub:
- ✅ `main.tf` can be public (just says "I need a token")
- ❌ `terraform.tfvars` should NEVER be public (has your actual token)
- 🔒 `.gitignore` should exclude `*.tfvars` files

---

## Phase 2: Prepare Proxmox (Manual Step)

Before Terraform can create containers, Proxmox needs an **LXC template** — the base operating system image.

### Step 2.1: Check Available Templates

1. **Open Proxmox Web UI:** https://VLAN 1 [MGMT]:8006
2. **Login** with your credentials
3. **Look at the left sidebar:** See the storage list

```
Datacenter
└── Bulakan (your node)
    ├── local (/var/lib/vz)
    │   ├── Content ← CLICK HERE
    │   └── CT Templates
    ├── local-lvm (...)
    └── Bulakan-ZFS (...)
```

4. **Click on "local"** → **"CT Templates"** tab
5. **What's there?** Probably empty or has a few templates

### Step 2.2: Download Debian 12 Template

This is the operating system your container will run.

**Method A: Web UI (Easiest)**

1. In **local** storage, click **"Templates"** button
2. Type "debian-12" in the search box
3. Find: `debian-12-standard_12.x-1_amd64.tar.zst`
4. **Click Download**
5. Wait for it to finish (progress bar at bottom)

**Method B: Command Line (SSH)**

From your PC's terminal:

```bash
# SSH into Proxmox
ssh root@VLAN 1 [MGMT]

# Update template database
pveam update

# List available Debian 12 templates
pveam available | grep debian-12

# Should show something like:
# system  debian-12-standard_12.0-1_amd64.tar.zst             
# system  debian-12-standard_12.7-1_amd64.tar.zst    

# Download it (use exact name from above)
pveam download local debian-12-standard_12.0-1_amd64.tar.zst

# Verify it downloaded
ls -lh /var/lib/vz/template/cache/
```

### Step 2.3: Verify Template Name

**Important:** The exact filename matters. Check it:

```bash
ssh root@VLAN 1 [MGMT] ls -la /var/lib/vz/template/cache/
```

You'll see something like:
```
debian-12-standard_12.0-1_amd64.tar.zst
```

**Update your terraform.tfvars:**

```powershell
cd /opt/homelab-infrastructure\terraform\proxmox
notepad terraform.tfvars
```

Make sure this line matches:
```hcl
lxc_template = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
#                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#                         Must match EXACTLY what you saw above
```

---

## Phase 3: Run Terraform (The Deployment!)

Now the fun part — actually creating things!

### Step 3.1: Verify Installation

Open PowerShell and check Terraform is installed:

```powershell
cd /opt/homelab-infrastructure\terraform\proxmox

# Check version
$/home/admin\AppData\Local\Microsoft\WinGet\Links\terraform.exe --version
# Should show: Terraform v1.14.x
```

If you get "command not found", use the full path:
```powershell
& "/home/admin\AppData\Local\Microsoft\WinGet\Links\terraform.exe" version
```

### Step 3.2: Terraform Workflow (The 4 Commands)

Terraform always follows this pattern:

```
1. terraform init      → Download providers (plugins)
2. terraform plan      → Preview what will change
3. terraform apply     → Make the changes
4. terraform destroy   → Tear everything down (careful!)
```

We've already done **init** (when I ran it earlier). Let's continue:

### Step 3.3: Plan (Preview Changes)

```powershell
# Set an alias for easier typing (optional)
$tf = "/home/admin\AppData\Local\Microsoft\WinGet\Links\terraform.exe"

# Plan targeting only the netboot container
& $tf plan -target="proxmox_virtual_environment_container.netbootxyz"
```

**What you'll see:**
- Terraform connects to Proxmox API
- Compares "desired state" (lxc.tf) with "actual state" (Proxmox)
- Shows: "1 to add, 0 to change, 0 to destroy"
- Lists all the properties it will set

**Key output to confirm:**
```
+ resource "proxmox_virtual_environment_container" "netbootxyz" {
    + vm_id       = 118
    + node_name   = "Bulakan"
    + description = "netboot.xyz - PXE network boot server"
    + unprivileged = true
    ...
  }

Plan: 1 to add, 0 to change, 0 to destroy.
```

### Step 3.4: Apply (Create the Container!)

```powershell
# Apply the changes
& $tf apply -target="proxmox_virtual_environment_container.netbootxyz"
```

**What happens:**

1. Terraform asks: `Do you want to perform these actions?` 
2. Type **yes** and press Enter
3. Terraform sends API requests to Proxmox
4. Proxmox:
   - Creates CT 118
   - Extracts Debian template
   - Configures network (VLAN 1 (Mgmt))
   - Sets CPU (2 cores), RAM (1GB), disk (16GB)
5. Terraform saves state to `.tfstate` file

**Expected output (~2-3 minutes):**
```
proxmox_virtual_environment_container.netbootxyz: Creating...
proxmox_virtual_environment_container.netbootxyz: Still creating... [10s elapsed]
...
proxmox_virtual_environment_container.netbootxyz: Creation complete after 2m15s

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### Step 3.5: Verify in Proxmox

1. **Refresh Proxmox Web UI** (F5)
2. **Look for CT 118** in the left sidebar
3. **Click on it** → Console tab
4. **Should see:** A running Debian container with hostname `netbootxyz`
5. **Try pinging it:**
   ```powershell
   ping VLAN 1 (Mgmt)
   # Should reply!
   ```

---

## Phase 4: Install Netboot.xyz Software

The container is just Debian right now — it doesn't have netboot.xyz yet!

### Step 4.1: Understand "Unmanaged" vs "Template-based"

**Two ways to create Proxmox containers:**

| Type | How It Works | Example |
|------|--------------|---------|
| **Template-based** | Pre-built with software | Turnkey Linux containers |
| **Unmanaged** | Manual OS install, then add software | Our netbootxyz container |

We used **unmanaged** because:
- netboot.xyz isn't a standard Proxmox template
- We run a helper script that installs Docker + netboot.xyz
- Gives more control over configuration

### Step 4.2: Access the Container Console

**Option A: Proxmox Web Console** (Easiest)

1. In Proxmox UI, click **CT 118 (netbootxyz)**
2. Click **Console** tab
3. **Login:** `root` (password is blank or see container config)

**Option B: SSH from Proxmox**

```bash
# From Proxmox shell
pct enter 118

# Now you're inside the container
whoami  # Should show: root
hostname  # Should show: netbootxyz
```

**Option C: Direct SSH (after setup)**

```bash
ssh root@VLAN 1 (Mgmt)
```

### Step 4.3: Install Netboot.xyz

The [tteck helper script](https://tteck.github.io/Proxmox/) automates everything:

```bash
# Inside the container

# Download and run the install script
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/netbootxyz.sh)"
```

**What the script does (~5-10 minutes):**

1. Updates Debian packages (`apt update && apt upgrade`)
2. Installs Docker and Docker Compose
3. Clones netboot.xyz-docker repository
4. Creates Docker network and volumes
5. Starts services:
   - `netbootxyz-web` (Web UI on port 3000)
   - `netbootxyz-tftp` (TFTP on port 69)
   - `netbootxyz-nginx` (HTTP on port 80)

**Script interaction:**
- May ask if you want to "Install Netboot.xyz?" → Type **y**
- Shows progress with colored output

### Step 4.4: Verify Services

After script completes:

```bash
# Check Docker is running
docker ps

# Expected output:
CONTAINER ID   IMAGE                     PORTS                  NAMES
abc123...      ghcr.io/netbootxyz/web    0.0.0.0:3000->3000    netbootxyz-web
xyz789...      ghcr.io/netbootxyz/tftp   0.0.0.0:69/udp         netbootxyz-tftp
...

# Test web interface
curl http://localhost:3000
```

### Step 4.5: Access Web UI from Your PC

1. **Open browser:** http://VLAN 1 (Mgmt):3000
2. **Should see:** Netboot.xyz Web UI

**If it doesn't load:**
- Check firewall: `pct exec 118 -- ufw status`
- Verify Docker: `pct exec 118 -- docker logs netbootxyz-web`

---

## Phase 5: Configure PXE Boot (The Magic!)

Now for the cool part — making other computers boot from this.

### Step 5.1: Understand PXE Boot Flow

```
┌──────────────┐                     ┌──────────────┐
│  Client PC   │      Step 1:        │   Your PC    │
│  (blank/new) │   ┌──────────────►  │  (netboot)   │
│              │   │  "I need OS!"   │  VLAN 1 (Mgmt)│
└──────────────┘   │                  └──────────────┘
      ▲            │
      │            │ Step 2: "DHCP says TFTP is at VLAN 1 (Mgmt)"
      │            │
      └────────────┤ Step 3: Downloads boot files via TFTP
                   │ Step 4: Boots menu, loads ISO over HTTP
                   └
```

### Step 5.2: Configure DHCP Options

Your DHCP server (usually router or Pi-hole) needs to tell clients about the PXE server.

#### Option A: Pi-hole DHCP (You have CT 301!)

1. **Login to Pi-hole:** http://VLAN 1 (Mgmt)/admin (or check CT 301's IP)
2. **Settings** → **DHCP** tab
3. **Enable DHCP server** if not already enabled
4. **Find "PXE/TFTP Server" settings:**
   - **TFTP Server:** `VLAN 1 (Mgmt)`
   - **Boot File:** `netboot.xyz.kpxe` (for BIOS) or `netboot.xyz.efi` (for UEFI)
5. **Save settings**

**Why this works:** When a PXE client boots, it asks DHCP: "Who's the TFTP server?" Pi-hole replies: "VLAN 1 (Mgmt)" and the client downloads the boot files.

#### Option B: Router DHCP

Every router is different, but look for:
- **Boot Server** or **TFTP Server:** `VLAN 1 (Mgmt)`
- **Network Boot Filename:** `netboot.xyz.kpxe`
- **DHCP Options:** 66 (TFTP server), 67 (bootfile)

Common locations:
- **ASUS:** Administration → Services → DHCP Server → "Enable PXE Server"
- **Ubiquiti/UniFi:** Settings → Networks → DHCP → "TFTP Server"
- **TP-Link:** Advanced → Network → DHCP → "PXE"

#### Option C: Test Without DHCP (Chainloading)

If you can't modify DHCP:

1. **Create a bootable USB** with netboot.xyz client
2. **Boot from USB** on target machine
3. **USB loads** → Chainloads to local server

Download from: https://netboot.xyz/docs/booting/usb

### Step 5.3: Test PXE Boot

Find a spare computer or VM:

1. **Enter BIOS/UEFI settings** (F2, F10, F12, DEL)
2. **Enable Network Stack / PXE Boot**
3. **Set boot priority:** Network/PXE to first
4. **Save and exit**
5. **Should see:**
   - DHCP request
   - TFTP download
   - Netboot.xyz menu appears!

**Common BIOS settings to enable:**
- "Network Stack" → Enabled
- "PXE Boot" → Enabled  
- "IPv4 Network Stack" → Enabled
- Boot order: "UEFI: IPv4" before hard drive

### Step 5.4: Troubleshoot Boot Issues

**"No boot device found"**
- DHCP not configured → Check Step 5.2
- Wrong boot filename → Try `undionly.kpxe` instead

**"TFTP timeout"**
- Firewall blocking UDP 69
- Container not running TFTP service → `docker ps` in container

**"Can't reach HTTP server"**
- Check ports 80/3000 accessible
- Verify container IP: `pct exec 118 -- ip addr`

---

## Phase 6: Configure Netboot.xyz

The Web UI (http://VLAN 1 (Mgmt):3000) lets you:

### Step 6.1: Enable Local Asset Caching

**Why:** Downloads ISOs once, serves from local network (fast!)

1. **Web UI** → **Settings** → **Local Assets**
2. **Enable:** "Cache Assets Locally" ✅
3. **Storage Path:** `/assets` (or `/opt/netbootxyz/assets`)
4. **Save**

### Step 6.2: Customize Boot Menu

1. **Menus** → Choose which OS lists appear
2. **Hide** things you don't use (makes menu faster)
3. **Enable:** Local mirrors for faster downloads

### Step 6.3: Monitor Usage

**Dashboard shows:**
- Recent boots
- Downloaded assets
- System health

---

## Phase 7: Terraform State Management

### Step 7.1: What is State?

Terraform keeps a **state file** (`.tfstate`) that maps configurations to real resources:

```json
{
  "resources": [
    {
      "type": "proxmox_virtual_environment_container",
      "name": "netbootxyz",
      "instances": [{
        "attributes": {
          "vm_id": 118,
          "id": "Bulakan/118"
        }
      }]
    }
  ]
}
```

**Important:** Don't edit this file manually!

### Step 7.2: View Current State

```powershell
# See what's tracked
& $tf show

# List all resources
& $tf state list

# Show specific resource
& $tf show proxmox_virtual_environment_container.netbootxyz
```

### Step 7.3: Import Existing Resources

If CT 118 already existed from before:

```powershell
# Tell Terraform "this already exists"
& $tf import proxmox_virtual_environment_container.netbootxyz Bulakan/118

# Then Terraform won't try to create it
```

Run the import script I created:
```powershell
cd /opt/homelab-infrastructure\terraform
.\import.ps1 -Module proxmox
```

### Step 7.4: Modify Resources

**Scenario:** You want to change RAM from 1GB to 2GB:

1. **Edit `lxc.tf`:**
```hcl
memory {
  dedicated = 2048  # Changed from 1024
}
```

2. **Plan changes:**
```powershell
& $tf plan
# Shows: 0 to add, 1 to change, 0 to destroy
```

3. **Apply:**
```powershell
& $tf apply
# Stops container, changes RAM, starts container
```

**Terraform is smart:** It only changes what's different!

---

## Phase 8: Destroy (When Needed)

To delete the container:

```powershell
& $tf destroy -target="proxmox_virtual_environment_container.netbootxyz"
# Type: yes
```

**What happens:**
1. Stops container
2. Deletes CT 118
3. Removes from .tfstate
4. **Data is gone!** (Unless you have backups)

**Safer alternative:** Just stop it in Proxmox UI without destroying

---

## Phase 9: Git Workflow

### Step 9.1: Track Changes

```powershell
cd /opt/homelab-infrastructure

# See what changed
git status

# Add modified files
git add terraform/proxmox/lxc.tf
git add terraform/proxmox/variables.tf

# Commit with message
git commit -m "feat: add netboot.xyz container (CT 118)

- Add netbootxyz LXC container with PXE capabilities
- Add lxc_template variable for provider v0.103 compatibility
- Update all existing containers with template_file_id
- Add deployment documentation"

# Push to GitHub
git push origin main
```

### Step 9.2: What NOT to Commit

**.gitignore** should have:
```
*.tfvars          # Contains secrets
.terraform/       # Provider cache (re-downloadable)
*.tfstate*        # State files (sensitive data)
crash.log
```

**If you accidentally commit secrets:**
1. Delete token from Proxmox UI → API Tokens
2. Create new token
3. Update terraform.tfvars locally
4. Rotate committed secrets with `git filter-repo` or GitHub support

---

## Phase 10: Documentation Review

### Documents We Created

| Document | Location | Purpose |
|----------|----------|---------|
| **Netbootxyz.md** | `05-Services/` | Complete setup guide for this service |
| **COMMANDS.md** | `terraform/proxmox/` | Command cheatsheet |
| **DEPLOYMENT_STATUS.md** | `terraform/proxmox/` | Deployment notes |
| **Walkthrough** | `06-Guides/` | This file! |

### Why Documentation Matters

Imagine you need to recreate this in 6 months:
- ❌ Without docs: "Why was CT 118 configured this way?"
- ✅ With docs: "According to Netbootxyz.md, here's the network config..."

---

## 🎓 Key Concepts Summary

### Terraform Concepts

| Concept | Explanation |
|---------|-------------|
| **Resource** | Thing to create (container, VM, etc.) |
| **Provider** | Plugin to talk to APIs (Proxmox, AWS, etc.) |
| **State** | Tracking file of what exists |
| **Variable** | Placeholder for configuration |
| **Output** | Values shown after apply |
| **Module** | Reusable group of resources |

### Proxmox Concepts

| Concept | Explanation |
|---------|-------------|
| **LXC** | Linux Containers (lightweight VMs) |
| **Template** | Base OS image (debian-12-standard) |
| **VMID** | Unique ID for each container/VM |
| **Storage** | Where files go (local, ZFS, etc.) |
| **Bridge** | Network interface (vmbr0) |

### Networking Concepts

| Concept | Explanation |
|---------|-------------|
| **DHCP** | Auto-assigns IP addresses |
| **TFTP** | Trivial File Transfer Protocol (PXE boot) |
| **PXE** | Preboot Execution Environment (network boot) |
| **iPXE** | Enhanced PXE with HTTP support |

---

## 🚀 Next Steps

Now that you understand the process:

1. **Deploy more containers** — Try adding another service!
2. **Learn Ansible** — Automate software installation (replace tteck script?)
3. **Set up GitHub Actions** — Auto-validate Terraform on commit
4. **Create modules** — Make reusable container templates
5. **Explore other providers** — AWS, Azure, Docker, Kubernetes

---

## 📚 Additional Resources

- **Terraform Tutorial:** https://learn.hashicorp.com/terraform
- **Proxmox Provider Docs:** https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- **Netboot.xyz Docs:** https://netboot.xyz/docs/
- **TTeck Scripts:** https://tteck.github.io/Proxmox/

---

**Questions?** Common commands in `COMMANDS.md`!  
**Last Updated:** 2026-04-20
