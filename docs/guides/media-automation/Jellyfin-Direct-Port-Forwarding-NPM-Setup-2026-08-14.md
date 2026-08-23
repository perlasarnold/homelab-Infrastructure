# 🎬 LAN-Only Reverse Proxy Guide: Jellyfin Dapitan (`jellyfindp.homelab-admin.me`) via NPM

> **Date:** 2026-08-14  
> **Objective:** Setup & operational documentation for `jellyfindp.homelab-admin.me` (Dapitan Jellyfin CT 510).  
> **Target Service:** Dapitan Jellyfin CT 510 (`VLAN 110 (Services):8096` — **SERVICES VLAN 110**)  
> **Reverse Proxy:** Nginx Proxy Manager (`VLAN 120 (DMZ)` — **DMZ VLAN 120**)  
> **Local DNS:** Pi-hole (`VLAN 1 [Primary DNS]`)  
> **Status:** 🟢 Active (LAN-Only Reverse Proxy with Let's Encrypt Wildcard SSL)  

---

## 1. Why Switch from Cloudflare Tunnel to Direct Port Forwarding?

- **Cloudflare TOS Compliance**: Section 2.8 of Cloudflare's Terms of Service prohibits serving video streaming media (Plex/Jellyfin) over proxied CDN or Tunnel connections without an Enterprise plan.
- **Direct Bandwidth**: Bypasses Cloudflare edge bottlenecks, enabling full ISP upload speeds for 4K / high-bitrate video streams.
- **SSL Protection**: NPM applies your valid Let's Encrypt Wildcard certificate (`*.homelab-admin.me`), securing the connection with end-to-end TLS encryption over public port `443`.

---

## 2. Step 1: Cloudflare DNS A Record (DNS-Only / Grey Cloud)

To route traffic directly to your UniFi router instead of Cloudflare's proxy edge:

1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com/) $\rightarrow$ Select `homelab-admin.me` $\rightarrow$ **DNS** $\rightarrow$ **Records**.
2. If `jellyfindp` currently exists as a CNAME or Proxied record, edit or delete it.
3. Click **Add Record**:
   - **Type**: `A`
   - **Name**: `jellyfindp`
   - **IPv4 address**: Your Public WAN IP address (e.g. `YOUR_WAN_IP`).
   - **Proxy status**: **DNS Only** (Grey Cloud — ⚠️ *Critical: Must be DNS Only to prevent Cloudflare video streaming block*).
   - **TTL**: `Auto`
4. Click **Save**.

> [!TIP]
> **Dynamic IP (DDNS)**: If your ISP changes your public WAN IP, configure UniFi Gateway DDNS (`Settings` $\rightarrow$ `Internet` $\rightarrow$ `WAN` $\rightarrow$ `Dynamic DNS`) pointing to Cloudflare DNS.

---

## 3. Step 2: UniFi Gateway Port Forwarding Rules

Configure your UniFi Router (`VLAN 1 [Gateway]` / UniFi Network Application) to forward incoming WAN traffic on ports 80/443 directly to your Nginx Proxy Manager LXC (`VLAN 1 [Management]`).

1. Open **UniFi Network** $\rightarrow$ **Settings** $\rightarrow$ **Security** $\rightarrow$ **Port Forwarding**.
2. Click **Create New Rule**:

### Rule 1: HTTPS (Port 443)
- **Name**: `NPM HTTPS`
- **Enable**: Checked
- **Interface**: `WAN`
- **From**: `Any`
- **Port**: `443`
- **Forward IP**: `VLAN 1 [Management]` (Nginx Proxy Manager LXC)
- **Forward Port**: `443`
- **Protocol**: `TCP`

### Rule 2: HTTP (Port 80 - for 301 Redirection & Let's Encrypt HTTP-01)
- **Name**: `NPM HTTP`
- **Enable**: Checked
- **Interface**: `WAN`
- **From**: `Any`
- **Port**: `80`
- **Forward IP**: `VLAN 1 [Management]`
- **Forward Port**: `80`
- **Protocol**: `TCP`

3. Click **Apply Changes**.

---

## 4. Step 3: Configure Proxy Host in Nginx Proxy Manager

Now, configure NPM (`http://VLAN 120 (DMZ):81`) to proxy `jellyfindp.homelab-admin.me` directly to Dapitan Jellyfin CT 510 (`VLAN 110 (Services):8096`).

1. Log into NPM (`http://VLAN 120 (DMZ):81`).
2. Go to **Hosts** $\rightarrow$ **Proxy Hosts** $\rightarrow$ Click **Add Proxy Host**.
3. **Details Tab**:
   - **Domain Names**: `jellyfindp.homelab-admin.me`
   - **Scheme**: `http`
   - **Forward Hostname / IP**: `VLAN 110 (Services)` (Dapitan Jellyfin CT 510 — **SERVICES VLAN 110**)
   - **Forward Port**: `8096`
   - **Websockets Support**: **Toggle ON** (Required for Jellyfin client state & SyncPlay)
4. **SSL Tab**:
   - **SSL Certificate**: Select `*.homelab-admin.me` (Let's Encrypt Wildcard)
   - **Force SSL**: **Toggle ON**
   - **HTTP/2 Support**: **Toggle ON**
   - **HSTS Enabled**: **Toggle ON**
5. **Advanced Tab** (Media Streaming Optimization):
   Add the following directives to disable proxy buffering and increase timeout limits for smooth video playback:

```nginx
# Jellyfin Streaming Optimizations
client_max_body_size 0;
proxy_buffering off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
send_timeout 3600s;
```

6. Click **Save**.

---

## 5. Verification & Testing

1. **DNS Resolution Check (Terminal)**:
   ```bash
   dig +short jellyfindp.homelab-admin.me
   # Output should return your Public WAN IP (not a 104.x.x.x Cloudflare IP)
   ```

2. **HTTP $\rightarrow$ HTTPS Redirection**:
   ```bash
   curl -I http://jellyfindp.homelab-admin.me
   # Expected Output: HTTP/1.1 301 Moved Permanently
   # Location: https://jellyfindp.homelab-admin.me/
   ```

3. **External Media Playback Test**:
   - Access `https://jellyfindp.homelab-admin.me` from a mobile network (5G) or outside network.
   - Play a video stream and inspect the browser console / media metrics to confirm high-bitrate streaming without proxy buffering drops.

---

## 6. References

- [Nginx Proxy Manager Service Doc](file:////opt/homelab-infrastructure/05-Services/Nginx%20Proxy%20Manager.md)
- [NPM Let's Encrypt SSL Guide](file:////opt/homelab-infrastructure/06-Guides/Nginx-Proxy-Manager-LetsEncrypt-SSL-Guide-2026-08-14.md)
- [Guides Index](file:////opt/homelab-infrastructure/06-Guides/Guides%20Index.md)
