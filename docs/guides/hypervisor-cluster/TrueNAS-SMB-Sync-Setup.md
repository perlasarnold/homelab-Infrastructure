# Implementation Guide: Automated SMB Sync

Follow these steps to set up the 15-minute sync from `VLAN 1 [Management]` to your TrueNAS server.

## Step 1: Configure Rclone Remote
Open the TrueNAS Shell (Web UI or SSH) and run:
```bash
rclone config
```
Follow the interactive prompts:
1.  **n)** New remote
2.  **name**: `seagate-source`
3.  **Storage**: `smb` (Find the number for SMB in the list)
4.  **host**: `VLAN 1 [Management]`
5.  **user**: (Your SMB Username)
6.  **pass**: (Your SMB Password - select `y` to enter your own password)
7.  **domain/port/etc**: Leave as default unless specifically required.
8.  **Edit advanced config?**: `n`
9.  **Keep this remote?**: `y`

**Verify**: Run `rclone lsd seagate-source:Seagate` to see if your folders appear.

---

## Step 2: Create the Sync Script
Create a persistent script to handle the sync logic and logging.

1.  Run `mkdir -p /mnt/DAS1-18TB/data/scripts`
2.  Run `nano /mnt/DAS1-18TB/data/scripts/sync-seagate.sh`
3.  Paste the following code:

```bash
#!/bin/bash
# Sync Seagate to TrueNAS DAS1
LOCKFILE=/tmp/sync_seagate.lock

# Prevent overlapping runs
if [ -f "$LOCKFILE" ]; then
    # Check if process is still running
    if ps -p $(cat "$LOCKFILE") > /dev/null; then
        echo "Sync already in progress. Exiting."
        exit 1
    fi
fi

# Record current PID
echo $$ > "$LOCKFILE"

echo "Starting sync at $(date)"

# Perform the sync
# Note: 'sync' deletes files on destination if they are gone from source.
# Use 'copy' if you want to keep everything.
/usr/bin/rclone sync seagate-source:Seagate /mnt/DAS1-18TB/data/Seagate/ \
    --transfers 4 \
    --checkers 8 \
    --contimeout 60s \
    --timeout 300s \
    --retries 3 \
    --low-level-retries 10 \
    --stats 1m \
    --log-file=/mnt/DAS1-18TB/data/scripts/rclone-seagate.log \
    --log-level INFO

echo "Sync completed at $(date)"

# Clean up
rm "$LOCKFILE"
```

4.  Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).
5.  Make it executable: `chmod +x /mnt/DAS1-18TB/data/scripts/sync-seagate.sh`

---

## Step 3: Schedule the Task (TrueNAS UI)
1.  Navigate to **Advanced > Cron Jobs** in the TrueNAS Web UI.
2.  Click **Add**.
3.  **Description**: `Sync Seagate SMB to DAS1`
4.  **Command**: `/usr/bin/bash /mnt/DAS1-18TB/data/scripts/sync-seagate.sh`
5.  **Run As User**: `root`
6.  **Schedule**:
    - Select **Custom**.
    - Minutes: `*/15`
    - Hours, Days, Months, Dow: `*`
7.  **Enabled**: Checked.
8.  **Save**.

---

## Step 4: Verification
You can manually trigger the job from the **Cron Jobs** list by clicking the "Run Now" icon to verify the first run works without waiting 15 minutes. 

Monitor the log file at:
`/mnt/DAS1-18TB/data/scripts/rclone-seagate.log`
