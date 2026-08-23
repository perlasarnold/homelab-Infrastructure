# Connecting Isolated Proxmox VNETs (Local Cluster)

This guide documents the architecture and steps to connect an isolated Virtual Network (VNet) across the Cebu and Bulakan Proxmox servers. Because these servers reside on the same Local Area Network (LAN), we use a Proxmox SDN VXLAN overlay directly over the LAN IPs, removing the need for a VPN tunnel.

## Prerequisites

- Access to the Proxmox Web GUI.
- Ensure the backend SDN requirements are met (e.g., clicking Apply, ensuring `source /etc/network/interfaces.d/*` is in your interfaces file).
- Know the local LAN IP addresses of both Cebu and Bulakan.

---

## Phase 1: Configure Proxmox SDN (VXLAN Overlay)

We will create a VXLAN overlay that bridges the two nodes over your physical network at Layer 2. This creates a completely private, isolated virtual switch.

### 1. Create the VXLAN Zone
1. Navigate to **Datacenter** -> **SDN** -> **Zones**.
2. Click **Add** -> **VXLAN**.
3. Fill out the details:
   - **ID:** `local-inter-node`
   - **Peers:** Enter both of your local LAN IPs separated by a comma (e.g., `VLAN 1 [Management], 192.168.1.XX` where XX is Bulakan's IP).
4. Click **Create**.

*(Note: We leave MTU empty/default since there is no VPN overhead to worry about on a local LAN).*

### 2. Create the VNet
1. Navigate to **Datacenter** -> **SDN** -> **VNets**.
2. Click **Add**.
3. Fill out the details:
   - **Name:** `vnet-shared`
   - **Zone:** Select the `local-inter-node` zone you just created.
4. Click **Create**.

### 3. Apply Configuration
1. Navigate to **Datacenter** -> **SDN**.
2. Click **Apply** at the top. The State should change to `OK`.

---

## Phase 2: Attach VMs and Validate

Now that the private `vnet-shared` bridge exists, you can connect VMs to it.

1. Go to a Virtual Machine on the Cebu node.
2. Under **Hardware**, edit the **Network Device**.
3. Change the **Bridge** to `vnet-shared`.
4. Do the same for a Virtual Machine on the Bulakan node.
5. **Assign Static IPs:** Because this VNet is isolated from your main router, there is no DHCP server. You must assign static IP addresses inside the VM operating systems (e.g., `10.50.0.10/24` and `10.50.0.11/24`).

They will now be able to ping each other securely across the isolated VNet!
