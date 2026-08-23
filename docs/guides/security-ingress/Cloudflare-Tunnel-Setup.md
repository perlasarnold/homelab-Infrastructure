# ☁️ Cloudflare Tunnel Setup & Redundancy Guide

This guide walks you through setting up a new Cloudflare Tunnel or adding a redundant "connector" to an existing tunnel for High Availability (HA).

---

## 1. Prerequisites
- A Cloudflare account with a domain pointed to Cloudflare.
- A Proxmox LXC container (Debian 12/13 recommended).
- Internet access inside the container (Bridge: `vmbr0`).

---

## 2. Installation Steps (Inside LXC)

If you are using a fresh Debian LXC, run these commands to install the `cloudflared` agent:

```bash
# 1. Update and install dependencies
apt update && apt install wget dpkg -y

# 2. Download the latest cloudflared package
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# 3. Install the package
dpkg -i cloudflared-linux-amd64.deb

# 4. Verify installation
cloudflared --version
```

---

## 3. Connecting to your Account

### Option A: Adding a Redundant Connector (Active-Active)
To add a new node to your existing tunnel (e.g., adding Cebu to the Bulakan tunnel):

1.  Go to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
2.  Navigate to **Networks** -> **Tunnels**.
3.  Click your existing Tunnel (e.g., `Bulakan-CF1`) -> **Edit**.
4.  Navigate to the **Overview** tab.
5.  Under **Install and run a connector**, select the **Debian** tab.
6.  Look at the command block. The **Token** is the long alphanumeric string at the very end of the command (starting after `service install`).
7.  Run the following in your new container:
    ```bash
    cloudflared service install <YOUR_TOKEN_HERE>
    ```

### Option B: Creating a Brand New Tunnel
1.  In the Dashboard, click **Create a Tunnel**.
2.  Select **cloudflared** and give it a name.
3.  Choose your environment (e.g., **Debian**).
4.  Cloudflare will display a command like `sudo cloudflared service install eyJhIjoi...`.
5.  Copy only the string after `service install`. This is your token.

---

## 4. Verification & Management

### Check local service status:
```bash
systemctl status cloudflared
```

### View live logs:
```bash
journalctl -u cloudflared -f
```

### Active-Active Check:
In the Cloudflare Dashboard, verify that **Connectors** shows multiple instances (e.g., `cloudflared` and `cloudflared-cebu`) both marked as **Connected**.

---

## 5. Troubleshooting

| Issue | Solution |
| :--- | :--- |
| **`command not found`** | Ensure `dpkg -i` finished successfully. Check `/usr/bin/cloudflared`. |
| **`Temporary failure in name resolution`** | Check your container's DNS. Try `echo "nameserver 1.1.1.1" > /etc/resolv.conf`. |
| **`Destination Host Unreachable`** | Your LXC is likely on an isolated bridge (like `vnet1`). Switch it to `vmbr0` in Proxmox. |
| **Wrong Token** | Run `cloudflared service uninstall` then rerun the install command with the correct token. |
