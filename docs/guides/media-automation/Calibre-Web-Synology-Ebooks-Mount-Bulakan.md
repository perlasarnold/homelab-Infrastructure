# Calibre-Web Synology Ebooks Mount (Bulakan)

**Date:** July 17, 2026  
**Objective:** Mount the Synology folder `\\PNAS\Media\Ebooks` on Bulakan and expose it persistently to Calibre-Web LXC 113.

## Resulting Layout

| Layer | Path |
|---|---|
| Synology SMB source | `//VLAN 1 [MGMT-NAS]/Media/Ebooks` |
| Bulakan host | `/mnt/ebooks` |
| Calibre-Web LXC 113 | `/books` |
| Calibre library database | `/books/Calibre/metadata.db` |

## Steps Taken

1. Identified Calibre-Web as unprivileged LXC 113 on Bulakan.
   - Rationale: SMB is mounted on the Proxmox host and passed through as a bind mount, avoiding CIFS privileges inside the container.
2. Tested the share temporarily using the existing Synology account.
   - Confirmed 50 top-level entries.
   - Confirmed container-mapped UID/GID `100000` could create and remove a test file.
3. Created `/root/.pnascredentials` with mode `0600` rather than adding another plaintext password to `/etc/fstab`.
4. Added the persistent host mount to `/etc/fstab`:

   ```fstab
   //VLAN 1 [MGMT-NAS]/Media/Ebooks /mnt/ebooks cifs credentials=/root/.pnascredentials,iocharset=utf8,vers=3.0,uid=100000,gid=100000,file_mode=0664,dir_mode=0775,noperm,nobrl,_netdev,nofail,x-systemd.automount 0 0
   ```

   - `_netdev`, `nofail`, and `x-systemd.automount` make the network mount resilient when the NAS is unavailable during early boot.
   - `nobrl` disables CIFS byte-range locks that prevented Calibre from opening the SQLite database for writes.
   - UID/GID `100000` maps ownership to root inside this unprivileged LXC.
5. Added the Proxmox bind mount to `/etc/pve/lxc/113.conf`:

   ```text
   mp0: /mnt/ebooks,mp=/books
   ```

6. Restarted only LXC 113 and verified the mount, write access, Calibre-Web service, and HTTP response.

## Outcome

- Host mount active: `//VLAN 1 [MGMT-NAS]/Media/Ebooks` at `/mnt/ebooks`.
- Container mount active at `/books`.
- Calibre library database found at `/books/Calibre/metadata.db`.
- Active catalog contains 745 books and 822 format records.
- All 807 unique source ebook files are represented in the managed library by SHA-256 content hash.
- Database integrity is `ok` and no cataloged format files are missing.
- `calibre-web.service` is active and the web application responds on port `8083`.
- Pre-change backups are stored in `/root/calibre-ebooks-backup-20260717-135330` on Bulakan.
- The original 18-book library is preserved at `/books/.calibre-import-backup-20260717-143141`.

## Calibre-Web Configuration

In **Admin > Edit Basic Configuration > Database Configuration**, set **Location of Calibre Database** to:

```text
/books/Calibre
```

The selected directory must contain `metadata.db`; do not select the database file itself.

## Bulk Import Troubleshooting and Resolution

### Problem

Calibre-Web initially displayed only 18 books even though the Ebooks share contained 856 ebook-like files across its top-level folders.

### Investigation

- `/books/Calibre/metadata.db` contained 18 book and 18 format records.
- The share contained 838 additional ebook-like files outside the managed Calibre directory.
- Calibre-Web reconnects to `metadata.db`; it does not discover loose files by scanning arbitrary folders.
- A staged `calibredb` import failed with `database is locked` even though no other process held the staged database.
- A temporary CIFS mount using `nobrl` passed an exclusive SQLite transaction test, confirming CIFS byte-range locking as the write blocker.

### Resolution

1. Added `nobrl` to the persistent Ebooks CIFS mount and restarted LXC 113 during a maintenance window.
2. Built a separate staged Calibre library while the original remained online.
3. Generated an import manifest containing 807 real ebook files:
   - Excluded 24 small torrent/readme text files.
   - Excluded seven byte-identical duplicate copies.
4. Imported with Calibre 8.5 and reconciled every source file against the staged library by SHA-256.
5. Added 42 distinct files that Calibre's initial title/author duplicate handling skipped.
6. Verified SQLite integrity, Calibre library consistency, and all cataloged file references.
7. Briefly stopped Calibre-Web, atomically replaced `/books/Calibre` with the staged library, and restarted the service.

### Preventive Measures

- Keep `nobrl` on this CIFS mount while Calibre writes its SQLite database over SMB.
- Add future books through Calibre, `calibredb`, or Calibre-Web upload so `metadata.db` remains authoritative.
- Use **Admin > Reconnect Calibre Database** after external Calibre changes.
- Do not expect Calibre-Web to scan loose files automatically.
- Import logs and manifests are retained inside LXC 113 at `/root/calibre-import-20260717-140826`.

## Scheduled Source Polling Importer

An addition-only systemd polling importer was enabled on July 17, 2026.

### Schedule and Behavior

- Timer: `calibre-source-importer.timer`
- Interval: every 15 minutes with up to 60 seconds of randomized delay
- Source: loose ebook files beneath `/books`, excluding `/books/Calibre` and hidden `.calibre-import-*` directories
- Supported formats: AZW, AZW3, CBR, CBZ, DJVU, DOCX, EPUB, FB2, LIT, LRF, MOBI, ODT, PDF, RTF, and TXT
- Text files smaller than 100 KiB are ignored to avoid importing torrent markers and readme files.
- New or changed files must have the same size and modification time across two polls before import. This avoids importing files that are still being copied.
- Exact content duplicates are skipped using SHA-256.
- Source deletions do not remove managed Calibre books.
- Calibre-Web is stopped only when a stable new file is ready to import, then started immediately after the batch.
- A consistent `metadata.db` backup is created before each non-empty import; the newest seven backups are retained.

The initial baseline contained 814 accepted source paths and zero pending files. Existing files were marked known, preventing the timer from re-importing the completed bulk migration.

### Installed Files

| Purpose | Path |
|---|---|
| Importer | `/usr/local/sbin/calibre-source-importer` |
| Service | `/etc/systemd/system/calibre-source-importer.service` |
| Timer | `/etc/systemd/system/calibre-source-importer.timer` |
| State | `/var/lib/calibre-source-importer/state.json` |
| Database backups | `/var/lib/calibre-source-importer/backups/` |
| Repository source | `scripts/calibre-source-importer.py` |
| Repository tests | `scripts/tests/test_calibre_source_importer.py` |

### Operations

Check the timer and recent imports:

```bash
pct exec 113 -- systemctl list-timers calibre-source-importer.timer --all
pct exec 113 -- journalctl -u calibre-source-importer.service -n 100 --no-pager
```

Run an immediate poll:

```bash
pct exec 113 -- systemctl start calibre-source-importer.service
```

Disable or re-enable polling:

```bash
pct exec 113 -- systemctl disable --now calibre-source-importer.timer
pct exec 113 -- systemctl enable --now calibre-source-importer.timer
```

The pre-install automation backup is `/root/calibre-source-importer-install-backup-20260717-160734` inside LXC 113.

## Rollback

Run from the Bulakan host during a maintenance window:

```bash
cp -a /root/calibre-ebooks-backup-20260717-135330/fstab /etc/fstab
cp -a /root/calibre-ebooks-backup-20260717-135330/113.conf /etc/pve/lxc/113.conf
systemctl daemon-reload
umount /mnt/ebooks
pct reboot 113
```

If `/root/.pnascredentials` is not used by another mount after rollback, remove it separately.

To roll back only the bulk import while retaining the working SMB mount, stop Calibre-Web and restore the preserved library:

```bash
pct exec 113 -- systemctl stop calibre-web
pct exec 113 -- mv /books/Calibre /books/.calibre-import-failed-manual
pct exec 113 -- mv /books/.calibre-import-backup-20260717-143141 /books/Calibre
pct exec 113 -- systemctl start calibre-web
```

The mount-option backup created immediately before adding `nobrl` is `/root/calibre-import-mount-backup-20260717-141347/fstab` on Bulakan.

## References

- [[Synology-Mount-Recovery-Plex-Bulakan]]
- [[Transmission-VPN-Proxmox-Setup]]
- [[05-Services/Services Index]]
