# 🌐 Nginx Proxy Manager (NPM) Let's Encrypt & SSL Implementation Guide

> **Date:** 2026-08-14  
> **Objective:** Translate production-ready Let's Encrypt & Nginx configuration principles (from [esc.sh Let's Encrypt Nginx Definitive Guide](https://blog.esc.sh/letsencrypt-nginx-definitive-guide/)) into actionable, step-by-step procedures for an **Nginx Proxy Manager (NPM)** container / LXC setup.  
> **Target Environment:** Proxmox VE (`Bulakan` - `VLAN 1 [Management]`), NPM Container / LXC  
> **Admin GUI Port:** `81` | **HTTP/HTTPS Ports:** `80` / `443`  
> **Status:** Active / Production Guide  

---

## 1. Concept Mapping: Bare-Metal Nginx vs. Nginx Proxy Manager

Nginx Proxy Manager (NPM) abstracts raw Nginx server blocks and Certbot CLI invocations into an intuitive Web UI backed by an internal SQLite/MySQL database and dynamic configuration engine.

| Concept / Action | Bare-Metal Nginx + Certbot CLI | Nginx Proxy Manager (NPM) GUI / Container |
| :--- | :--- | :--- |
| **Certbot Installation** | `apt install certbot python3-certbot-nginx` | Pre-packaged inside the NPM container/LXC image. |
| **Certificate Request** | `certbot --nginx -d example.com -d www.example.com` | **SSL Certificates** tab $\rightarrow$ Add Let's Encrypt Certificate, or **Proxy Hosts** $\rightarrow$ SSL tab $\rightarrow$ "Request a new SSL Certificate". |
| **HTTP $\rightarrow$ HTTPS Redirect** | `return 301 https://$host$request_uri;` in Port 80 block | Toggle **"Force SSL"** in Proxy Host / Redirection Host settings. |
| **Certificate Auto-Renewal** | Systemd timer (`certbot.timer`) & deploy hooks | Internal NPM scheduler runs renewal checks twice daily; reloads Nginx dynamically. |
| **TLS Hardening (HSTS / HTTP/2)** | Manual `add_header Strict-Transport-Security` & `listen 443 ssl http2` | Toggles for **"Force SSL"**, **"HTTP/2 Support"**, **"HSTS Enabled"**, and **"HSTS Subdomains"**. |
| **WWW $\leftrightarrow$ Non-WWW Redirect** | 4 separate Nginx `server` blocks for HTTP/HTTPS combination | NPM **"Redirection Hosts"** or Advanced Custom Nginx snippets. |
| **Wildcard Certificates** | `certbot certonly --manual --preferred-challenges dns` | SSL Certificates $\rightarrow$ **"Use a DNS Challenge"** with provider API credentials (e.g. Cloudflare). |

---

## 2. Prerequisites & DNS Verification

Before requesting Let's Encrypt certificates, verify DNS records point to your public entry point (Router Public IP or Cloudflare Tunnel edge).

### Verification Commands (Host / Terminal)
```bash
# Check non-www and www DNS propagation
dig +short example.com
dig +short www.example.com

# Alternative check using nslookup
nslookup example.com
```

> [!IMPORTANT]
> **HTTP-01 Challenge Requirement**: If using the standard HTTP-01 challenge, port `80` must be publicly accessible and routed to NPM (`VLAN 1 [Management]:80`).  
> **DNS-01 Challenge (No Open Ports)**: If ports 80/443 are closed (e.g., behind Cloudflare Tunnels or CGNAT), use the **DNS-01 Challenge** described in Section 6.

---

## 3. Step-by-Step Implementation in NPM

### Step 1: Create the Proxy Host & Fetch Certificate (HTTP-01)

1. Log into the NPM Admin Console at `http://VLAN 1 [Management]:81`.
2. Navigate to **Hosts** $\rightarrow$ **Proxy Hosts** $\rightarrow$ Click **Add Proxy Host**.
3. **Details Tab**:
   - **Domain Names**: Enter `example.com` and press `Enter`. Enter `www.example.com` and press `Enter`.
   - **Scheme**: Select `http` or `https` (upstream service protocol).
   - **Forward Hostname / IP**: Enter internal service IP (e.g., `VLAN 1 (Management)` for Authentik or Immich).
   - **Forward Port**: Enter internal service port (e.g., `9000`).
   - **Websockets Support**: Toggle **ON** (recommended for modern web applications).
4. **SSL Tab**:
   - **SSL Certificate**: Select **"Request a new SSL Certificate"**.
   - **Force SSL**: Toggle **ON** (generates HTTP $\rightarrow$ HTTPS 301 redirection).
   - **HTTP/2 Support**: Toggle **ON**.
   - **HSTS Enabled**: Toggle **ON** (adds `Strict-Transport-Security` header).
   - **HSTS Subdomains**: Toggle **ON** (if subdomains are covered).
   - **Email Address for Let's Encrypt**: Enter valid administrative email.
   - **I Agree to the Let's Encrypt Terms of Service**: Check **ON**.
5. Click **Save**. NPM will invoke Certbot in the background, complete the HTTP-01 challenge, write the certificate files into `/data/tls/certbot/live/npm-<id>/`, and activate the HTTPS server block.

---

## 4. HTTP $\rightarrow$ HTTPS Redirection & TLS Hardening

NPM handles HTTP-to-HTTPS redirection natively when **Force SSL** is enabled. To enforce production-grade security headers (matching Section 8 of the reference guide):

1. Edit the Proxy Host in NPM.
2. Click on the **Advanced** tab.
3. Add custom HTTP hardening headers into the **Custom Nginx Configuration** block:

```nginx
# Production TLS & Security Hardening
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header X-XSS-Protection "1; mode=block" always;
```

4. Click **Save**.

---

## 5. Canonical WWW $\leftrightarrow$ Non-WWW Redirection in NPM

The reference guide emphasizes clean canonical domain handling (preventing duplicate content and SSL mismatch errors). In NPM, implement this using **Redirection Hosts**.

### Scenario A: Prefer Non-WWW (`www.example.com` $\rightarrow$ `example.com`)

1. Go to **Hosts** $\rightarrow$ **Redirection Hosts** $\rightarrow$ Click **Add Redirection Host**.
2. **Details Tab**:
   - **Domain Names**: `www.example.com`
   - **Scheme**: `https`
   - **Forward Domain**: `example.com`
   - **Preserve Path**: Toggle **ON** (ensures `www.example.com/foo` redirects to `example.com/foo`).
   - **HTTP Code**: `301 Moved Permanently`.
3. **SSL Tab**:
   - Select your existing certificate covering `www.example.com` (or request a new one).
   - Toggle **Force SSL** **ON**.
4. Click **Save**.

### Scenario B: Prefer WWW (`example.com` $\rightarrow$ `www.example.com`)

1. Go to **Hosts** $\rightarrow$ **Redirection Hosts** $\rightarrow$ Click **Add Redirection Host**.
2. **Details Tab**:
   - **Domain Names**: `example.com`
   - **Scheme**: `https`
   - **Forward Domain**: `www.example.com`
   - **Preserve Path**: Toggle **ON**.
   - **HTTP Code**: `301 Moved Permanently`.
3. **SSL Tab**:
   - Select your certificate covering `example.com`.
   - Toggle **Force SSL** **ON**.
4. Click **Save**.

---

## 6. Wildcard Certificates via DNS-01 Challenge

For internal services, multi-subdomain environments, or no-open-ports setups (Cloudflare Tunnels), use **DNS-01 Challenge** for wildcard SSL certificates (`*.example.com`).

### Setting up Cloudflare DNS API Integration in NPM

1. Generate a Cloudflare API Token with `Zone:DNS:Edit` permissions.
2. In NPM, navigate to **SSL Certificates** $\rightarrow$ Click **Add SSL Certificate** $\rightarrow$ **Let's Encrypt**.
3. **Domain Names**: Enter `*.example.com` and `example.com`.
4. Toggle **Use a DNS Challenge** **ON**.
5. **DNS Provider**: Select `Cloudflare` (or your DNS provider).
6. **Credentials File Content**: Update the token variable:

```ini
# Cloudflare API token
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN_HERE
```

7. **Propagation Seconds**: Set to `30` (allows DNS TXT record to propagate globally).
8. Agree to Terms and click **Save**.

---

## 7. Auto-Renewal & Lifecycle Management

In bare-metal setups, systemd timers (`certbot.timer`) manage renewal. In NPM, this is automated internally:

- **Renewal Frequency**: NPM runs an internal scheduler process every 12 hours checking for certificates expiring within 30 days.
- **Reload Mechanism**: Upon successful certificate renewal, NPM automatically triggers `nginx -s reload` without dropping active connections.

### Manual Renewal Verification (LXC / Container Console)
If you need to verify or test certificate renewal inside the NPM LXC / Container:

```bash
# Enter LXC / Container shell
# Test Certbot renewal in dry-run mode
certbot renew --dry-run

# Inspect active Let's Encrypt certificates
certbot certificates

# Check renewal configuration files
ls -la /etc/letsencrypt/renewal/
```

---

## 8. Verification & Security Testing

After deploying your proxy host and SSL certificate:

1. **Verify HTTP $\rightarrow$ HTTPS Redirect (Curl Test)**:
   ```bash
   curl -I http://example.com/test-path
   # Expected Output: HTTP/1.1 301 Moved Permanently
   # Location: https://example.com/test-path
   ```

2. **Verify TLS Headers**:
   ```bash
   curl -I https://example.com
   # Expected: strict-transport-security: max-age=31536000; includeSubDomains; preload
   ```

3. **Qualys SSL Labs Test**:
   Test your domain at [SSL Labs Server Test](https://www.ssllabs.com/ssltest/) to confirm an **A+ Rating**.

---

## 9. 🔄 Zero-to-Hero Rebuild Playbook (Fresh Deployment)

Follow this exact end-to-end playbook if you need to rebuild your **Nginx Proxy Manager** container and re-establish your **Let's Encrypt Wildcard SSL** setup from scratch.

### Phase 1: Provision NPM LXC on Proxmox VE (Bulakan)
1. Open Proxmox VE Shell on node `Bulakan` (`VLAN 1 [Management]`).
2. Run the Proxmox VE Community Helper Script:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/nginxproxymanager.sh)"
   ```
3. Follow the wizard defaults (Set Static IP: `VLAN 1 [Management]/24`, Gateway: `VLAN 1 [Gateway]`).
4. Access the NPM Admin GUI: `http://VLAN 1 [Management]:81`.
5. Log in using default credentials:
   - **Email**: `admin@example.com`
   - **Password**: `changeme`
6. Update your administrative email and set a secure password when prompted.

---

### Phase 2: Create Cloudflare DNS API Token
1. Log into [Cloudflare Dashboard](https://dash.cloudflare.com/) $\rightarrow$ Profile $\rightarrow$ **API Tokens** $\rightarrow$ **Create Token**.
2. Select **Custom Token** $\rightarrow$ **Get started**.
3. Set **Token Name**: `NPM-Wildcard-SSL`
4. Set **Permissions**: `Zone` $\rightarrow$ `DNS` $\rightarrow$ `Edit`
5. Set **Zone Resources**: `Include` $\rightarrow$ `All zones` (or `homelab-admin.me`).
6. Click **Continue to summary** $\rightarrow$ **Create Token**.
7. Copy and save your API token securely.

---

### Phase 3: Issue Wildcard SSL Certificate (`*.homelab-admin.me`)
1. In NPM (`http://VLAN 1 [Management]:81`), go to **SSL Certificates** $\rightarrow$ **Add SSL Certificate** $\rightarrow$ **Let's Encrypt**.
2. **Domain Names**: Type `*.homelab-admin.me` [Enter], then `homelab-admin.me` [Enter].
3. Toggle **Use a DNS Challenge** $\rightarrow$ Select **Cloudflare**.
4. Set **Credentials File Content**:
   ```ini
   dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN_HERE
   ```
5. Set **Propagation Seconds**: `30`.
6. Agree to Terms of Service $\rightarrow$ Click **Save**.

---

### Phase 4: Recreate Proxy Hosts
In NPM $\rightarrow$ **Hosts** $\rightarrow$ **Proxy Hosts** $\rightarrow$ Click **Add Proxy Host** for each service:

| Domain | Forward IP / Port | Websockets | SSL Cert | Toggles |
| :--- | :--- | :--- | :--- | :--- |
| `auth.homelab-admin.me` | `http://VLAN 110 (Services):9000` | **ON** | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS |
| `photos.homelab-admin.me` | `http://VLAN 110 (Services):2283` | **ON** | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS |
| `media.homelab-admin.me` | `http://VLAN 1 [Management]:8096` | **ON** | `*.homelab-admin.me` | Force SSL, HTTP/2, HSTS |

> [!TIP]
> For **Immich (`photos`)**, open the **Advanced** tab and add `client_max_body_size 50000M;` to support large photo/video uploads.

---

### Phase 5: Verification & Auto-Renewal Confirmation
1. Run a dry-run test inside the NPM LXC container:
   ```bash
   pct exec 502 -- certbot renew --dry-run
   ```
2. Test HTTPS connectivity:
   ```bash
   curl -I https://auth.homelab-admin.me
   curl -I https://photos.homelab-admin.me
   curl -I https://media.homelab-admin.me
   ```

---

## 10. References

- [Original Reference Guide: Let's Encrypt + Nginx Definitive Guide](https://blog.esc.sh/letsencrypt-nginx-definitive-guide/)
- [Nginx Proxy Manager Service Doc](file:////opt/homelab-infrastructure/05-Services/Nginx%20Proxy%20Manager.md)
- [Homelab Guides Index](file:////opt/homelab-infrastructure/06-Guides/Guides%20Index.md)

