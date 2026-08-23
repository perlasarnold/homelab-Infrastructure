# Netboot.xyz Deployment Status

## ✅ Completed

| Step | Status |
|------|--------|
| Terraform installed | ✓ |
| Container configuration created | ✓ |
| All LXC configs updated for provider v0.103.0 | ✓ |
| Terraform.tfvars created with API token | ✓ |
| Terraform initialized | ✓ |

## ⚠️ Manual Steps Required

The deployment failed because the **LXC template is not available** on the Proxmox server.

### Step 1: Download Debian 12 Template

You need to download the LXC template to your Proxmox node. Choose **one** method:

#### Option A: Proxmox Web UI (Easiest)

1. Open https://VLAN 1 [MGMT]:8006
2. Navigate to **local (Storage)** → **CT Templates**
3. Click **Templates** button
4. Find and download: `debian-12-standard`
5. Wait for download to complete (typically 100-200 MB)

#### Option B: Command Line (via SSH)

```bash
# SSH into Proxmox
ssh root@VLAN 1 [MGMT]

# Update template list
pveam update

# Search for available Debian 12 templates
pveam available | grep debian-12

# Download the template (use exact name from above)
pveam download local debian-12-standard_12.0-1_amd64.tar.zst

# Verify it's downloaded
ls -la /var/lib/vz/template/cache/
```

#### Option C: Using PowerShell (from this machine)

```powershell
# Run the helper script I created
.\Download-LXCTemplate.ps1 -ProxmoxHost VLAN 1 [MGMT]
```

### Step 2: Update Template Name (if needed)

Once you know the exact template name, update `terraform.tfvars`:

```hcl
lxc_template = "local:vztmpl/YOUR_EXACT_TEMPLATE_NAME.tar.zst"
```

### Step 3: Re-deploy

```powershell
cd /opt/homelab-infrastructure\terraform\proxmox
terraform apply -target="proxmox_virtual_environment_container.netbootxyz"
```

---

## 🔧 What Changed

### Files Modified

| File | Change |
|------|--------|
| `lxc.tf` | Added `netbootxyz` container + `template_file_id` for all containers |
| `variables.tf` | Added `lxc_template` variable |
| `terraform.tfvars` | Created with API credentials |
| `terraform.tfvars.example` | Reference template name |
| `import.ps1` | Added import command for CT 118 |
| `outputs.tf` | Added netbootxyz to outputs |
| `COMMANDS.md` | Added deployment guide |

### Container Specs

| Property | Value |
|----------|-------|
| **VM ID** | 118 |
| **Name** | netbootxyz |
| **IP** | VLAN 1 (Mgmt)/24 (static) |
| **Template** | debian-12-standard |
| **CPU** | 2 cores |
| **RAM** | 1024 MB |
| **Disk** | 16 GB (Bulakan-ZFS) |
| **Bridge** | vmbr0 |
| **Unprivileged** | Yes |
| **Nesting** | Disabled (not needed with tteck script) |

---

## 📋 Next Steps After Deployment

1. Container created → Install netboot.xyz software
2. Configure DHCP options for PXE boot
3. Access Web UI at http://VLAN 1 (Mgmt):3000

See full documentation: `../../05-Services/Netbootxyz.md`

---

## 🚨 Security Note

The file `terraform.tfvars` contains your API token. It has been created with:

```
proxmox_api_token = "root@pam!terraform=***"
```

**Actions to take:**
- ✅ Added to `.gitignore` (should already be there)
- ⚠️ Consider restricting the API token in Proxmox:
  - Go to **Datacenter → Permissions → API Tokens**
  - Edit the token to only allow required paths (e.g., `/vms/`, `/nodes/{node}/`)
  - Or rotate the token after deployment

---

## Troubleshooting

### "Permission check failed" Error

If you see this error again, it means the API token doesn't have permission to create privileged containers. The container is now configured as `unprivileged = true` which should work.

### Template Not Found After Download

Verify the exact template name:

```bash
ssh root@VLAN 1 [MGMT]
ls -la /var/lib/vz/template/cache/
```

Then update `terraform.tfvars` with the exact filename.

### Container ID 118 Already Exists

If CT 118 already exists on your Proxmox:

1. **Option 1:** Import it: `terraform import proxmox_virtual_environment_container.netbootxyz Bulakan/118`
2. **Option 2:** Change the VM ID in `lxc.tf` to an unused ID (e.g., 118 → 118 is fine if it doesn't exist)

---

**Status:** Waiting for LXC template download ⏳

**Last Updated:** 2026-04-20
