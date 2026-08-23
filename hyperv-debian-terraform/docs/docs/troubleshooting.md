# Troubleshooting

A self-correcting reference for common issues. Check here before opening a GitHub issue.

---

## GitHub Actions Runner

### Runner shows as offline in GitHub

```bash
# On the Proxmox/Linux host:
sudo systemctl status actions.runner.*
sudo systemctl restart actions.runner.*

# Check logs:
journalctl -u actions.runner.* -n 50
```

**Self-fix:** The `docker-watchdog` cron installed by `04_maintenance.yml` restarts the runner service if it stops. Verify it's installed:
```bash
crontab -l | grep watchdog
```

---

## Terraform

### `rgl/hyperv` provider: connection refused on port 5986

```powershell
# On Windows host, check WinRM listener:
winrm enumerate winrm/config/listener
# Should show HTTPS on port 5986

# If missing, re-run:
.\setup\01_enable_hyperv_winrm.ps1
```

### `bpg/proxmox` provider: 401 Unauthorized

- Verify the API token in Proxmox: **Datacenter → API Tokens**
- Ensure `PROXMOX_VE_API_TOKEN` secret is in format: `root@pam!terraform=SECRET`
- Check token has `PVEAdmin` or `Administrator` role on `/`

### Terraform state locked

```bash
# If a workflow was cancelled and left a lock:
terraform force-unlock LOCK_ID
```

---

## Ansible

### `UNREACHABLE` — SSH timeout

```bash
# Test SSH manually from the runner:
ssh -i /path/to/key debian@VM_IP -o ConnectTimeout=10

# Check UFW on the VM:
sudo ufw status
sudo ufw allow 22/tcp   # if accidentally blocked
```

### `FAILED — Permission denied`

```bash
# Verify the VM user is in sudoers:
ssh debian@VM_IP "sudo whoami"
# Should return: root
```

### Playbook fails midway — how to re-run safely

All Ansible playbooks are **idempotent** — safe to re-run. Just trigger the workflow again. Tasks that already succeeded will be skipped.

---

## Docker

### Container keeps restarting

```bash
# SSH via Guacamole or Tailscale, then:
docker logs <container-name> --tail 50
docker inspect <container-name> --format '{{.State.ExitCode}}'
```

Common causes:

| Exit Code | Meaning | Fix |
|---|---|---|
| 1 | Application error | Check logs |
| 137 | OOM killed | Increase memory limit in compose |
| 126/127 | Command not found | Wrong image or entrypoint |

### Disk full — Docker cleanup

```bash
docker system prune -af --volumes   # WARNING: removes ALL unused volumes
docker system df                    # see what's using space
```

**Better:** trigger the **Auto-Remediation** workflow from GitHub Actions — it does targeted cleanup without touching active volumes.

### Port already in use

```bash
ss -tulpn | grep :<PORT>
# Find which container has it:
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

---

## Services

### Wiki.js — blank page or can't connect to DB

```bash
docker logs wikijs --tail 50
# Usually a DB_PASS mismatch between wikijs and wikijs-db services
# Check your .env file matches in both services
```

### Vaultwarden — Bitwarden clients can't connect

!!! warning
    Vaultwarden requires **HTTPS**. Bitwarden clients reject plain HTTP.

Fix: set up Nginx Proxy Manager with a Let's Encrypt certificate pointing to `vaultwarden:80`.

### Pi-hole — port 53 conflict

```bash
# Disable systemd-resolved:
sudo systemctl disable --now systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
# Then restart Pi-hole:
docker compose -f /opt/homelab/stacks/pihole/docker-compose.yml restart
```

### Immich — faces not being recognised

Immich ML requires enough RAM. Check `docker stats immich-ml`. If consistently OOMing, increase the VM's RAM via Terraform and re-apply.

---

## Networking

### Cloudflare Tunnel — tunnel not appearing in dashboard

```bash
docker logs cloudflared --tail 30
# Look for: "Registered tunnel connection"
# If TUNNEL_TOKEN is wrong you'll see authentication errors
```

### Tailscale — device not appearing in admin console

```bash
docker logs tailscale --tail 30
# Common: TS_AUTHKEY expired — generate a new one and update the secret
docker compose down && docker compose up -d
```

---

## Storage

### Check disk usage at a glance

```bash
df -h /
du -sh /opt/homelab/stacks/*/
docker system df
```

### Low disk — automated fix

The **Auto-Remediation** workflow (hourly) handles disk cleanup automatically when above 80%. If disk hits 90%+, it creates a CRITICAL alert and the GitHub Actions job fails, sending you an email.

---

## Self-Healing Reference

| Problem | Auto-Fixed? | Manual Fix |
|---|---|---|
| Container stopped | ✅ Every 5 min (watchdog) | `docker compose up -d` |
| Disk > 80% | ✅ Hourly (auto-remediation) | `docker system prune -af` |
| RAM pressure | ✅ Hourly (drop page cache) | Restart memory-hungry container |
| Security patches | ✅ Daily (unattended-upgrades) | `apt-get dist-upgrade` |
| Monthly full update | ✅ 1st of month 03:00 | Trigger `scheduled-maintenance.yml` |
| Runner offline | ✅ systemd auto-restart | `systemctl restart actions.runner.*` |
| VM needs reboot | ✅ Monthly (2-4am window) | `sudo reboot` |
