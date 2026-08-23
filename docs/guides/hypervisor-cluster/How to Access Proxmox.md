# How to Access Proxmox

**Difficulty:** 🟢 Beginner  
**Time:** ~2 minutes

---

## What you need

- A device on the same network (192.168.1.x)
- A modern web browser (Chrome, Firefox, Edge)
- Your Proxmox login credentials

---

## Steps

### 1. Open the Web Interface

Open your browser and go to:

```
https://VLAN 1 [Management]:8006
```

> ⚠️ **Certificate Warning**: You'll see a "Your connection is not private" warning. This is normal — Proxmox uses a self-signed certificate. Click **Advanced → Proceed to VLAN 1 [Management] (unsafe)** to continue.

### 2. Log In

| Field | Value |
|-------|-------|
| **User name** | `root` (or your username) |
| **Password** | Your Proxmox password |
| **Realm** | `Linux PAM standard authentication` |

Click **Login**.

### 3. You're In!

You'll land on the Proxmox dashboard showing your nodes, VMs, and containers.

---

## What you'll see

- **Left panel** — tree view of your datacenter, nodes, VMs, and containers
- **Top bar** — status, create buttons, search
- **Main panel** — summary/console/config for the selected item

---

## Related

- [[Proxmox Overview]]
- [[How to Create a VM]]
