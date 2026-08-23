# 🛠️ Arr Stack Indexer & Download Client Resolution Guide

- **Date:** August 22, 2026
- **Objective:** Resolve Sonarr health check failures ("No download client is available", "All indexers are unavailable due to failures", and RSS/Search indexer errors) resulting from legacy IP configurations post-SERVICES VLAN 110 migration.
- **Maintainer:** Perlas

---

## 🔍 Investigation & Root Cause

### Symptoms
When accessing `https://sonarr.homelab-admin.me/system/status`, the following health warnings and errors were reported:
1. `No download client is available`
2. `All rss-capable indexers are temporarily unavailable due to recent indexer errors`
3. `All indexers are unavailable due to failures`
4. `All search-capable indexers are temporarily unavailable due to recent indexer errors`

### Root Cause
1. **Legacy IP Mappings in Prowlarr & Sonarr:**
   - When the Arr Stack LXC container (CT 417) was migrated from VLAN 1 (`VLAN 1 (Management)`) to SERVICES VLAN 110 (`VLAN 110 (Services)`), Prowlarr application sync configurations and Sonarr Torznab indexer URLs still retained the old `http://VLAN 1 (Management):9696` and `http://VLAN 1 (Management):8989` endpoints.
   - Sonarr attempts to contact Prowlarr for RSS feeds and search queries failed with `System.Net.Sockets.SocketException (113): Host is unreachable (VLAN 1 (Management):9696)`, placing all indexers in a disabled backoff state.
2. **Missing Download Client:**
   - Sonarr had no configured download client entry pointing to the local Transmission daemon running behind Gluetun (`http://VLAN 110 (Services):9091`).

---

## 🛠️ Actions Taken

### 1. Prowlarr & Sonarr Network Endpoint Synchronization
- Updated Prowlarr database (`prowlarr.db`) application definitions for Sonarr (`id=1`) and Radarr (`id=2`), migrating `prowlarrUrl` and `baseUrl` to `http://VLAN 110 (Services):9696`, `http://VLAN 110 (Services):8989`, and `http://VLAN 110 (Services):7878`.
- Updated Sonarr database (`sonarr.db`) indexer base URLs to `http://VLAN 110 (Services):9696/1/`.
- Saved and tested application links in Prowlarr, triggering automatic sync for indexers (**LimeTorrents** and **The Pirate Bay**).

### 2. Transmission Download Client Configuration
- Configured and linked the active Transmission client via Sonarr API (`/api/v3/downloadclient`):
  - **Host:** `VLAN 110 (Services)`
  - **Port:** `9091`
  - **URL Base:** `/transmission/`
  - **Category:** `tv-sonarr`
  - **SSL:** Disabled

### 3. Testing & Validation
- Executed indexer verification via Sonarr API (`/api/v3/indexer/test`):
  - `LimeTorrents (Prowlarr)`: **PASSED**
  - `The Pirate Bay (Prowlarr)`: **PASSED**
- Verified Transmission connectivity and category mapping.

---

## 🧪 Outcome
- All 4 health errors and warnings were successfully cleared.
- Sonarr is actively communicating with Prowlarr over SERVICES VLAN 110 (`VLAN 110 (Services)`) and downloading via Transmission through Gluetun VPN.

---

## 📚 References
- [Sonarr Health Checks Documentation](https://wiki.servarr.com/sonarr/system#health-checks)
- [Prowlarr Documentation](https://wiki.servarr.com/prowlarr)
- [Arr Stack GUI Configuration Guide](file:////opt/homelab-infrastructure/06-Guides/Arr-Stack-GUI-Configuration-Guide.md)
