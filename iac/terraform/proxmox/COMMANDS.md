# Proxmox Terraform Commands

> [!WARNING]
> **Terraform is currently DEPRECATED for management of the Bulakan node.** 
> Use these commands only for the Cebu node or for resource testing. For Bulakan maintenance, use the manual Proxmox Helper Scripts.

## Basic Terraform Workflow

### Initialize
```bash
terraform init
```

### Plan Changes
```bash
terraform plan
```

### Apply Changes
```bash
terraform apply
```

### Destroy Resources
```bash
terraform destroy
```

### Import Existing Resources
```powershell
.\import.ps1 -Module proxmox
```

### Validate Configuration
```bash
terraform validate
```

### Format Configuration
```bash
terraform fmt
```

### Show Current State
```bash
terraform show
```

### Output Values
```bash
terraform output
```

---

## netboot.xyz Deployment

After `terraform apply` creates the container:

### 1. Access the container
```bash
pct exec 118 -- bash
```

### 2. Install netboot.xyz
Run the helper script (from [tteck/Proxmox](https://github.com/tteck/Proxmox)):
```bash
bash -c "$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/netbootxyz.sh)"
```

### 3. Access Web UI
- URL: `http://192.168.1.54:3000` (or DHCP-assigned IP)
- Configure PXE boot options, local asset caching, etc.

### 4. Network Requirements
For PXE booting clients, ensure:
- DHCP server points to `192.168.1.54` for TFTP (option 66/67)
- Firewall allows UDP 69 (TFTP), TCP 80/3000 (HTTP/Web)