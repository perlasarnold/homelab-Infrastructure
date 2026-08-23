# 🛠️ Troubleshooting: Cebu Pi-hole (VLAN 1 [Secondary DNS]) Unreachable

**Date:** 2026-05-21
**Objective:** Resolve issue where `http://VLAN 1 [Secondary DNS]/admin` (Cebu Pi-hole) was not loading and the IP was completely unreachable from the network.

## Problem Statement
The user reported that the secondary Pi-hole web interface on the Cebu node (`VLAN 1 [Secondary DNS]`) was not loading. Pings to the IP address from the user's machine were failing with "Destination Host Unreachable".

## Investigation Steps
1. **Host Verification:** Pinged the Proxmox host `VLAN 1 [Management]` (Cebu) which responded successfully, confirming the physical node was online.
2. **Container Status:** Connected to the Cebu node via SSH and ran `pct status 401`. The container was running.
3. **Network Config Check:** Ran `pct config 401`. Discovered two issues:
   - The container was attached to `vnet1` (an isolated Proxmox SDN bridge) instead of `vmbr0` (the physical LAN bridge).
   - The `ostype` was set to `unmanaged`, meaning Proxmox does not automatically manage the OS network configuration.
4. **Internal Network Check:** Ran `ip a` inside the container. The `eth0` interface was in a `DOWN` state and had no IP address assigned.

## Root Cause
The `pihole_cebu` Terraform module deployed the container as an `unmanaged` OS on the `vnet1` bridge. Because it was unmanaged, Proxmox did not auto-generate the `/etc/network/interfaces` file. Without this file, Debian did not bring up the `eth0` interface or assign the static IP (`VLAN 1 [Secondary DNS]`).

Additionally, even if it had an IP, it would have been trapped on the isolated `vnet1` network rather than the main `vmbr0` LAN. Finally, Pi-hole was never installed on the container after it was provisioned.

## Resolution Applied
1. **Bridge Fix:** Changed the container's network interface to use `vmbr0`:
   ```bash
   pct set 401 -net0 name=eth0,bridge=vmbr0,gw=VLAN 1 [Gateway],ip=VLAN 1 [Secondary DNS]/24
   ```
2. **Interface Configuration:** Manually created the `/etc/network/interfaces` file inside the container to define the static IP:
   ```text
   auto lo
   iface lo inet loopback

   auto eth0
   iface eth0 inet static
       address VLAN 1 [Secondary DNS]/24
       gateway VLAN 1 [Gateway]
   ```
3. **Service Restart:** Rebooted the container. `eth0` successfully came online with `VLAN 1 [Secondary DNS]`.

## Next Steps & Preventive Measures
- The Pi-hole software has now been successfully installed via the automated setup script. The web interface is accessible at `http://VLAN 1 [Secondary DNS]/admin` with the password `marziel24`.
- **Preventive Measure:** For future Terraform LXC deployments, ensure `bridge = "vmbr0"` is explicitly set if `vnet1` is not intended, and either use a managed `ostype` (like `debian`) or use an Ansible playbook/cloud-init to provision the network interfaces and install the required software post-creation.
