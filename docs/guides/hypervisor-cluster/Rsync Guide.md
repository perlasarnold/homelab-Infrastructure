# 🔄 Synology to JBOD Sync Guide (Layman's Version)

This guide explains how we set up a "Sync" between your Synology NAS (PNAS) and your big 18TB disk on Cebu.

## 📖 The Big Picture
Imagine you have two bookshelves.
1. **Source (Synology):** The "Seagate" folder on your NAS.
2. **Destination (Cebu):** The "das-18tb-1" disk on your new server.

We want Cebu to check the Synology bookshelf and copy any new books (files) to its own shelf.

---

## 🛠️ Step 1: The Connection (Mounting)
Before Cebu can copy files, it needs to be able to "see" the Synology folder. We did this by "mounting" it.

- **Synology Path:** `//VLAN 1 [Management]/Seagate`
- **Cebu Path:** `/mnt/pve/PNAS-Seagate` (This is like a shortcut on Cebu that leads to the NAS).

> [!NOTE]
> If you ever reboot Cebu and the folder looks empty, you might need to re-run the "mount" command. (I can help you automate this later).

---

## 🚀 Step 2: The Copying (Rsync)
We use a tool called `rsync`. It's smart: it only copies files that are new or have changed.

### How to run a sync manually:
1. Log into your **Cebu Shell** (the black command-line screen).
2. Type this command:
   ```bash
   rsync -av --progress /mnt/pve/PNAS-Seagate/ /das-18tb-1/
   ```

### What do those letters mean?
- `-a` (Archive): Keep everything exactly as it is (dates, permissions, etc.).
- `-v` (Verbose): Tell me what you're doing.
- `--progress`: Show a progress bar so you know how fast it's going.
- `/mnt/pve/PNAS-Seagate/`: Where the files are coming **FROM**.
- `/das-18tb-1/`: Where the files are going **TO**.

---

## 🕰️ Step 3: Running in the Background (Screen)
Since 18TB is a LOT of data, the sync might take days. If you close your browser, the sync will stop. To prevent this, we use `screen`.

1. In the Cebu Shell, type: `screen -S sync`
2. Now run the `rsync` command from Step 2.
3. To "detach" (leave it running in the background), press `Ctrl + A`, then `D`.
4. You can now close your browser!

### To check on it later:
1. Open the Cebu Shell.
2. Type: `screen -r sync`
3. You'll see the progress bar right where you left it.

---

## ⚠️ Important Tips
- **One-Way Street:** This sync only goes from Synology ➡️ Cebu. If you delete a file on Cebu, it won't be deleted on Synology.
- **Delete on Source:** By default, if you delete a file on Synology, it **STAYS** on Cebu. If you want it to delete on Cebu too, add `--delete` to the command (be careful!).
