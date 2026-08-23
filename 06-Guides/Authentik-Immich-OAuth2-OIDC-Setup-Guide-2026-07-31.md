# 🔐 Authentik OAuth2/OIDC Integration Guide for Immich Photo Server

- **Date:** July 31, 2026
- **Objective:** Document the setup, configuration, troubleshooting, and lessons learned for integrating Authentik Single Sign-On (SSO) over OpenID Connect (OIDC) / OAuth2 with the Immich Photo Management server (`immich.homelab-admin.me`).
- **Status:** Production Active / Verified Working

---

## 📐 System Topology & Subnet Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Homelab-Net HOMELAB                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [ Public Internet User ]                                                   │
│             │                                                               │
│             ▼                                                               │
│  [ Cloudflare Edge HTTPS ]                                                  │
│             │                                                               │
│             ▼                                                               │
│  [ Cloudflare Tunnel: Bulakan-CF1 ] ◄── DMZ (VLAN 120)                      │
│        │                        │                                           │
│        │ (auth.homelab-admin.me)  │ (immich.homelab-admin.me)                  │
│        ▼                        ▼                                           │
│  [ Authentik (CT 103) ]   [ Immich (CT 504) ] ◄── SERVICES (VLAN 110)       │
│  VLAN 110 (Services):9000     VLAN 110 (Services):2283                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Component | Node / Guest ID | IP Address | Subnet / VLAN | External Domain |
| :--- | :--- | :--- | :--- | :--- |
| **Authentik IdP** | Cebu CT 103 | `VLAN 110 (Services)` | SERVICES (VLAN 110) | `https://auth.homelab-admin.me` |
| **Immich Server** | Dapitan CT 504 | `VLAN 110 (Services)` | SERVICES (VLAN 110) | `https://immich.homelab-admin.me` |
| **Cloudflare Tunnel** | Bulakan CT 304 / Cebu CT 404 | `VLAN 120 (DMZ)` / `.6` | DMZ (VLAN 120) | `*.homelab-admin.me` |

---

## 🛠️ Step-by-Step Implementation Workflow

### Step 1: Subnet & Network Migration (SERVICES - VLAN 110)
1. Updated Cebu CT 103 (`authentik`) Proxmox network interface (`net0`):
   * **Bridge:** `vmbr0`
   * **VLAN Tag:** `110`
   * **IPv4/CIDR:** `VLAN 110 (Services)/24`
   * **Gateway:** `VLAN 110 (Services)`

### Step 2: Authentik Initial Admin Bootstrapping
1. Navigated to `http://VLAN 110 (Services):9000/if/flow/initial-setup/`.
2. Created the primary administrator password for `akadmin`.
3. Verified administrative access at `https://auth.homelab-admin.me/if/admin/`.

### Step 3: Authentik OIDC Provider & Application Creation
1. **Created Provider (`Provider-Immich`):**
   * **Type:** OAuth2/OpenID Provider
   * **Authorization Flow:** `default-provider-authorization-explicit-consent`
   * **Client Type:** `Confidential`
   * **Redirect URIs:**
     ```text
     https://immich.homelab-admin.me/auth/login
     https://immich.homelab-admin.me/user-settings
     app.immich:/
     ```
   * **Signing Key:** `authentik Self-signed Certificate`
2. **Created Application (`Immich Photos`):**
   * **Name:** `Immich Photos`
   * **Slug:** `immich-photos`
   * **Provider:** `Provider-Immich`
3. Extracted credentials:
   * **Client ID:** `7vGoLwmsjwriwg8eEA9ORykexinBE1hxwCEMfTO2`
   * **Client Secret:** `LVEcisf1FKrn5ckQYK8cmwNi9EaIImfxfxGPy7hTiSvtMn9w9BVNTgpjNJ4A7w18VhMLvM6gkDkrbzmNpxbXXmBt02LvmXrhyGp7umoB92SqVYXXf1lq5UG0v0gQrMGf`

### Step 4: Immich OAuth Web UI Configuration
1. Logged into Immich Admin (`https://immich.homelab-admin.me`) ➡️ **Administration** ➡️ **Settings** ➡️ **OAuth Settings**.
2. Configured parameters:
   * **Enable OAuth:** `Enabled`
   * **Issuer URL:** `https://auth.homelab-admin.me/application/o/immich-photos/`
   * **Client ID:** `7vGoLwmsjwriwg8eEA9ORykexinBE1hxwCEMfTO2`
   * **Client Secret:** `LVEcisf1FKrn5ckQYK8cmwNi9EaIImfxfxGPy7hTiSvtMn9w9BVNTgpjNJ4A7w18VhMLvM6gkDkrbzmNpxbXXmBt02LvmXrhyGp7umoB92SqVYXXf1lq5UG0v0gQrMGf`
   * **Button Text:** `Login with Authentik`
   * **Auto Register:** `Enabled`

---

## ⚠️ Troubleshooting, Errors & Corrections

During deployment, four distinct issues were encountered and resolved:

### Issue 1: Gateway Typo Causing Network Timeout (`ERR_CONNECTION_TIMED_OUT`)
* **Problem Statement:** Navigating to `http://VLAN 110 (Services):9000` resulted in `This site can't be reached / VLAN 110 (Services) took too long to respond`.
* **Investigation:** Inspected Proxmox CT 103 `net0` configuration modal.
* **Root Cause:** A 1-digit typo occurred in the gateway field: `192.168.119.1` was entered instead of `VLAN 110 (Services)`.
* **Correction:** Updated Gateway to `VLAN 110 (Services)` and rebooted CT 103.
* **Prevention:** Double-check subnets when entering Class C gateways.

### Issue 2: Missing Required Authorization Flow Field
* **Problem Statement:** Clicking **Finish** on Authentik's *New Provider* modal triggered error: `Authorization flow: This field may not be null.`
* **Investigation:** Inspected Authentik provider creation form validation requirements.
* **Root Cause:** The `Authorization flow` dropdown was left empty at top of form.
* **Correction:** Selected `default-provider-authorization-explicit-consent` from dropdown list.

### Issue 3: Immich Rejection of HTTP Issuer URL (`only requests to HTTPS are allowed`)
* **Problem Statement:** Clicking *Login with Authentik* on Immich threw error: `Error in OAuth discovery: ClientError: only requests to HTTPS are allowed`.
* **Investigation:** Evaluated Immich OAuth client security specification.
* **Root Cause:** Plain HTTP URL (`http://VLAN 110 (Services):9000/application/o/immich-photos/`) was specified as Issuer URL. Immich enforces HTTPS for OpenID Connect discovery.
* **Correction:** Updated Issuer URL to public HTTPS endpoint: `https://auth.homelab-admin.me/application/o/immich-photos/`.

### Issue 4: Outdated Cloudflare Tunnel Target (`unexpected HTTP response status code`)
* **Problem Statement:** After updating Issuer URL to HTTPS, Immich threw: `Error in OAuth discovery: ClientError: unexpected HTTP response status code`.
* **Investigation:** Tested OpenID discovery endpoint (`https://auth.homelab-admin.me/application/o/immich-photos/.well-known/openid-configuration`).
* **Root Cause:** The `auth.homelab-admin.me` route in Cloudflare Tunnel (`Bulakan-CF1`) was still pointing to legacy IP `http://VLAN 1 (Mgmt):80` (NPM) instead of the new Authentik instance. Cloudflare returned `502 Bad Gateway`.
* **Correction:** Updated `auth.homelab-admin.me` Service URL in Cloudflare Tunnel dashboard to `http://VLAN 110 (Services):9000`.

---

## 📊 Verification & Final Outcome

1. **OpenID Discovery:** `https://auth.homelab-admin.me/application/o/immich-photos/.well-known/openid-configuration` returns `HTTP 200 OK` with valid JSON metadata.
2. **SSO Authentication Flow:** Clicking **"Login with Authentik"** on `https://immich.homelab-admin.me` redirects smoothly to `auth.homelab-admin.me`, authenticates credentials, and redirects back to Immich logged in.
3. **Auto-Provisioning:** Authentik user profile automatically creates a corresponding Immich user account upon first login.

---

## 🔗 Related Documentation & References

- [Services Index](file:////opt/homelab-infrastructure/05-Services/Services%20Index.md)
- [Dapitan Immich Setup Guide](file:////opt/homelab-infrastructure/06-Guides/Dapitan-Immich-Server-Setup-2026-07-24.md)
- [UniFi Network Foundation Guide](file:////opt/homelab-infrastructure/06-Guides/UniFi-Network-Foundation-Setup-Guide-2026-07-30.md)
