# Dapitan PNAS Movies Copy

## Date

2026-07-23

## Objective

Provide a safe, restartable script on Dapitan that copies the contents of:

```text
\\pnas\Seagate\Share\Movies\
```

to:

```text
/mnt/bindmounts/media-data/library/movies/
```

The transfer is one-way and does not delete destination files.

## Steps Taken

### 1. Selected safe source and destination handling

- The script mounts `//192.168.1.12/Seagate` temporarily and read-only.
- Cebu's existing Seagate-share credential is reused without printing it.
- Dapitan stores it in the dedicated root-owned, mode `0600` file
  `/etc/dapitan-copy/pnas-seagate.credentials`.
- This is separate from `/etc/pve/priv/storage/PNAS.pw`: the latter belongs
  to the Proxmox backup share and does not have access to `Seagate`.
- The script validates the credential file's owner and mode before mounting,
  and unmounts the source on exit.
- It verifies that the source subdirectory is `Share/Movies`.
- It refuses to run if the source is missing or empty.
- It verifies that the destination is on `bulk18/media-data` and that the
  ZFS dataset is writable.

### 2. Implemented guarded rsync behavior

Repository script:

```text
homelab/scripts/dapitan-copy-pnas-movies.sh
```

Deployed Dapitan path:

```text
/usr/local/sbin/dapitan-copy-pnas-movies
```

Safety behavior:

- Dry-run is the default.
- `--execute` is required to copy files.
- No `--delete` option is used.
- Source ownership and SMB permission modes are not propagated.
- Existing destination files are updated only when normal rsync
  size/time comparison identifies a change.
- Interrupted files are retained in `.rsync-partial` for resumption.
- Throughput defaults to 81,920 KiB/s, approximately 80 MiB/s.
- `nice` and `ionice` reduce impact on active workloads.
- A lock prevents two movie-copy jobs from running simultaneously.
- Synology `#recycle`, `#snapshot`, `@eaDir`, and `.DS_Store` entries are
  excluded.
- Logs are root-only under `/var/log/dapitan-pnas-movies-copy/`.

### 3. Validation commands

Quick mount and path check:

```bash
/usr/local/sbin/dapitan-copy-pnas-movies --check
```

Validation completed successfully on 2026-07-23. It confirmed:

- `//192.168.1.12/Seagate/Share/Movies` is accessible.
- The SMB source is mounted read-only during the check.
- `/mnt/bindmounts/media-data/library/movies` is on
  `bulk18/media-data`.
- The destination dataset is writable.
- 17,849,883,033,600 bytes were available at validation time.
- The temporary source mount was removed after validation.
- No files were copied by the check.

Persistent dry-run:

```bash
systemd-run \
  --unit=dapitan-pnas-movies-dry-run \
  --collect \
  /usr/local/sbin/dapitan-copy-pnas-movies --dry-run
```

Monitor it:

```bash
systemctl status dapitan-pnas-movies-dry-run
journalctl -fu dapitan-pnas-movies-dry-run
```

Review the resulting file-change list and statistics before starting the
real copy.

### 4. Execute the copy

Only after reviewing a successful dry-run:

```bash
systemd-run \
  --unit=dapitan-pnas-movies-copy \
  --collect \
  /usr/local/sbin/dapitan-copy-pnas-movies --execute
```

Monitor it:

```bash
systemctl status dapitan-pnas-movies-copy
journalctl -fu dapitan-pnas-movies-copy
```

The job can be safely rerun. Rsync will skip files that already match.

To override the bandwidth limit:

```bash
/usr/local/sbin/dapitan-copy-pnas-movies \
  --execute \
  --bwlimit-kib 40960
```

## Outcome

The script is installed and its non-copying live validation completed
successfully. It validates the SMB source and ZFS destination before every
run, defaults to a non-writing preview, and copies without mirroring source
deletions into Dapitan.

Installed script SHA-256:

```text
2dbd9126e28a5e4ca0c47b353ff47cbe2ed71a04256b5dd0b4ccc57e8cdd8920
```

Creating and validating the script does not start the bulk movie transfer.
The user must explicitly invoke `--execute`.

## References

- [Dapitan storage plan](./OptiPlex-Proxmox-Direct-Attached-Storage-Plan-2026-07-22.md)
- [Synology to JBOD rsync guide](../02-Proxmox/Rsync%20Guide.md)
- [rsync manual](https://download.samba.org/pub/rsync/rsync.1)
