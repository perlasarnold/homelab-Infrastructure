# Guide: Home Assistant OS VM Setup on Cebu Proxmox (Helper Script Method)

* **Date:** May 18, 2026  
* **Objective:** Deploy Home Assistant OS (HAOS) as a high-performance, resilient Virtual Machine on the `cebu` Proxmox VE node (`192.168.1.26`) utilizing the community-maintained Proxmox VE Helper Script (`haos-vm.sh`) for rapid, standardized deployment.
* **Maintainer:** Perlas  

---

## 1. Active Infrastructure & VM Specifications

Following the community-maintained helper script execution, the active VM is configured on node `cebu` as follows:

* **Host Node:** `cebu` (192.168.1.26)
* **VM ID:** `111`
* **VM Name:** `haos-17.3`
* **Active IP Address:** `192.168.1.207` (Dynamically reported by QEMU Guest Agent)
* **Status:** Running (Active)
* **CPU:** `2 Cores` (Default allocation)
* **RAM:** `2 GiB` (2048 MiB) or `4 GiB` (4096 MiB)
* **Storage Target:** `cebu-zfs` (2TB Local ZFS pool)
* **Default Disk Size:** `32 GB` (Expandable in Hardware > Hard Disk > Resize)
* **Network Bridge:** `vmbr0` (Main local network bridge)
* **BIOS:** `OVMF (UEFI)` (Required by HAOS, auto-configured by script)
* **Machine Type:** `q35` (Modern architecture, auto-configured by script)

---

## 2. Step-by-Step Provisioning Workflow

The installation was performed using the community-maintained Proxmox VE Helper Scripts (the community-supported fork of the original tteck scripts).

### Command Executed
Inside the Proxmox Web GUI Shell on node `cebu`, the following command was run to initiate the automated builder:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/vm/haos-vm.sh)"
```

### Script Execution Logic & Rationale
1. **Interactive Prompt:** The builder asks whether to proceed using the **Default Settings** or **Advanced Settings**.
   * *Default Settings:* Installs HAOS with 2vCPU, 2GB RAM, 32GB disk size on `cebu-zfs`, automatically configures VM ID 111 (or next available ID), maps to bridge `vmbr0`, and enables QEMU Guest Agent.
   * *Advanced Settings (Optional):* Allows manually setting target CPU, memory, storage pool, and custom VM IDs.
2. **Automated Image Download:** The script queries GitHub for the latest stable release of Home Assistant OS (KVM `.qcow2.xz` image) and downloads it directly to the host's temporary storage.
3. **Automated VM Assembly:** The script executes Proxmox `qm` commands behind the scenes to:
   * Create VM shell `111` with UEFI/OVMF BIOS, Q35 machine type, and SCSI controllers.
   * Initialize a local EFI disk on `cebu-zfs`.
   * Extract and import the HAOS qcow2 virtual disk directly to the target `cebu-zfs` pool.
   * Set boot orders and enable the **QEMU Guest Agent**.
4. **Boot Execution:** Starts VM `111` automatically upon successful deployment.

---

## 3. Physical Hardware Passthrough (Zigbee / Z-Wave)

To connect smart home physical devices (like USB Zigbee coordinators or Z-Wave dongles), follow these instructions to pass the hardware through to VM `111`:

### GUI Discovery Method (Easiest)
1. Plug your USB coordinator (e.g. *Sonoff Zigbee Dongle Plus, Conbee II, Aeotec Z-Wave Gen5*) into a USB port on the physical `cebu` server.
2. Log in to the Proxmox Web GUI (`https://192.168.1.26:8006`).
3. Select VM **111 (haos-17.3)** in the sidebar.
4. Go to **Hardware** > **Add** > **USB Device**.
5. Select **Use USB Vendor/Device ID**.
6. Open the dropdown menu; Proxmox will display all physical USB devices currently active on the host.
7. Select your smart home coordinator (e.g., *Silicon Labs CP210x USB to UART Bridge*) and click **Add**.

### CLI Discovery Method (For Verification)
If you have multiple identical USB controllers or need to verify the exact device ID, run this in the Proxmox `cebu` host shell:

```bash
lsusb
```

Look for the Zigbee or Z-Wave device line in the output. For example:
```
Bus 001 Device 004: ID 10c4:ea60 Silicon Labs CP210x UART Bridge
```
* **Vendor ID:** `10c4`
* **Device ID:** `ea60`

You can manually map these in the **USB Vendor/Device ID** fields of Proxmox GUI VM Hardware options if the dropdown does not render.

> [!IMPORTANT]
> **Host CPU Exposure & Guest Agent:**
> Exposing CPU as `host` type and keeping `QEMU Guest Agent` checked (both automated by the helper script) ensures that Home Assistant can report its IP address directly to the Proxmox dashboard and shut down gracefully during host maintenance.

---

## 4. Post-Install Configurations & Networking

### Onboarding Access
1. Select VM **111** and open the **Console** tab.
2. Once booted, the terminal displays the local network IP and port:
   ```
   IPv4 addresses for enp6s18: 192.168.1.207/24
   Home Assistant URL:        http://homeassistant.local:8123
   Observer URL:              http://homeassistant.local:4357
   ```
3. Open a web browser on any computer connected to your local network and navigate to `http://192.168.1.207:8123` or `http://homeassistant.local:8123`.
4. Follow the setup wizard to create your primary owner account.

### Static IP Allocation
It is highly recommended to pin the IP address for Home Assistant to prevent integrations from losing contact:

* **Recommended (DHCP Reservation):** Log in to your router/firewall dashboard, find the DHCP lease list, match the MAC address of VM 111 (visible in Proxmox > VM 111 > Hardware > Network Device), and reserve `192.168.1.207` as the static assignment.
* **Inside Home Assistant (Fallback):** 
  1. Navigate to **Settings** > **System** > **Network**.
  2. Click **IPv4** to expand options.
  3. Change the radio toggle from *DHCP* to *Static*.
  4. Configure:
     * **IP Address:** `192.168.1.207`
     * **Netmask:** `255.255.255.0` (or `/24`)
     * **Gateway:** `192.168.1.1`
     * **DNS Servers:** `192.168.1.4` (Pi-hole on Cebu node) and `1.1.1.1` (Backup)

---

## Outcomes & Performance Goals
* **High Availability:** Auto-starts on Proxmox node boot; highly resilient to system crashes.
* **Storage Performance:** Placed on local SSD pool `cebu-zfs` with full TRIM capacity enabled.
* **Inter-VLAN Communication:** Placed on bridge `vmbr0` for main LAN accessibility.

---

## References & Additional Resources
1. **Community Proxmox VE Helper Scripts:** `https://community-scripts.org/scripts?q=home`  
2. **Official Home Assistant Installation Docs:** `https://www.home-assistant.io/installation/alternative`  
3. [[02-Proxmox/Proxmox Overview]] — Hardware profile of node Cebu (`192.168.1.26`).
4. [[05-Services/Services Index]] — Master list of URLs for internal services.
