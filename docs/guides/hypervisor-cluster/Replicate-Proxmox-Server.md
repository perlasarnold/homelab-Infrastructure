# 🔄 Replicating Proxmox Server to New Hardware

This guide walks you through the process of replicating your current Proxmox server setup to new hardware.

> [!IMPORTANT]
> While this repository contains Terraform configurations, management for the primary node (**Bulakan**) has shifted to **Manual Provisioning** (using Proxmox Helper Scripts) due to provider reliability issues. Use Terraform primarily for the **Cebu** node or as a configuration reference.

## Overview

The process involves:
1. Installing Proxmox VE on new hardware
2. Configuring basic settings (network, storage)
3. Setting up Terraform with your configuration
4. Applying the Terraform configuration to recreate all VMs and containers
5. Verifying the replication was successful

## Prerequisites

- New hardware meeting or exceeding original server specifications
- Proxmox VE installation media (matching major version preferred)
- Access to the original server's Terraform configuration (this repository)
- Basic knowledge of Linux command line and Terraform

## Step-by-Step Process

### Phase 1: Prepare New Hardware

#### 1. Install Proxmox VE
1. Download Proxmox VE ISO from [proxmox.com](https://www.proxmox.com/en/downloads)
2. Install Proxmox VE on the new hardware following standard installation process
3. During installation, note:
   - Root password
   - Management interface IP address
   - Hostname

#### 2. Initial Configuration
1. Access the Proxmox web interface at `https://<new-server-ip>:8006`
2. Log in with root credentials
3. Update Proxmox to match the original version if needed:
   ```bash
   pve-version
   apt update && apt dist-upgrade
   ```

### Phase 2: Configure Infrastructure to Match Original

#### 3. Network Configuration
Compare with original network setup from `02-Proxmox/Proxmox Overview.md`:

**Original Configuration:**
- Host IP: `VLAN 1 [Management]`
- Node Name: `Bulakan`
- vmbr0: Linux Bridge `VLAN 1 [Management]/24`
- bond0: Active-Backup Bond (enp1s0 + enx000000000000)

**On new hardware:**
1. Adjust network interfaces in `/etc/network/interfaces` or via web UI
2. Update hostname if desired:
   ```bash
   hostnamectl set-hostname <new-hostname>
   ```
3. Update `/etc/hosts` and `/etc/hostname` accordingly

#### 4. Storage Configuration
Match storage pools from original:

**Original Storage Pools:**
- Bulakan-ZFS (ZFS) - Disk images, Containers
- PNAS (SMB/CIFS → Unraid) - Backups, ISOs, Templates
- local (Directory `/var/lib/vz`) - Backups, ISOs, Templates
- local-lvm (LVM-Thin) - Disk images, Containers

**On new hardware:**
1. Create matching storage pools via Datacenter → Storage in web UI
2. Use same names where possible, or plan to update variables later
3. For ZFS pools, ensure matching configuration if data migration is needed

### Phase 3: Prepare Terraform Configuration

#### 5. Clone Repository (if not already done)
```bash
git clone <repository-url>
cd homelab
```

#### 6. Configure Terraform Variables
1. Copy example variables file:
   ```bash
   cp terraform/proxmox/terraform.tfvars.example terraform/proxmox/terraform.tfvars
   ```
2. Edit `terraform.tfvars` with new server details:
   ```hcl
   proxmox_endpoint  = "https://<new-server-ip>:8006"
   proxmox_node      = "<new-hostname>"  # or keep original if preferred
   default_bridge    = "vmbr0"           # change if using different bridge
   default_datastore = "<your-datastore-name>"  # e.g., "local-zfs"
   proxmox_api_token = "<your-api-token>"  # see step 7
   ```

#### 7. Create API Token
1. In Proxmox web UI: Datacenter → API Tokens → Add
2. User: `root@pam` (or create dedicated service account)
3. Token ID: `terraform`
4. Privilege Separation: **unchecked** (or assign PVEAdmin role)
5. Copy the generated secret (shown only once)
6. Format: `root@pam!terraform=<your-secret>`

### Phase 4: Apply Terraform Configuration

#### 8. Initialize and Plan
```bash
cd terraform/proxmox
terraform init
terraform plan -var-file="terraform.tfvars"
```
Review the plan to ensure it shows creation of all expected resources.

#### 9. Apply Configuration
```bash
terraform apply -var-file="terraform.tfvars"
```
Confirm with "yes" when prompted.

#### 10. Alternative: Import Existing Resources
If you want to import existing VMs/containers rather than recreate them:
```bash
# First, ensure basic Terraform setup is complete
terraform init

# Then run the import script
cd ../../..
.\terraform\import.ps1 -Module proxmox
```

### Phase 5: Verification and Cleanup

#### 11. Verify All Resources Created
1. Check Proxmox web UI for all VMs and containers
2. Verify they have correct:
   - IDs
   - Names
   - CPU/RAM/Disk allocations
   - Network settings
   - OS types

#### 12. Start Services
Most services should start automatically, but you can manually start any that didn't:
```bash
# Start all LXC containers
pct list | awk '{if(NR>1 && $3=="stopped") system("pct start " $1)}'

# Start all VMs
qm list | awk '{if(NR>1 && $3=="stopped") system("qm start " $1)}'
```

#### 13. Update Documentation
1. Update `02-Proxmox/Proxmox Overview.md` with new server details
2. Update any other documentation referencing specific IPs or hostnames

## Troubleshooting

### Common Issues

#### "permission denied" errors
- Ensure API token has sufficient permissions (PVEAdmin role recommended)
- Verify token format is correct: `userid@realm!tokenid=<secret>`

#### Storage mismatches
- If using different storage names, either:
  1. Update `default_datastore` in variables
  2. Or edit individual resources in `.tf` files to use correct storage

#### Network issues
- Verify bridge names match (`vmbr0` by default)
- Check firewall settings if services aren't accessible

#### Version mismatches
- Significant Proxmox version differences may cause compatibility issues
- Try to match major version (e.g., both 8.x)

## Reproducibility Checklist

When setting up a new Proxmox node:

1. [ ] Install Proxmox VE (match major version: 8.4.14)
2. [ ] Configure network interfaces (adjust vmbr0/bond0 as needed)
3. [ ] Create storage pools (match names or update variables)
4. [ ] Generate API token with appropriate permissions
5. [ ] Update `terraform.tfvars` with node-specific values
6. [ ] Run `terraform init` and `terraform apply`
7. [ ] Verify all containers/VMs start correctly
8. [ ] Update documentation with new node details

## Notes

- This process creates new VMs/containers rather than migrating existing data
- For data migration, consider using Proxmox backup/restore or storage migration tools
- The Terraform approach ensures infrastructure-as-code reproducibility
- Always review `terraform plan` output before applying to avoid unexpected changes

## References

- [Proxmox Terraform Provider Documentation](https://registry.terraform.io/providers/bpg/proxmox/latest)
- Original Server Overview: `02-Proxmox/Proxmox Overview.md`
- Terraform Commands: `terraform/proxmox/COMMANDS.md`