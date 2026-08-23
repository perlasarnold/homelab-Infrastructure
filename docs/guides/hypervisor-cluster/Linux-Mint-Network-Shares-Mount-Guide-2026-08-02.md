# 📁 Linux Mint Desktop Network Shares Auto-Mount Guide (Dapitan 192.168.1.27 Focus)

- **Date:** August 2, 2026
- **Objective:** Configure persistent, resilient auto-mounting of all homelab network storage shares—specifically targeting **Dapitan Server (`192.168.1.27`)** ZFS 18TB storage—onto the Linux Mint Desktop VM (`mint-desktop-dapitan`).
- **Target Host:** `mint-desktop-dapitan` (`192.168.20.192` / `192.168.20.70`)
- **Dapitan Server Host:** `192.168.1.27` (Proxmox VE Node 3)
- **Maintainer:** Perlas

---

## 🗄️ Dapitan (`192.168.1.27`) Network Storage Matrix

| Share Name | Dapitan ZFS Path (`192.168.1.27`) | Linux Mint Mount Point | Protocol | Access Mode |
|---|---|---|---|---|
| `media-data` | `/mnt/bindmounts/media-data` (`bulk18/media-data`) | `/mnt/dapitan-media` | CIFS / SMB | Read / Write (`0777`) |
| `shared` | `/mnt/bindmounts/shared` (`bulk18/shared`) | `/mnt/dapitan-shared` | CIFS / SMB | Read / Write (`0777`) |

---

## 🛠️ Step 1: Enable Samba Shares on Dapitan Host (`192.168.1.27`)

If Samba sharing is not yet enabled on the Dapitan host (`192.168.1.27`), run these commands on the **Dapitan Proxmox shell**:

```bash
# 1. Install Samba on Dapitan host
apt update && apt install -y samba

# 2. Append shares to /etc/samba/smb.conf
cat << 'EOF' >> /etc/samba/smb.conf

[media-data]
   path = /mnt/bindmounts/media-data
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   force user = root

[shared]
   path = /mnt/bindmounts/shared
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   force user = root
EOF

# 3. Restart Samba daemon
systemctl restart smbd
```

---

## 🖥️ Step 2: Mount `\\192.168.1.27\` on Linux Mint Desktop

Run this command block inside the **Linux Mint Terminal**:

```bash
# 1. Create mount directories
sudo mkdir -p /mnt/dapitan-media
sudo mkdir -p /mnt/dapitan-shared

# 2. Add resilient automount entries to /etc/fstab
sudo cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d_%H%M%S)

sudo tee -a /etc/fstab > /dev/null << 'EOF'

# --- Dapitan Server (192.168.1.27) 18TB ZFS Shares ---
//192.168.1.27/media-data /mnt/dapitan-media cifs guest,iocharset=utf8,vers=3.0,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,_netdev,nofail,x-systemd.automount 0 0
//192.168.1.27/shared /mnt/dapitan-shared cifs guest,iocharset=utf8,vers=3.0,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,_netdev,nofail,x-systemd.automount 0 0
EOF

# 3. Reload systemd and mount
sudo systemctl daemon-reload
sudo mount -a

# 4. Add GUI bookmarks to Nemo File Manager
mkdir -p ~/.config/gtk-3.0
tee -a ~/.config/gtk-3.0/bookmarks > /dev/null << 'EOF'
file:///mnt/dapitan-media Dapitan-18TB-Media
file:///mnt/dapitan-shared Dapitan-18TB-Shared
EOF

echo "=== ✅ Dapitan 192.168.1.27 shares mounted successfully! ==="
df -h | grep /mnt/dapitan
```

---

## 🔍 Verification

1. Check active mount status:
   ```bash
   df -h | grep dapitan
   ```
2. Verify Nemo sidebar: Open **Files** on Linux Mint to see `Dapitan-18TB-Media` and `Dapitan-18TB-Shared` in the sidebar.

---

## 🔗 References

- [[OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22]] — Dapitan 18TB ZFS dataset structure
- [[Network Overview]] — Subnet and host IP mapping
