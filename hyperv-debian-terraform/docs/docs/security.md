# Security

This project follows security best practices throughout. This page explains the model.

---

## Secrets Management — SOPS + age

Secrets (DB passwords, API keys, tokens) are **encrypted at rest** using [SOPS](https://github.com/getsops/sops) with [age](https://github.com/FiloSottile/age) encryption. Encrypted files are safe to commit. The private key lives **only** in GitHub Secrets.

### Setup (one time)

```bash
# 1. Install age
apt install age   # Debian/Proxmox
brew install age  # macOS

# 2. Generate your key pair
age-keygen -o ~/.config/sops/age/keys.txt
# Output example:
#   Public key: age1abc123...
#   (written to keys.txt)

# 3. Paste the public key into .sops.yaml
#    Replace: age1REPLACE_WITH_YOUR_PUBLIC_KEY

# 4. Add the FULL contents of keys.txt as GitHub Secret: SOPS_AGE_KEY
```

### Encrypt a new secret file

```bash
# Create plaintext file
cat > secrets/myservice.env <<EOF
MY_DB_PASSWORD=strongpassword
MY_API_KEY=secretkey
EOF

# Encrypt it
sops --encrypt secrets/myservice.env > secrets/myservice.env.enc

# Delete the plaintext — only commit .env.enc
rm secrets/myservice.env
git add secrets/myservice.env.enc
```

### Edit an existing encrypted file

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/myservice.env.enc
# Opens in $EDITOR — saves re-encrypted automatically
```

---

## SSH Keys — Best Practice

!!! warning "Never commit SSH private keys"
    SSH private keys are written to runner temp storage at workflow runtime and deleted immediately after. They live in GitHub Secrets only.

**Key generation (ed25519 — most secure):**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab-github-actions"
# Private key → GitHub Secret: DEBIAN_SSH_PRIVATE_KEY
# Public key  → cloud-init (Proxmox) or authorized_keys on VM (Hyper-V)
```

**Key rotation (periodically recommended):**

1. Generate a new key pair
2. Run `ansible-bootstrap.yml` with updated `DEBIAN_SSH_PUBLIC_KEY` secret
3. Update `DEBIAN_SSH_PRIVATE_KEY` secret
4. Old key is automatically removed from `authorized_keys`

---

## SSH Hardening (applied by `01_bootstrap.yml`)

| Setting | Value | Why |
|---|---|---|
| `PasswordAuthentication` | `no` | Keys only — no brute-force risk |
| `PermitRootLogin` | `no` | Never log in as root |
| `MaxAuthTries` | `3` | Limits brute-force attempts |
| `LoginGraceTime` | `30s` | Short window for auth |
| `Protocol` | `2` | Only modern SSH2 |
| `X11Forwarding` | `no` | No GUI forwarding |

---

## Firewall (UFW)

Applied by `01_bootstrap.yml`. Default: **deny all inbound, allow all outbound**.

Ports opened:

| Port | Service | Source |
|---|---|---|
| 22 | SSH | Any (Tailscale restricts further) |
| 80 | HTTP | cloudflared only |
| 443 | HTTPS | cloudflared only |

!!! tip
    With Tailscale deployed, you can further restrict SSH to Tailscale IPs only:
    ```bash
    sudo ufw delete allow 22/tcp
    sudo ufw allow in on tailscale0 to any port 22
    ```

---

## fail2ban (applied by `01_bootstrap.yml`)

Automatically bans IPs with 3+ failed SSH attempts for 24 hours.

```bash
# Check ban list:
sudo fail2ban-client status sshd

# Unban an IP:
sudo fail2ban-client set sshd unbanip X.X.X.X
```

---

## Docker Security (applied by `02_install_docker.yml`)

| Setting | Value |
|---|---|
| `no-new-privileges` | true |
| `userns-remap` | default (subuid mapping) |
| `icc` (inter-container comms) | false (explicit networks only) |
| Log rotation | 10MB max, 3 files |

---

## Database SQL Injection Prevention

All services in this project use databases only through their official images, which use **parameterized queries** and **ORMs** internally:

| Service | ORM/Driver | SQL injection safe? |
|---|---|---|
| Wiki.js | Knex.js (parameterized) | ✅ |
| Nextcloud | Doctrine ORM | ✅ |
| Vaultwarden | SQLite/Diesel ORM | ✅ |
| Immich | Prisma + TypeORM | ✅ |
| Guacamole | MyBatis (prepared stmts) | ✅ |
| Grafana | GORM | ✅ |

All database passwords are stored in SOPS-encrypted files and written as `0600` `.env` files on the VM — never in compose YAML.

---

## GitHub Environments (deployment gate)

The `docker-deploy.yml` workflow uses the `homelab-production` environment.
Set up a required reviewer so deployments need approval:

**Repo → Settings → Environments → homelab-production → Required reviewers**

---

## Secret Leak Scanning

The `validate.yml` workflow runs [Gitleaks](https://github.com/gitleaks/gitleaks) on every push and PR to catch accidentally committed secrets before they reach the repo history.
