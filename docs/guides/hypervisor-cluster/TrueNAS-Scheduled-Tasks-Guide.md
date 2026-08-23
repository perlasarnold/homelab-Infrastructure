# Guide: Creating Scheduled Tasks in TrueNAS SCALE

Scheduled tasks (Cron Jobs) allow you to automate scripts, maintenance commands, and sync operations in TrueNAS.

## 1. Accessing the Tasks Menu

1. Log in to your TrueNAS SCALE web interface (e.g., `VLAN 1 (Mgmt)`).
2. On the left sidebar, click **System Settings**.
3. Select **Advanced**.
4. Find the **Cron Jobs** card and click **Add**.

---

## 2. Configuring a New Task

When adding a task, fill in the following fields:

- **Description**: A clear name for the task (e.g., `Sync Seagate SMB to DAS1`).
- **Command**: The full path to the script or command you want to run.
  - *Example*: `/usr/bin/bash /mnt/DAS1-18TB/data/scripts/sync-seagate.sh`
- **Run As User**: Usually `root` for system tasks, or a specific service user for restricted tasks.
- **Schedule**:
  - Use the **Presets** (Hourly, Daily, etc.) for simple tasks.
  - Select **Custom** to use standard Cron syntax (e.g., `*/15 * * * *` for every 15 minutes).
- **Hide Stdout/Stderr**:
  - **Uncheck** this while testing to ensure you can see errors in the logs.
  - **Check** this once the task is stable to avoid filling up logs.
- **Enabled**: Ensure this is checked.

---

## 3. Testing and Verification

### Manual Trigger
You don't have to wait for the schedule to trigger the task for the first time.
1. Go to **System Settings > Advanced > Cron Jobs**.
2. Click the **Run Now** icon (play button) next to your task.
3. Check the logs or the target destination to ensure the task executed correctly.

### Checking Logs
TrueNAS logs cron execution to the system logs. You can also redirect output in your command for easier debugging:
`bash /path/to/script.sh > /path/to/log.log 2>&1`

---

## 4. Other Types of Scheduled Tasks

TrueNAS has specialized menus for specific automated tasks:

- **Cloud Sync Tasks**: (**Data Protection > Cloud Sync Tasks**) For syncing data to S3, Google Drive, Backblaze, etc.
- **Replication Tasks**: (**Data Protection > Replication Tasks**) For ZFS snapshots and syncing between pools or servers.
- **SMART Tests**: (**Data Protection > SMART Tests**) For scheduled hard drive health checks.
- **Scrub Tasks**: (**Data Protection > Scrub Tasks**) For ZFS data integrity verification.

---

## Related Guides
- [[TrueNAS-SMB-Sync-Setup]] — Practical example of using a scheduled task for data mirroring.
- [[TrueNAS-on-Proxmox-Setup]] — How to set up the underlying TrueNAS VM.
