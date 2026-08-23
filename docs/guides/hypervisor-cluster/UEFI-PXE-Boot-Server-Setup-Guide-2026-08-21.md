# 🚀 UEFI PXE Boot & Automated OS Installation Setup Guide (Dapitan Tiered-Storage Architecture)

- **Date:** August 21, 2026
- **Target Node:** **Dapitan** (VLAN 1 [Management] / VLAN 10 (SecOps))
- **Objective:** Deploy an ultra-efficient UEFI/BIOS PXE Boot, TFTP, and HTTP Kickstart server inside **CT 513** (pxe-dapitan) on **VLAN 110 (Services)** with domain **pxe.homelab-admin.me**, leveraging Dapitan's **1TB SSD (m-fast)** for fast I/O and **18TB HDD (ulk18)** for mass OS repository/ISO storage.
- **Reference Article:** [Red Hat: How to set up PXE boot for UEFI hardware](https://www.redhat.com/en/blog/pxe-boot-uefi)
- **Maintainer:** Perlas

---

## ⚡ Tiered-Storage Architecture (Efficiency Design)

To avoid filling Dapitan's **1TB SSD (m-fast)** with heavy ISOs and operating system package trees (which can quickly consume 50-100GB+ across multiple distros), storage is split into two specialized tiers:

`
+---------------------------------------------------------------------------------------------------+
|                                  DAPITAN TWO-TIER STORAGE MODEL                                    |
+---------------------------------------------------------------------------------------------------+

   TIER 1: HIGH-SPEED SSD (vm-fast - Samsung 870 QVO 1TB)
   ├── CT 513 Root Filesystem (8 GB minimal footprint)
   ├── /var/lib/tftpboot/ (shimx64.efi, grubx64.efi, grub.cfg)
   │     └── Ultra-low latency for TFTP protocol handshakes and initial boot
   └── /var/www/html/kickstarts/ (Lightweight ks.cfg and preseed automation scripts)

   TIER 2: BULK CAPACITY HDD (bulk18 - Seagate IronWolf Pro 18TB)
   ├── ZFS Dataset: bulk18/pxe-data (Mounted at /mnt/bindmounts/pxe-data)
   ├── Bind-mounted into CT 513 at: /var/www/html/os
   │     ├── /var/www/html/os/rocky9/      (Full installation RPM trees)
   │     ├── /var/www/html/os/ubuntu24/    (Full cloud-init/subiquity squashfs)
   │     ├── /var/www/html/os/proxmox/     (PVE ISO installations)
   │     └── /var/www/html/os/isos/        (Raw ISO storage archive)
   └── ZFS Features: zstd compression enabled (saves 20-30% disk space) + 1M recordsize

   TIER 3: RAM ACCELERATION (Dapitan 40 GiB RAM + ZFS ARC)
   └── Nginx zero-copy sendfile: Repeated PXE installs stream directly from RAM cache at line rate!
+---------------------------------------------------------------------------------------------------+
`

---

## 🏗️ Dapitan System Inventory & Allocation

| Component | Specification | Storage Pool | Role & Optimization |
| :--- | :--- | :--- | :--- |
| **LXC Container** | **CT 513** (pxe-dapitan) | m-fast:8 (SSD) | Small 8GB rootfs; fast system boots and package updates |
| **Bootloader / TFTP** | /var/lib/tftpboot | m-fast (SSD) | Instant TFTP response time for shimx64.efi & grubx64.efi |
| **Mass OS Trees / ISOs** | /var/www/html/os | ulk18/pxe-data (HDD) | Mass storage bind mount with ZFS zstd compression |
| **Static IP & VLAN** | VLAN 110 (Services)/24 (Tag 110) | VLAN 110 Services | Gateway: VLAN 110 (Services) |
| **Private DNS** | pxe.homelab-admin.me | Pi-hole Local DNS | Restricted strictly to local LAN subnets |

---

## 🛠️ Step 1: Create Host ZFS Dataset on Dapitan (ulk18)

Execute directly on **Dapitan Proxmox Host** (VLAN 1 [Management]):

`ash
# 1. Create optimized ZFS dataset on bulk18 for ISOs and OS repositories
zfs create -o recordsize=1M -o compression=zstd bulk18/pxe-data

# 2. Create host bind mount staging directory
mkdir -p /mnt/bindmounts/pxe-data
mkdir -p /mnt/bindmounts/pxe-data/{rocky9,ubuntu24,pve,isos}

# 3. Ensure permissions
chmod -R 755 /mnt/bindmounts/pxe-data
`

---

## 🛠️ Step 2: Provision Lightweight LXC Container (CT 513)

Execute on **Dapitan Proxmox Host**:

`ash
# Provision minimal 8GB container on vm-fast SSD
pct create 513 local:vztmpl/almalinux-9-default_*.tar.xz \
  --hostname pxe-dapitan \
  --cores 2 \
  --memory 2048 \
  --swap 1024 \
  --features nesting=1 \
  --net0 name=eth0,bridge=vmbr0,tag=110,ip=VLAN 110 (Services)/24,gw=VLAN 110 (Services) \
  --nameserver VLAN 110 (Services) \
  --storage vm-fast \
  --rootfs vm-fast:8 \
  --unprivileged 0 \
  --onboot 1

# Bind mount bulk18 mass storage dataset into Nginx OS webroot
pct set 513 -mp0 /mnt/bindmounts/pxe-data,mp=/var/www/html/os

# Start container
pct start 513
`

---

## 🌐 Step 3: Configure Local DNS in Pi-hole

In your Pi-hole Web Admin (**Local DNS** → **DNS Records**):
- **Domain:** pxe.homelab-admin.me
- **IP Address:** VLAN 110 (Services)

---

## 📦 Step 4: Install & Configure High-Speed TFTP & EFI Bootloaders

Attach to CT 513:
`ash
pct enter 513
`

Inside CT 513:
`ash
# 1. Install packages
dnf install -y tftp-server syslinux-tftpboot grub2-efi-x64 shim-x64 nginx wget

# 2. Build TFTP layout (kept on SSD for lightning-fast TFTP transfers)
mkdir -p /var/lib/tftpboot/grub
mkdir -p /var/lib/tftpboot/images/{rocky9,ubuntu24,pve}
mkdir -p /var/www/html/kickstarts

# 3. Copy official signed UEFI Shim and GRUB2 binaries
cp /boot/efi/EFI/almalinux/shimx64.efi /var/lib/tftpboot/shimx64.efi
cp /boot/efi/EFI/almalinux/grubx64.efi /var/lib/tftpboot/grubx64.efi

# 4. Tune TFTP for large block transfers (1468 bytes blocksize)
sed -i 's|ExecStart=/usr/sbin/in.tftpd -s /var/lib/tftpboot|ExecStart=/usr/sbin/in.tftpd -B 1468 -s /var/lib/tftpboot|' /usr/lib/systemd/system/tftp.service

# 5. Start TFTP service
systemctl daemon-reload
systemctl enable --now tftp.socket
systemctl enable --now tftp.service
`

---

## 🌐 Step 5: Configure Nginx with Zero-Copy Kernel Acceleration

Create /etc/nginx/conf.d/pxe.conf inside CT 513:

`
ginx
server {
    listen 80;
    server_name pxe.homelab-admin.me VLAN 110 (Services) pxe.local;
    root /var/www/html;

    # 🔒 Local LAN only security
    allow 192.168.0.0/16;
    allow 10.0.0.0/8;
    allow 172.16.0.0/12;
    allow 127.0.0.1;
    deny all;

    # 🚀 Kernel zero-copy streaming & TCP buffering optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    sendfile_max_chunk 1m;

    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }

    # Cache headers for heavy OS files
    location ~* \.(iso|img|rpm|deb|squashfs|tar|xz|gz)$ {
        expires 30d;
        add_header Cache-Control public, no-transform;
    }
}
`
Start Nginx:
`ash
systemctl enable --now nginx
`

---

## 💽 Step 6: Populate OS Tree on Bulk Storage & Copy Boot Kernels to SSD

Inside CT 513:
`ash
# Download ISO directly to bulk18 storage
cd /var/www/html/os/isos
wget -O rocky9.iso https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.4-x86_64-minimal.iso

# Mount ISO temporarily
mkdir -p /mnt/iso
mount -o loop,ro /var/www/html/os/isos/rocky9.iso /mnt/iso

# 1. Copy full OS tree to bulk18 mass storage (/var/www/html/os/rocky9/)
cp -r /mnt/iso/* /var/www/html/os/rocky9/
cp -r /mnt/iso/.treeinfo /var/www/html/os/rocky9/ 2>/dev/null || true

# 2. Copy lightweight kernel & initrd to SSD TFTP storage (/var/lib/tftpboot/)
cp /mnt/iso/images/pxeboot/vmlinuz /var/lib/tftpboot/images/rocky9/vmlinuz
cp /mnt/iso/images/pxeboot/initrd.img /var/lib/tftpboot/images/rocky9/initrd.img

umount /mnt/iso
chmod -R 755 /var/lib/tftpboot
chmod -R 755 /var/www/html
`

---

## 📜 Step 7: GRUB2 & Kickstart Automation Files

#### 1. GRUB Config (/var/lib/tftpboot/grub.cfg on SSD):
`ini
set default=0
set timeout=30

insmod efi_gop
insmod efi_uga
insmod net
insmod efinet
insmod tftp
insmod gzio
insmod part_gpt
insmod ext2

menuentry '1. Automated Install - Rocky Linux 9 (Kickstart)' --class fedora --class gnu-linux --class os {
    linuxefi images/rocky9/vmlinuz ip=dhcp inst.ks=http://pxe.homelab-admin.me/kickstarts/rocky9-ks.cfg inst.stage2=http://pxe.homelab-admin.me/os/rocky9 quiet
    initrdefi images/rocky9/initrd.img
}

menuentry '2. Interactive Install - Rocky Linux 9' --class fedora --class gnu-linux --class os {
    linuxefi images/rocky9/vmlinuz ip=dhcp inst.stage2=http://pxe.homelab-admin.me/os/rocky9 quiet
    initrdefi images/rocky9/initrd.img
}

menuentry '3. Boot from Local Hard Drive' {
    exit
}
`

#### 2. Kickstart Config (/var/www/html/kickstarts/rocky9-ks.cfg on SSD):
`	ext
#version=RHEL9
text
skipx
url --url=http://pxe.homelab-admin.me/os/rocky9
lang en_US.UTF-8
keyboard us
timezone America/Los_Angeles --utc
network --bootproto=dhcp --device=link --activate --onboot=on

# Replace with your password hash (openssl passwd -6 'YourPassword')
rootpw --iscrypted =656000
user --name=perlas --groups=wheel --iscrypted --password==656000

firewall --enabled --service=ssh
selinux --enforcing
zerombr
clearpart --all --initlabel
ignoredisk --only-use=sda,vda,nvme0n1

part /boot/efi --fstype=efi --size=600 --fsoptions=umask=0077,shortname=winnt
part /boot --fstype=xfs --size=1024
part pv.01 --fstype=lvmpv --grow --size=1

volgroup vg_system pv.01
logvol / --vgname=vg_system --fstype=xfs --size=10240 --name=lv_root
logvol /var --vgname=vg_system --fstype=xfs --size=5120 --name=lv_var
logvol swap --vgname=vg_system --fstype=swap --size=2048 --name=lv_swap
reboot

%packages
@^minimal-environment
curl
wget
git
qemu-guest-agent
vim
tar
%end

%post --log=/root/ks-post.log
systemctl enable qemu-guest-agent
systemctl enable sshd
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleAdminKey admin@homelab >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
%end
`

---

## 📊 Summary of Efficiency Gains on Dapitan

| Metric | Traditional Single-Drive Setup | Dapitan Tiered Setup | Gain / Benefit |
| :--- | :--- | :--- | :--- |
| **SSD Usage (m-fast)** | ~40-60 GB per multiple OS | **< 8 GB Total** | Preserves valuable SSD space for high-I/O databases & VMs |
| **TFTP Boot Latency** | Slow if on mechanical HDD | **Instant (SSD)** | Bootloader and kernel load into client RAM in seconds |
| **Mass Storage (ulk18)** | N/A | **Virtually Unlimited** | Can store dozens of full distro trees (RHEL, Rocky, Ubuntu, Debian, Proxmox, Windows) |
| **ZFS Compression** | None | **zstd on ulk18** | Automatic 20-30% disk space reduction for package repositories |
| **RAM Cache (40GB)** | Default HTTP transfer | **ZFS ARC + Nginx sendfile** | Line-rate package delivery directly from RAM |
