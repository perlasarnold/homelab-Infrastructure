# Synology DSM settings export (local)

Remote IDEs and cloud assistants **cannot** open `https://pnas.local:5001/` — `.local` hostnames only resolve on your LAN.

To **document current DSM settings**, run this on **your PC** on the same network as the NAS.

## Prerequisites

- **Python 3.10+** from [python.org](https://www.python.org/downloads/) or `winget install Python.Python.3.12`  
  (The Microsoft Store “python” stub is not enough — you need a real interpreter.)
- For **browser login**: `pip install -r requirements-browser.txt` then `playwright install chromium` once.

## Authentication (choose one)

### A) Browser login (recommended if you use 2FA)

Opens a **visible** browser via Playwright. On **Windows**, **Microsoft Edge** is used by default (the bundled Chromium build sometimes does not show a window or is blocked by security software). You sign in normally; the tool captures the DSM session from API traffic, then runs the export.

```powershell
cd scripts\synology-dsm-export
pip install -r requirements-browser.txt
playwright install chromium
python dump_dsm_settings.py --browser
```

If **no window appears**: check the taskbar; try `--browser-channel chrome` (Chrome must be installed) or `--browser-channel chromium` after `playwright install chromium`. Allow Playwright/your browser in antivirus or **Smart App Control**.

If the window is open but the script **never captures a session**: stop it (Ctrl+C), `git pull` / save the latest `dump_dsm_settings.py`, and run again. The exporter listens on the **whole browser context** (iframes), parses **JSON POST** bodies, reads **`SYNO.Session.sid`** from every frame every 2s, and matches `_sid=` in URLs. After login, open **Control Panel** or **Package Center** so DSM issues webapi calls.

Environment: `DSM_PLAYWRIGHT_CHANNEL=msedge|chrome|chromium|auto`

Or:

```powershell
.\Run-DsmExport.ps1 -InstallDeps -InstallPlaywrightBrowser
```

### B) Username / password (`.env`)

```powershell
copy .env.example .env
notepad .env
pip install -r requirements.txt
python dump_dsm_settings.py
```

Set `DSM_URL`, `DSM_USER`, `DSM_PASS`. May not work with all 2FA setups.

### C) Existing session (after logging in with a normal browser)

1. Log in to DSM in Chrome/Edge.
2. Open DevTools → **Network**, trigger any action (open Control Panel).
3. Find a request to `entry.cgi` or `webapi`, copy `_sid=` (and `_syno_token=` if present).

```powershell
$env:DSM_URL = "https://pnas.local:5001"
$env:DSM_SID = "<paste _sid>"
$env:DSM_SYNO_TOKEN = "<optional>"
python dump_dsm_settings.py
```

## Options

- `--no-probe-catalog` — faster; skips probing every API in `SYNO.API.Info` (only static list + full API catalog JSON).
- `--max-probe-calls 400` — cap catalog probes (default 400).
- `--wait-browser 600` — seconds to wait for session capture during `--browser`.

Default SSL verification is **off** for typical self-signed NAS certs. For strict TLS:

```powershell
$env:DSM_VERIFY_SSL = "1"
```

## Outputs (gitignored)

- `out/dsm-full-<timestamp>.md` — short Markdown with truncated samples
- `out/dsm-full-<timestamp>.json` — **full** export (all sections, including probes)

## What it captures

`SYNO.API.Info` (full catalog metadata), a long **static** endpoint list, then **catalog probing**: for each published `entry.cgi` API, tries read-like methods (`get`, `list`, `info`, …) and **keeps successful responses only** (up to `--max-probe-calls` attempts).

Some APIs need parameters or are absent on your model — those simply won’t appear in the probe results.

For a **restore-capable** backup, use DSM **Control Panel → Update & Restore → Configuration Backup** (or Hyper Backup). This tool is for **documentation and drift snapshots**, not bare-metal restore.

## Security

- Never commit `.env` or `out/` (see `.gitignore` here).
- Treat exports as sensitive; they describe your network and services.
