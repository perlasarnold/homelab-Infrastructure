# 🎬 Sonarr Reverse Proxy & Wildcard SSL Configuration Guide

- **Date:** August 22, 2026
- **Objective:** Resolve the default "Nginx Proxy Manager - Host not setup yet" landing page when accessing `sonarr.homelab-admin.me` by deploying reverse proxy routing, Wildcard SSL termination (`*.homelab-admin.me`), and security headers to upstream Sonarr running on Cebu CT 417 (`192.168.110.42:8989`).
- **Maintainer:** Perlas

---

## 🔍 Problem Statement & Investigation

### Symptom
Accessing `http://sonarr.homelab-admin.me` in the browser yielded the default NPM catch-all landing page:
> *"Congratulations! You've successfully started the Nginx Proxy Manager. If you're seeing this site then you're trying to access a host that isn't set up yet."*

### Root Cause
1. DNS resolution was successfully routing requests for `sonarr.homelab-admin.me` to the primary Nginx Proxy Manager LXC container (Cebu CT 105 at `192.168.120.211`).
2. NPM had no proxy host definition or Nginx server block mapped to the domain `sonarr.homelab-admin.me`.
3. Upstream Sonarr service was actively listening on Cebu Arr Stack CT 417 (`192.168.110.42:8989`).

---

## 🛠️ Implementation Steps

### 1. Database & Proxy Host Deployment
A new Proxy Host definition (ID `15`) was configured and synchronized in the SQLite database (`/data/database.sqlite`) on Cebu CT 105:
- **Domain:** `sonarr.homelab-admin.me`
- **Forward Scheme / IP / Port:** `http://192.168.110.42:8989`
- **SSL Certificate ID:** `3` (`*.homelab-admin.me`, `homelab-admin.me`)
- **Toggles:** Force SSL, HTTP/2 Support, HSTS Enabled (`max-age=63072000; preload`), Websocket Upgrades, Exploit Blocking.

### 2. Nginx Server Block Configuration
Deployed `/data/nginx/proxy_host/15.conf`:
```nginx
# ------------------------------------------------------------
# sonarr.homelab-admin.me
# ------------------------------------------------------------

map $scheme $hsts_header {
    https   "max-age=63072000; preload";
}

server {
  set $forward_scheme http;
  set $server         "192.168.110.42";
  set $port           8989;

  listen 80;
  listen [::]:80;

  listen 443 ssl;
  listen [::]:443 ssl;

  server_name sonarr.homelab-admin.me;

  http2 on;

  # Let's Encrypt SSL
  include /etc/nginx/conf.d/include/letsencrypt-acme-challenge.conf;
  include /etc/nginx/conf.d/include/ssl-cache.conf;
  include /etc/nginx/conf.d/include/ssl-ciphers.conf;
  ssl_certificate /etc/letsencrypt/live/npm-3/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-3/privkey.pem;

  # HSTS
  add_header Strict-Transport-Security $hsts_header always;

  # Force SSL
  set $trust_forwarded_proto "F";
  include /etc/nginx/conf.d/include/force-ssl.conf;

  # Block Exploits
  include /etc/nginx/conf.d/include/block-exploits.conf;

  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $http_connection;
  proxy_http_version 1.1;

  access_log /data/logs/proxy-host-15_access.log proxy;
  error_log /data/logs/proxy-host-15_error.log warn;

  location / {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    proxy_http_version 1.1;

    # Proxy!
    include /etc/nginx/conf.d/include/proxy.conf;
  }

  # Custom
  include /data/nginx/custom/server_proxy[.]conf;
}
```

### 3. Syntax Verification & Dynamic Reload
```bash
# Verify Nginx configuration syntax
nginx -t

# Perform graceful daemon reload without downtime
nginx -s reload
```

---

## 🧪 Verification & Outcome

1. **HTTP Redirect:**
   ```bash
   curl -I --resolve sonarr.homelab-admin.me:80:127.0.0.1 http://sonarr.homelab-admin.me/
   # Returns HTTP/1.1 301 Moved Permanently -> Location: https://sonarr.homelab-admin.me/
   ```
2. **HTTPS & TLS Handshake:**
   ```bash
   curl -I -k --resolve sonarr.homelab-admin.me:443:127.0.0.1 https://sonarr.homelab-admin.me/
   # Returns HTTP/2 401 (Sonarr Authentication Screen via OpenResty)
   ```
3. **Web GUI:** `https://sonarr.homelab-admin.me` is now fully operational with Let's Encrypt Wildcard SSL encryption.

---

## 📚 References
- [Nginx Proxy Manager Documentation](https://nginxproxymanager.com/)
- [Sonarr Documentation](https://sonarr.tv/)
- [Homelab Services Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
