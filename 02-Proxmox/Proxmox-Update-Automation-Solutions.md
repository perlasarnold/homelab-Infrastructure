# Proxmox VE Update and Patching Automation Solutions

**Date:** May 16, 2026  
**Objective:** Evaluate, document, and compare the top industry-standard and community-proven methodologies for automating system patching and package updates on Proxmox VE (PVE) hosts and their guest workloads (LXCs/VMs).  
**Status:** Implemented & Deployed in Homelab (`/ansible`)  
**Active Production Setup:** Sequential Node & Workload Playbook (`serial: 1`) and 3rd Sunday 2:00 AM Pacific Schedule (`schedule_proxmox_updates.yml`).

---

## Executive Summary
Automating updates on a hypervisor host differs fundamentally from standard server patching because the host coordinates shared storage, software-defined networking, and virtualized workloads. A service disruption on the host can cause cascading downtime across all guest virtual machines and containers. 

This guide evaluates the three top methodologies for Proxmox VE update automation:
1. **Ansible Orchestration (The Gold Standard)** — Safest, highly configurable, cluster-aware, and handles rolling node reboots with live migrations.
2. **Debian `unattended-upgrades` (The Native Restricted OS Route)** — Lightweight, but requires extensive blacklisting of Proxmox packages and disabling of automatic reboots to prevent catastrophic cluster desynchronization.
3. **PVE LXC Updaters & Guest Automation (Workload Patching)** — Utilizing community-maintained tools or agents specifically for the virtualized guest systems rather than the hypervisor host itself.

---

## 1. Ansible Orchestration (The Industry Standard)

Ansible is the most secure and robust way to automate Proxmox updates, especially in multi-node clusters like **Bulakan** and **Cebu**. Because Ansible is agentless and connects via SSH, it does not add overhead to the hypervisor host.

### Key Strategies for Safe Execution
* **Serial Execution (`serial: 1`):** Crucial for cluster stability. By updating and rebooting only one host at a time, your virtualized services remain highly available.
* **Workload Evacuation (Live Migration):** In a cluster with shared storage, virtual machines and containers can be live-migrated to online nodes before the host begins updating, ensuring **zero downtime** for critical services.
* **Post-Update Health Check:** The automation playbook must query host status and cluster health (such as Ceph OSD state or corosync sync) before allowing the next host to update.

### Recommended Community Roles
* **`adfinis.proxmox_upgrade` (Ansible Galaxy):** Specifically engineered for safe, automated rolling updates of Proxmox VE clusters. It automates VM/CT migration, node updates, reboot verification, and post-reboot validation.
* **`lae.proxmox`:** A highly respected role for general Proxmox deployment and host maintenance.

### Example Production-Grade Update Playbook
Below is an example of a cluster-aware rolling update playbook. It handles update checks, packages upgrades, checks if a reboot is needed, executes the reboot sequentially, and waits for services to recover.

```yaml
---
- name: Proxmox VE Sequential Rolling Update Playbook
  hosts: proxmox_nodes
  become: true
  serial: 1  # Crucial: processes only one node at a time to prevent multi-node downtime
  any_errors_fatal: true # Fails immediately if any task on a node encounters an error
  
  tasks:
    - name: Ensure APT cache is updated
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Run safe dist-upgrade
      apt:
        upgrade: dist
        autoclean: yes
        autoremove: yes

    - name: Check if a reboot is required
      stat:
        path: /var/run/reboot-required
      register: reboot_required_file

    - name: Evacuate VMs/Containers (For Clustered Environments with Shared Storage)
      block:
        - name: Get running guests on host
          shell: "qm list | awk 'NR>1 {print $1}' && pct list | awk 'NR>1 {print $1}'"
          register: running_guests
          changed_when: false

        - name: Log evacuation status
          debug:
            msg: "Found running guests: {{ running_guests.stdout_lines }}. Evacuating node..."
          when: running_guests.stdout_lines | length > 0

        # Note: In non-shared storage environments, you should shut down guests safely instead.
        # Below is a shell block example to bulk-migrate or bulk-suspend guests:
        # For true HA clusters: pvesh create /nodes/{{ inventory_hostname }}/migrateall --target {{ ha_target_node }}
      when: reboot_required_file.stat.exists

    - name: Reboot the host
      reboot:
        msg: "Rebooting Proxmox host {{ inventory_hostname }} due to kernel/package updates"
        connect_timeout: 5
        reboot_timeout: 600
        pre_reboot_delay: 5
        post_reboot_delay: 30
        test_command: whoami
      when: reboot_required_file.stat.exists

    - name: Verify Proxmox Node and Cluster Health
      shell: pvecm status
      register: cluster_status
      changed_when: false
      retries: 5
      delay: 15
      until: "'Quorate: Yes' in cluster_status.stdout"
      when: reboot_required_file.stat.exists
```

---

## 2. Debian `unattended-upgrades` (The Native OS Route - Restricted)

While `unattended-upgrades` is a native Debian utility, using it on Proxmox VE hosts is **highly controversial**. Applying updates that silently alter the hypervisor's hyper-critical subsystems (like storage mounts, networking templates, or the QEMU/LXC virtualization wrappers) without an administrator present is high-risk. 

However, if unattended updates are required, they **must** be strictly restricted.

### The "Safe" Unattended Upgrades Ruleset
1. **Limit to Security Repositories Only:** Only allow Debian and Proxmox security repositories. Major upgrades must remain manual.
2. **Strictly Blacklist Core Proxmox Packages:** Exclude the core virtualization packages. This ensures that updates to the kernel, container wrappers, or management interface never install automatically.
3. **Never Allow Automatic Reboots:** Disable unattended reboot triggers. Instead, configure email notifications to alert you that a reboot is pending.

### Configuration Guide
To enforce this, edit your `/etc/apt/apt.conf.d/50unattended-upgrades` file to include the following configuration:

```apt
// /etc/apt/apt.conf.d/50unattended-upgrades

Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    // Avoid allowing the main pve repositories automatically!
};

// Prevent Proxmox components from updating automatically to avoid unexpected breakdowns
Unattended-Upgrade::Package-Blacklist {
    "proxmox-ve";
    "pve-kernel-.*";
    "pve-manager";
    "qemu-server";
    "pve-qemu-kvm";
    "pve-container";
    "corosync";
    "ceph-.*";
};

// Never reboot automatically
Unattended-Upgrade::Automatic-Reboot "false";

// Send email notifications to the admin when upgrades happen or fail
Unattended-Upgrade::Mail "admin@yourdomain.com";
Unattended-Upgrade::MailOnlyOnError "false";
```

*Validate your configuration at any time by running:*
```bash
unattended-upgrades --dry-run
```

---

## 3. LXC Guest Updaters & Community Helper-Scripts

A critical distinction must be made between **updating the Proxmox Host** and **updating the virtualized guest workloads**. 

### The Proxmox Helper-Scripts Ecosystem
In the Proxmox homelab community, the **Proxmox VE Helper-Scripts** (formerly known as tteck scripts, now maintained by a community organization at `community-scripts.github.io`) are incredibly popular. 

* **Warning:** **Never** use community or custom shell scripts to automatically update the core Proxmox VE Host. The host must be updated using official Debian tools (`apt update && apt dist-upgrade`) or official GUI panels.
* **The Solution for LXCs:** The community offers a dedicated tool called the **PVE LXC Updater** script. This runs on the host shell and loops through selected LXC containers, updating their guest OS packages sequentially.
* **How to run the LXC Updater:**
  ```bash
  bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/misc/update-lxcs.sh)"
  ```
  This script allows you to choose which containers to update, handles package cleanups, and restarts containers if needed, taking the manual labor out of keeping 10+ LXCs patched.

---

## Automated Patching Solution Comparison Matrix

| Feature / Metric | Ansible Playbook (Galaxy / Custom) | Restricted `unattended-upgrades` | Community `PVE LXC Updater` |
| :--- | :--- | :--- | :--- |
| **Primary Target** | Proxmox Hosts & Guest OS | Proxmox Host (Debian core) | LXC Containers (Guest OS) |
| **Risk Profile** | **Low** (Highly controlled, sequential) | **High** (Unattended host updates) | **Low** (Isolated to guest workloads) |
| **Setup Complexity**| Moderate (Requires SSH keys & Ansible) | Low (Single APT package & config) | Very Low (On-demand interactive script) |
| **Reboot Handling** | Graceful (Migration + sequentially) | Dangerous (May skip or force reboots) | Restart-aware per container |
| **Cluster Aware** | **Yes** (Verifies node/Ceph health) | **No** (Individual node is blind) | **No** (Workload level) |
| **Recommended For** | Production networks, active clusters | Single-node labs (security packages only)| Rapid patching of guest Linux services |

---

## Strategic Recommendations for Your Homelab

Based on your active cluster layout (**Bulakan** and **Cebu** nodes):

1. **Host Updates (Bulakan & Cebu):**
   * **Do not use unattended upgrades on the hosts.** A hypervisor cluster split, network desynchronization, or unplanned reboot of Bulakan could break active services like Jellyfin or Plex syncing.
   * **Adopt Ansible:** Use a simple Ansible script (like the one shown above) configured in your local environment. Run this manually or via a CI/CD job triggered on a schedule, but ensure you trigger it in a controlled maintenance window. 
   * **Ensure Shared Storage is Healthy:** If you have shared storage or local sync operations (like your TrueNAS scheduled tasks), pause them or ensure they have completed before executing host upgrades.

2. **LXC Container Updates:**
   * Integrate the community **PVE LXC Updater** script as a cron job or shell helper. Since containers are lightweight and isolated, automating their package updates is much lower risk.
   * Use an Ansible playbook targeting your container IPs directly to update packages within your services layer (e.g., standardizing package dependencies across your media stack).

---

## References & Official Resources
* **Official Proxmox Upgrade Guides:** [Proxmox VE Wiki - System Software Updates](https://pve.proxmox.com/wiki/System_Software_Updates)
* **Community-Scripts:** [Proxmox VE Community Helper-Scripts](https://community-scripts.github.io/ProxmoxVE/)
* **Ansible Galaxy Collections:** [Ansible `community.general.proxmox` Collection](https://galaxy.ansible.com/ui/repo/published/community/general/)
