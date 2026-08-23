# 📖 Guides Index

Step-by-step guides for common homelab tasks. Written for beginners.

---

## Getting Started

- [[How to Access Proxmox]] — Logging into the Proxmox web interface
- [[How to Access Unraid]] — Logging into the Unraid web interface

## Proxmox Guides

- [[How to Create a VM]] — Spinning up a new virtual machine
- [[How to Create an LXC Container]] — Lightweight container creation
- [[How to Take a Snapshot]] — Backing up a VM state
- [[Immich-High-Availability-Guide]] — Establishing redundant auto-failover and SSD offloading for Immich
- [[Dapitan-Immich-Performance-Optimization-Guide-2026-08-21]] — Optimizing Immich load speed, PostgreSQL parameters, GPU acceleration, and Valkey queues on Dapitan CT 504
- [[Cebu-Immich-LXC-Setup-Guide]] — High-performance Debian 13 LXC Immich deployment with Intel iGPU Passthrough on Cebu
- [[Cebu-Immich-Startup-Troubleshooting]] — Resolving container boot failure and web service crash loop on Cebu
- [[Plex-Cluster-Hardware-Acceleration-and-RAM-Transcoding-Guide-2026-08-21]] — Standardizing Intel QuickSync GPU transcoding and RAM-disk transcoding across Bulakan, Cebu, and Dapitan with 1-click automation
- [[Dapitan-Plex-Setup-Recovery-2026-07-24]] — Restoring inaccessible Dapitan Plex Media Server CT 509 with static IP VLAN 1 (Mgmt) and 18TB ZFS media library mount
- [[Dapitan-Jellyfin-Replication-Guide-2026-07-24]] — Replicating Cebu Jellyfin to Dapitan CT 510 with IP VLAN 1 (Mgmt) and 18TB ZFS media library mount
- [[Linux-Mint-Remote-Desktop-Dapitan-Setup-Guide-2026-08-01]] — Provisioning Linux Mint 22 VM on Dapitan SSD with 128GB disk, VLAN 20 placement, Guacamole HTML5 RDP, and Authentik MFA
- [[Linux-Mint-Remote-Desktop-Dapitan-Setup-Guide-2026-08-01]] — Provisioning Linux Mint 22 VM on Dapitan SSD with 128GB disk, VLAN 20 placement, Guacamole HTML5 RDP, and Authentik MFA
- [[Home-Assistant-on-Proxmox-Setup]] — Installing Home Assistant OS (HAOS) VM via Proxmox VE Helper Script
- [[Proxmox-Windows-VM-Performance-Optimization]] — Optimizing Windows guest performance and fixing high CPU load on host
- [[Transmission-VPN-Proxmox-Setup]] — Deploying Transmission with Surfshark VPN (Gluetun) and Synology SMB storage
- [[Calibre-Web-Synology-Ebooks-Mount-Bulakan]] — Mounting the Synology Ebooks library into Calibre-Web LXC 113
- [[Cebu-Surfshark-Region-Change]] — Guide for changing Surfshark VPN regions on Cebu
- [[Cebu-Arr-Stack-Setup]] — Deploying an Arr Stack (Sonarr, Radarr, etc.) in a Debian LXC via Docker Compose
- [[Master-Arr-Stack-Sonarr-NPM-WireGuard-Setup-Guide-2026-08-22]] — Master setup guide for Sonarr, NPM wildcard SSL reverse proxy, Synology NAS media storage, and Surfshark WireGuard killswitch
- [[Arr-Stack-Surfshark-WireGuard-Storage-Guide-2026-08-22]] — Configuring Gluetun with dedicated Surfshark WireGuard credentials, Transmission killswitch, and NAS storage mappings
- [[Arr-Stack-Indexer-DownloadClient-Resolution-Guide-2026-08-22]] — Troubleshooting Sonarr health check errors and indexer sync post-SERVICES VLAN 110 migration
- [[Sonarr-NPM-Reverse-Proxy-Guide-2026-08-22]] — Step-by-step setup of Nginx Proxy Manager wildcard SSL termination and routing for Sonarr
- [[Bulakan-Homepage-Deployment-Guide-2026-08-13]] — Deploying Homepage dashboard in a Debian LXC container on Bulakan for cluster-wide monitoring
- [[Arr-Stack-GUI-Configuration-Guide]] — Guide for configuring the Web GUIs of the Arr stack (NPM routing, Jackett indexers, Remote Path Mapping)
- [[Cebu-Network-Driver-Hang-Troubleshooting]] — Resolving e1000e NIC hang and connectivity loss on Cebu

## Unraid Guides

- [[How to Add a Docker App]] — Installing an app via Community Applications
- [[How to Add a New Drive]] — Expanding the storage array
- [[How to Map a Network Share]] — Accessing Unraid shares from Windows/Mac

## Infrastructure as Code & Provisioning

- [[UEFI-PXE-Boot-Server-Setup-Guide-2026-08-21]] — Complete UEFI/BIOS PXE boot server setup with TFTP, GRUB2, HTTP media hosting, and automated Kickstart provisioning
- [[Terraform-Walkthrough-Netbootxyz]] — Complete beginner's guide to deploying LXC containers with Terraform
- [[Cloudflare-Tunnel-Setup]] — Guide for HA redundancy and Active-Active setup

## Network & Security

- [[Jellyfin-Active-Active-HA-Setup-Guide-2026-08-18]] — High Availability active-active setup for Jellyfin with state sync, health failover, and zero-downtime routing
- [[NPM-Firefox-Domain-Mismatch-Troubleshooting-2026-08-16]] — Resolving Firefox SSL handshake failures and aligning NPM domain aliases for Immich, Jellyfin, and Plex
- [[Dapitan-Plex-NPM-Proxy-Setup-2026-08-15]] — Reverse proxy & VLAN 110 migration setup for Dapitan Plex (`plexdp.homelab-admin.me`) via NPM
- [[Jellyfin-Direct-Port-Forwarding-NPM-Setup-2026-08-14]] — Direct Port Forwarding setup for Dapitan Jellyfin (`jellyfindp.homelab-admin.me`) via UniFi and NPM
- [[Nginx-Proxy-Manager-LetsEncrypt-SSL-Guide-2026-08-14]] — Let's Encrypt SSL configuration, TLS hardening, auto-renewal, and canonical redirects in Nginx Proxy Manager
- [[VLAN-Segmentation-Roadmap]] — Step-by-step path to secure inter-VLAN segmentation and firewall rules
- [[Cebu-VLAN-Migration-Guide-2026-07-30]] — 802.1Q VLAN tagging, subnet segmentation, and UniFi firewall rules setup for Cebu Proxmox node
- [[Network-Saturation-Troubleshooting-2026-05-24]] — Diagnosing local network saturation from SMB transfers and disk I/O wait

## Media & Metadata Standardization

- [[Human-Movies-Metadata-Standardization]] — Clean and match movies on PNAS/TrueNAS shares
- [[TV-Shows-Metadata-Standardization]] — Automate TV series migration and Plex standardizing
- [[TrueNAS-Photo-Renaming-Automation]] — Automate photo library EXIF renaming and sorting

## Maintenance

- [[How to Update Proxmox]] — Safely updating PVE
- [[How to Update Unraid]] — Updating Unraid OS
- [[Bulakan-Proxmox-VE8-to-VE9-Upgrade]] — In-place upgrade of the Bulakan node from Proxmox VE 8.4 to VE 9 (Debian 13 Trixie)
- [[Cebu-PVE-9.2.5-Update-Staging-2026-07-23]] — Completed Cebu's update to PVE 9.2.5 with protected backups, controlled reboot, and service validation
- [[Dapitan-Homelab-Net-Cluster-Join-2026-07-23]] — Joined Dapitan to the three-node Homelab-Net cluster and restored its node-local storage
- [[Dapitan-PNAS-Movies-Copy-2026-07-23]] — Dry-run-first script for copying PNAS movies into Dapitan's bulk18 media library

## TrueNAS Guides

- [[TrueNAS-on-Proxmox-Setup]] — Deploying TrueNAS SCALE on Proxmox
- [[TrueNAS-SMB-Sync-Setup]] — Automating SMB share synchronization
- [[TrueNAS-Scheduled-Tasks-Guide]] — Creating and managing cron jobs
- [[Cebu-Jellyfin-Setup-Guide]] — Full migration and setup walkthrough
- [[TrueNAS-Boot-Pool-Alert-Troubleshooting]] — Troubleshooting boot pool errors and health alerts
- [[TrueNAS-System-Dataset-Deadlock-Recovery]] — Resolving system dataset space deadlocks and Samba startup failures
- [[TrueNAS-DAS2-System-Dataset-Space-Deadlock]] — Resolving DAS2 pool space deadlock and clearing Immich cache files
- [[TrueNAS-Storage-IO-Error-Pause-Troubleshooting]] — Troubleshooting VM unresponsiveness caused by host ZFS pool degradation and QEMU IO Error pause
- [[Cebu-TrueNAS-DAS-Safe-Shutdown-2026-07-22]] — Safely taking failed DAS pools and TrueNAS offline without redirecting backups to the Proxmox root disk
- [[TrueNAS-Mount-Recovery-Plex-Cebu]] — Recovering TrueNAS CIFS mounts on Cebu host and restoring Plex Media Server playback after storage outage
- [[Synology-Mount-Recovery-Plex-Bulakan]] — Recovering Synology CIFS mounts on Bulakan host and restoring Plex, Jellyfin, and Audiobookshelf playback after host reboot
- [[TrueNAS-Synology-Mount-Recovery-Cebu]] — Recovering TrueNAS and Synology CIFS mounts on Cebu host and restoring Plex and Jellyfin playback after host reboot

---

*Add new guide pages in `06-Guides/` and link them here.*
