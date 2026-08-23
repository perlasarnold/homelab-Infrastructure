# 🎛️ Arr Stack GUI Configuration Guide

- **Date:** May 21, 2026
- **Objective:** Configure the Web GUIs of a newly deployed Arr stack (Sonarr, Radarr, Prowlarr, Jackett) to integrate with Nginx Proxy Manager, automatically sync indexers through a Gluetun VPN via Prowlarr, and seamlessly offload downloads to a remote Windows torrent client using Remote Path Mappings.
- **Maintainer:** Perlas

---

## 🛠️ Step 1: DNS & Reverse Proxy Setup (Pi-hole & NPM)

To drop the port numbers (e.g., `:8989`) and access your applications cleanly (e.g., `http://sonarr.local`), traffic must be routed through Nginx Proxy Manager (NPM).

### 1. Pi-hole Configuration
Instead of pointing domains directly to your Arr stack container, point them to NPM.
1. Go to Pi-hole **Local DNS Records**.
2. Add the following records pointing to the NPM IP (e.g., `VLAN 1 (Mgmt)`):
   - `sonarr.local` -> `VLAN 1 (Mgmt)`
   - `radarr.local` -> `VLAN 1 (Mgmt)`
   - `bazarr.local` -> `VLAN 1 (Mgmt)`
   - `wizarr.local` -> `VLAN 1 (Mgmt)`
   - `prowlarr.local` -> `VLAN 1 (Mgmt)`
   - `jackett.local` -> `VLAN 1 (Mgmt)`

### 2. Nginx Proxy Manager Configuration
Route the incoming NPM traffic to the specific container ports.
1. Open NPM and click **Add Proxy Host**.
2. Create an entry for each service, pointing to the Arr LXC IP (`VLAN 1 (Mgmt)`):
   - `sonarr.local` -> `VLAN 1 (Mgmt):8989`
   - `radarr.local` -> `VLAN 1 (Mgmt):7878`
   - `bazarr.local` -> `VLAN 1 (Mgmt):6767`
   - `wizarr.local` -> `VLAN 1 (Mgmt):5690`
   - `prowlarr.local` -> `VLAN 1 (Mgmt):9696`
   - `jackett.local` -> `VLAN 1 (Mgmt):9117`
3. Toggle **Block Common Exploits** for security and save.

---

## 🔗 Step 2: Indexer Configuration (Prowlarr -> Arr)

Prowlarr completely replaces Jackett's manual Torznab copying by automatically pushing configured indexers directly to Sonarr and Radarr via their APIs. Because Prowlarr is attached to the `gluetun` network namespace, all tracker queries are automatically encrypted.

### A. Link Sonarr and Radarr to Prowlarr
1. Open **Sonarr**, navigate to **Settings > General**, and copy the **API Key**. Do the same for **Radarr**.
2. Open **Prowlarr** (`http://prowlarr.local`).
3. Navigate to **Settings > Apps** and click the big **+** button.
4. Add **Sonarr**:
   - **Sync Level:** Full Sync
   - **Prowlarr Server:** `http://prowlarr:9696` *(Internal Docker hostname)*
   - **Sonarr Server:** `http://sonarr:8989` *(Internal Docker hostname)*
   - **API Key:** Paste your Sonarr API Key.
   - Click **Test** and **Save**.
5. Repeat the exact same process for **Radarr**, substituting the Server to `http://radarr:7878` and using the Radarr API Key.

### B. Add Indexers to Prowlarr
1. In **Prowlarr**, go to **Indexers > + Add Indexer**.
2. Search for your preferred indexer (e.g., 1337x, TorrentGalaxy) and click it.
3. Click **Test** and **Save**.
4. Prowlarr will immediately and automatically inject the indexer directly into Sonarr and Radarr with the exact correct categories and settings! You no longer need to configure indexers in Sonarr/Radarr directly.

---

## 📥 Step 3: Remote Torrent Client Integration (Windows Box)

If your torrent client (e.g., qBittorrent) runs on a separate Windows machine, Sonarr/Radarr needs to send magnet links to its API.

1. **Enable Web UI:** Ensure your Windows Torrent Client has its Web UI enabled (e.g., port `8080`).
2. **Configure Sonarr/Radarr:**
   - Navigate to **Settings > Download Clients** and click **+ Add**.
   - Select your client (e.g., qBittorrent).
   - Enter the **IP Address** of the Windows machine, the Web UI Port, Username, and Password.
3. Click **Test** and **Save**. The Arr apps can now send torrents to your Windows box.

---

## 🗺️ Step 4: Remote Path Mapping

**The Problem:** The Windows box downloads to a mapped drive (e.g., `Z:\downloads`), but the Arr LXC container sees the TrueNAS storage as Linux directories (e.g., `/data/media/downloads`). Sonarr gets confused when Windows says "I saved the file at Z:\downloads\Show".

**The Solution:** Remote Path Mappings translate the Windows paths into Linux paths for the Arr stack.

1. Open Sonarr/Radarr and navigate to **Settings > Download Clients**.
2. Scroll to the bottom to find **Remote Path Mappings** and click **+ Add**.
3. Configure the mapping:
   - **Host:** Select the Windows Download Client you created in Step 3.
   - **Remote Path:** `Z:\downloads\` *(The exact path configured in the Windows Torrent Client)*.
   - **Local Path:** `/data/media/downloads/` *(The exact volume path mounted inside the Sonarr/Radarr Docker container)*.
4. Click **Save**. 

*(Rationale: When the Windows client finishes a download at `Z:\downloads\Movie`, Sonarr will intercept the completion event, automatically translate the path to `/data/media/downloads/Movie`, and flawlessly import/rename the file into your library.)*

---

## ✅ Outcome
The Web GUIs are now cleanly accessible via local DNS domains without port numbers. The Arr ecosystem is completely wired together: Prowlarr automatically manages and syncs your indexers across the stack, routing searches securely through Surfshark via Gluetun. Sonarr/Radarr sends grabbed magnet links to a remote Windows Torrent Client for processing, and seamlessly maps the remote directories to perform automated library imports.

---

## 📚 References
- [Nginx Proxy Manager Documentation](https://nginxproxymanager.com/)
- [Trash Guides - Remote Path Mapping](https://trash-guides.info/Radarr/Radarr-remote-path-mapping/)
- [Jackett Torznab Documentation](https://github.com/Jackett/Jackett#configuring-sonarr)
