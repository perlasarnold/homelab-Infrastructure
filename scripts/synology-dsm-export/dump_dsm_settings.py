#!/usr/bin/env python3
"""
Export Synology DSM settings via Web API (read-only probes).

Auth (pick one):
  1) Browser:  python dump_dsm_settings.py --browser
  2) Password: DSM_URL, DSM_USER, DSM_PASS in environment or .env
  3) Session:  DSM_SID (and optional DSM_SYNO_TOKEN) after logging in via browser — no password stored

Run on a machine that can reach the NAS (e.g. https://pnas.local:5001).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- Static read-oriented endpoints (api, max_version, method, extra_params) ---
STATIC_ENDPOINTS: list[tuple[str, int, str, dict[str, Any] | None]] = [
    ("SYNO.Core.System", 1, "info", None),
    ("SYNO.Core.System.Utilization", 1, "get", None),
    ("SYNO.Core.Hardware.NeedRestart", 1, "get", None),
    ("SYNO.Core.Hardware.PowerRecovery", 1, "get", None),
    ("SYNO.Core.Hardware.Hibernation", 1, "get", None),
    ("SYNO.Core.Hardware.BeepControl", 1, "get", None),
    ("SYNO.Core.Hardware.FanSpeed", 1, "get", None),
    ("SYNO.Core.FileServ.FTP", 1, "get", None),
    ("SYNO.Core.FileServ.AFP", 1, "get", None),
    ("SYNO.Core.FileServ.NFS", 1, "get", None),
    ("SYNO.Core.FileServ.SMB", 1, "get", None),
    ("SYNO.Core.FileServ.Rsync", 1, "get", None),
    ("SYNO.Core.Network", 2, "get", None),
    ("SYNO.Core.Network.Ethernet", 1, "list", None),
    ("SYNO.Core.Network.Router.Gateway.List", 1, "get", None),
    ("SYNO.Core.Network.Router.Static.Route", 1, "list", None),
    ("SYNO.Core.Network.Router.Topology", 1, "get", None),
    ("SYNO.Core.Network.WOL", 1, "get", None),
    ("SYNO.Core.Network.Proxy", 1, "get", None),
    ("SYNO.Core.Network.UPnP", 1, "get", None),
    ("SYNO.Core.Network.MACClone", 1, "get", None),
    ("SYNO.Core.Network.DHCPServer", 1, "get", None),
    ("SYNO.Core.Network.DHCPServer.WPX", 1, "get", None),
    ("SYNO.Core.Security.AutoBlock", 1, "get", None),
    ("SYNO.Core.Security.ScanPort", 1, "get", None),
    ("SYNO.Core.Security.DSM.Escheck", 1, "get", None),
    ("SYNO.Core.Security.DSM.Proxy", 1, "get", None),
    ("SYNO.Core.Security.DSM.Debug", 1, "get", None),
    ("SYNO.Core.Security.DSM.Rate", 1, "get", None),
    ("SYNO.Core.Security.DSM.SSO", 1, "get", None),
    ("SYNO.Core.Security.DSM.Sudo", 1, "get", None),
    ("SYNO.Core.Security.DSM.Notify", 1, "get", None),
    ("SYNO.Core.Terminal", 1, "get", None),
    ("SYNO.Core.SNMP", 1, "get", None),
    ("SYNO.Core.Upgrade.Server", 1, "get", None),
    ("SYNO.Core.Upgrade.Setting", 1, "get", None),
    ("SYNO.Core.QuickConnect", 1, "get", None),
    ("SYNO.Core.QuickConnect.Permission", 1, "get", None),
    ("SYNO.Core.ExternalCloud.Sync", 1, "get", None),
    ("SYNO.Core.FileServ.ServiceDiscovery", 1, "get", None),
    ("SYNO.Core.DDNS.Record", 1, "list", None),
    ("SYNO.Core.DDNS.Provider", 1, "list", None),
    ("SYNO.Core.DDNS.ExtIP", 1, "get", None),
    ("SYNO.Core.MyDSAccount", 1, "get", None),
    ("SYNO.Core.Notification.Mail", 1, "get", None),
    ("SYNO.Core.Notification.SMS", 1, "get", None),
    ("SYNO.Core.Notification.Push", 1, "get", None),
    ("SYNO.Core.Notification.Advance", 1, "get", None),
    ("SYNO.Core.Notification.Mobile", 1, "get", None),
    ("SYNO.Core.Notification.Mail.Auth", 1, "get", None),
    ("SYNO.Core.Web.DSM", 1, "get", None),
    ("SYNO.Core.Web.DSM.External", 1, "get", None),
    ("SYNO.Core.CurrentConnection", 1, "get", None),
    ("SYNO.Core.Directory.Domain.Schedule", 1, "get", None),
    ("SYNO.Core.Directory.LDAP", 1, "get", None),
    ("SYNO.Core.Directory.SSO", 1, "get", None),
    ("SYNO.Core.Directory.Domain", 1, "get", None),
    ("SYNO.Core.User", 1, "list", None),
    ("SYNO.Core.Group", 1, "list", None),
    ("SYNO.Core.Share", 1, "list", None),
    ("SYNO.Core.Share.Crypto", 1, "get", None),
    ("SYNO.Core.TaskScheduler", 3, "list", None),
    ("SYNO.Core.Package", 2, "list", None),
    ("SYNO.Core.Package.Server", 2, "list", None),
    ("SYNO.Core.Package.Setting", 1, "get", None),
    ("SYNO.Core.Package.Log", 1, "list", None),
    ("SYNO.Core.Package.Installation", 1, "list", None),
    ("SYNO.Core.Package.Control", 1, "get", None),
    ("SYNO.Core.BandwidthControl.Protocol", 1, "get", None),
    ("SYNO.Core.BandwidthControl.Status", 1, "get", None),
    ("SYNO.Core.BandwidthControl.Smart", 1, "get", None),
    ("SYNO.Core.Virtualization.Host", 1, "get", None),
    ("SYNO.Core.iSCSI.LUN", 1, "list", None),
    ("SYNO.Core.iSCSI.Target", 1, "list", None),
    ("SYNO.Core.Backup.Config.Backup", 1, "get", None),
    ("SYNO.Core.Backup.Config.Restore", 1, "get", None),
    ("SYNO.ResourceMonitor.Utilization", 1, "get", None),
    ("SYNO.ResourceMonitor.Log", 1, "get", None),
    ("SYNO.Storage.CGI.Storage", 1, "load_info", None),
    ("SYNO.Storage.CGI.Disk", 1, "list", None),
    ("SYNO.Storage.CGI.HddMan", 1, "list", None),
    ("SYNO.Storage.CGI.Smart", 1, "get", None),
    ("SYNO.FolderSharing", 1, "list", None),
    ("SYNO.FileStation.Info", 1, "get", None),
    ("SYNO.FileStation.List", 1, "list_share", None),
    ("SYNO.LogCenter.RecvRule", 1, "list", None),
    ("SYNO.LogCenter.Setting", 1, "get", None),
    ("SYNO.Core.SyslogClient.Setting", 1, "get", None),
    ("SYNO.Core.SyslogClient.Status", 1, "get", None),
    ("SYNO.Core.TFTP", 1, "get", None),
    ("SYNO.Core.NTP.Server", 1, "get", None),
    ("SYNO.Core.NTP.Client", 1, "get", None),
    ("SYNO.Core.Region.NTP", 1, "get", None),
    ("SYNO.Core.Region.Language", 1, "get", None),
    ("SYNO.Core.Region.DataFormat", 1, "get", None),
    ("SYNO.Core.Region.NTPDateTime", 1, "get", None),
]

PROBE_METHODS = ("get", "list", "info", "query", "load_info", "list_share")


def env(name: str, default: str | None = None) -> str | None:
    v = os.environ.get(name, default)
    if v == "":
        return default
    return v


def load_dotenv() -> None:
    p = Path(__file__).resolve().parent / ".env"
    if not p.is_file():
        return
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            k, v = k.strip(), v.strip().strip('"').strip("'")
            if k and k not in os.environ:
                os.environ[k] = v


def api_url(base: str, path: str) -> str:
    base = base.rstrip("/")
    if not path.startswith("/"):
        path = "/" + path
    return base + path


def dsm_login(
    session: requests.Session,
    base: str,
    account: str,
    password: str,
    verify_ssl: bool,
) -> tuple[str, str | None]:
    paths = ("/webapi/auth.cgi", "/webapi/entry.cgi")
    last_text = ""
    for path in paths:
        for version in ("7", "6", "3"):
            r = session.get(
                api_url(base, path),
                params={
                    "api": "SYNO.API.Auth",
                    "version": version,
                    "method": "login",
                    "account": account,
                    "passwd": password,
                    "session": "dsm",
                    "format": "sid",
                },
                verify=verify_ssl,
                timeout=60,
            )
            last_text = r.text
            try:
                data = r.json()
            except json.JSONDecodeError:
                continue
            if data.get("success") and "data" in data:
                sid = data["data"].get("sid")
                if sid:
                    token = data["data"].get("synotoken") or data["data"].get("SynoToken")
                    return sid, token
    print("Login failed. Check URL, user, password, and 2FA.", file=sys.stderr)
    print(last_text[:2000], file=sys.stderr)
    sys.exit(1)


def _playwright_launch_browser(playwright: Any, channel: str | None) -> Any:
    """Prefer real Edge/Chrome on Windows so a visible window appears (bundled Chromium can fail to show)."""
    common: dict[str, Any] = {
        "headless": False,
        "args": [
            "--window-position=80,80",
            "--disable-features=IsolateOrigins,site-per-process",
        ],
    }
    if channel in ("msedge", "chrome", "chrome-beta", "msedge-beta", "msedge-dev"):
        return playwright.chromium.launch(channel=channel, **common)
    return playwright.chromium.launch(**common)


def browser_capture_sid(
    base_url: str,
    wait_seconds: int,
    channel_cli: str | None,
) -> tuple[str, str | None]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(
            "Playwright not installed. Run:\n"
            "  pip install -r requirements-browser.txt\n"
            "  playwright install chromium",
            file=sys.stderr,
        )
        sys.exit(1)

    captured: dict[str, str | None] = {"sid": None, "token": None}

    def _apply_sid_qs(qs: dict[str, list[str]]) -> None:
        for key in qs:
            lk = key.lower()
            if lk == "_sid" and qs[key]:
                captured["sid"] = qs[key][0]
            if lk == "_syno_token" and qs[key]:
                captured["token"] = qs[key][0]

    def _parse_post_data(pd: str) -> None:
        if not pd or len(pd) > 2_000_000:
            return
        pd_strip = pd.strip()
        if pd_strip.startswith("{"):
            try:
                j = json.loads(pd_strip)
                if isinstance(j, dict):
                    for k, v in j.items():
                        lk = k.lower()
                        if lk == "_sid" and v and not captured["sid"]:
                            captured["sid"] = str(v)
                        if lk == "_syno_token" and v and not captured["token"]:
                            captured["token"] = str(v)
            except json.JSONDecodeError:
                pass
        if "=" in pd:
            try:
                _apply_sid_qs(parse_qs(pd, strict_parsing=False))
            except Exception:
                pass

    _sid_in_url = re.compile(r"[&?]_sid=([^&#]+)", re.I)

    def _scan_url_for_sid(url: str) -> None:
        m = _sid_in_url.search(url)
        if m and not captured["sid"]:
            captured["sid"] = unquote(m.group(1).strip())

    def on_request(req: Any) -> None:
        url = req.url
        pd = req.post_data or ""
        if (
            "/webapi/" not in url
            and ".cgi" not in url.lower()
            and "_sid" not in url
            and "_sid" not in pd
        ):
            return
        _scan_url_for_sid(url)
        _apply_sid_qs(parse_qs(urlparse(url).query))
        _parse_post_data(pd)

    def on_response(resp: Any) -> None:
        try:
            url = resp.url
            if "/webapi/" not in url and ".cgi" not in url.lower():
                return
            body = resp.body()
            if not body:
                return
            ct = (resp.headers.get("content-type") or "").lower()
            text = body.decode("utf-8", errors="replace")
            if "json" not in ct and not text.strip().startswith("{"):
                return
            j = json.loads(text)
            if not isinstance(j, dict):
                return
            data = j.get("data")
            if isinstance(data, dict):
                if data.get("sid") and not captured["sid"]:
                    captured["sid"] = str(data["sid"])
                t = data.get("synotoken") or data.get("SynoToken")
                if t and not captured["token"]:
                    captured["token"] = str(t)
        except Exception:
            pass

    # CLI overrides DSM_PLAYWRIGHT_CHANNEL. Use Edge on Windows by default (visible window).
    raw = (channel_cli or env("DSM_PLAYWRIGHT_CHANNEL") or "").strip().lower()
    if raw in ("", "auto"):
        browser_channel = "msedge" if sys.platform == "win32" else None
    elif raw == "chromium":
        browser_channel = None
    else:
        browser_channel = raw

    channel_label = browser_channel or "bundled Chromium"
    print(
        f"Starting Playwright ({channel_label}) — first launch can take 10–20s.\n"
        f"If no window appears, check the taskbar; on Windows, Edge is used by default.\n"
        f"Target: {base_url}\n"
        "Log in to DSM (2FA OK). After the desktop loads, open Control Panel or File Station — "
        "the exporter listens for API traffic with your session id.\n",
        flush=True,
    )

    deadline = time.time() + wait_seconds
    browser = None
    with sync_playwright() as pw:
        try:
            browser = _playwright_launch_browser(pw, browser_channel)
        except Exception as e1:
            if browser_channel:
                print(
                    f"Could not launch {browser_channel}: {e1}\nRetrying with bundled Chromium...",
                    flush=True,
                )
                try:
                    browser = _playwright_launch_browser(pw, None)
                except Exception as e2:
                    print(
                        "Failed to start any browser.\n"
                        "- Install Microsoft Edge (Windows) or Google Chrome, or run:\n"
                        "    playwright install chromium\n"
                        "- Temporarily allow the browser in antivirus / Smart App Control.\n"
                        f"Errors: {e1!r} | {e2!r}",
                        file=sys.stderr,
                    )
                    raise SystemExit(1) from e2
            else:
                print(
                    f"Could not start bundled Chromium: {e1}\n"
                    "Try:  set DSM_PLAYWRIGHT_CHANNEL=msedge\n"
                    "  or:  playwright install chromium",
                    file=sys.stderr,
                )
                raise SystemExit(1) from e1

        try:
            context = browser.new_context(ignore_https_errors=True)
            # Context-level listeners catch traffic from iframes / workers (DSM uses iframes heavily).
            context.on("request", on_request)
            context.on("response", on_response)
            page = context.new_page()
            page.set_default_timeout(120_000)
            print("Browser window should be open — bring it to the front if you only see this terminal.\n", flush=True)
            try:
                page.goto(base_url, wait_until="domcontentloaded", timeout=120_000)
            except Exception as nav_err:
                print(
                    f"Note: initial page load reported: {nav_err}\n"
                    f"If the window is blank, type this URL in the address bar: {base_url}\n",
                    flush=True,
                )
            last_ping = time.time()
            last_dom = 0.0

            def try_syno_session_from_frames() -> None:
                """Read SYNO.Session.sid from main page and every iframe (DSM desktop is iframe-heavy)."""
                if captured["sid"]:
                    return
                js = """() => {
                  const pick = (w) => {
                    try {
                      if (!w) return null;
                      if (w.SYNO && w.SYNO.Session && w.SYNO.Session.sid) return String(w.SYNO.Session.sid);
                      if (w._session && w._session.sid) return String(w._session.sid);
                    } catch (e) {}
                    return null;
                  };
                  return pick(window) || pick(window.top) || pick(window.parent);
                }"""
                for fr in page.frames:
                    try:
                        got = fr.evaluate(js)
                        if got:
                            captured["sid"] = str(got)
                            return
                    except Exception:
                        continue

            while time.time() < deadline:
                if captured["sid"]:
                    print("Session id captured — closing browser and exporting API data…\n", flush=True)
                    break
                now = time.time()
                if now - last_dom >= 2.0:
                    try_syno_session_from_frames()
                    last_dom = now
                if now - last_ping > 25:
                    left = max(0, int(deadline - time.time()))
                    print(
                        f"Waiting for DSM session… ({left}s left) Log in, then open **Control Panel**, "
                        f"**File Station**, or **Package Center** (iframes + webapi traffic).",
                        flush=True,
                    )
                    last_ping = now
                time.sleep(0.4)
        finally:
            browser.close()

    if not captured["sid"]:
        print(
            "Timed out without seeing a session id. After logging in, click around DSM for ~30s, "
            "or set DSM_SID / DSM_SYNO_TOKEN from DevTools (Network → any entry.cgi → Query String → _sid).\n"
            "If the browser never appeared: set DSM_PLAYWRIGHT_CHANNEL=chrome (if Chrome is installed) "
            "or run  playwright install chromium",
            file=sys.stderr,
        )
        sys.exit(1)
    return captured["sid"], captured["token"]


def entry_request(
    session: requests.Session,
    base: str,
    sid: str,
    api: str,
    version: int,
    method: str,
    extra: dict[str, Any] | None,
    verify_ssl: bool,
    synotoken: str | None,
) -> dict[str, Any]:
    params: dict[str, Any] = {
        "api": api,
        "version": version,
        "method": method,
        "_sid": sid,
    }
    if synotoken:
        params["_syno_token"] = synotoken
    if extra:
        params.update(extra)
    r = session.get(
        api_url(base, "/webapi/entry.cgi"),
        params=params,
        verify=verify_ssl,
        timeout=120,
    )
    r.raise_for_status()
    return r.json()


def query_info_all(
    session: requests.Session,
    base: str,
    sid: str,
    synotoken: str | None,
    verify_ssl: bool,
) -> dict[str, Any]:
    qparams: dict[str, Any] = {
        "api": "SYNO.API.Info",
        "version": "1",
        "method": "query",
        "query": "all",
        "_sid": sid,
    }
    if synotoken:
        qparams["_syno_token"] = synotoken
    r = session.get(
        api_url(base, "/webapi/query.cgi"),
        params=qparams,
        verify=verify_ssl,
        timeout=180,
    )
    r.raise_for_status()
    return r.json()


def probe_catalog(
    session: requests.Session,
    base: str,
    sid: str,
    synotoken: str | None,
    verify_ssl: bool,
    info_payload: dict[str, Any],
    max_calls: int,
) -> list[tuple[str, dict[str, Any]]]:
    """Try read-like methods for each API key in SYNO.API.Info response."""
    out: list[tuple[str, dict[str, Any]]] = []
    data = info_payload.get("data")
    if not isinstance(data, dict):
        return out

    skip_apis = frozenset({"SYNO.API.Auth", "SYNO.API.OTP", "SYNO.API.Info"})
    calls = 0
    for api_name, meta in sorted(data.items()):
        if calls >= max_calls:
            break
        if not isinstance(meta, dict) or not api_name.startswith("SYNO."):
            continue
        if api_name in skip_apis:
            continue
        path = meta.get("path", "entry.cgi")
        if path != "entry.cgi":
            continue
        try:
            max_ver = int(meta.get("maxVersion", 1))
        except (TypeError, ValueError):
            max_ver = 1
        ver = max(1, max_ver)
        for method in PROBE_METHODS:
            if calls >= max_calls:
                break
            label = f"probe:{api_name}.{method}@{ver}"
            try:
                j = entry_request(session, base, sid, api_name, ver, method, None, verify_ssl, synotoken)
                calls += 1
                if j.get("success") is True:
                    out.append((label, j))
            except Exception as e:
                calls += 1
                out.append((label, {"error": str(e)}))
    return out


def safe_json(data: Any) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False, sort_keys=True)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export Synology DSM settings (read-only).")
    p.add_argument(
        "--browser",
        action="store_true",
        help="Open a real browser via Playwright (Edge on Windows by default); you log in; session is captured.",
    )
    p.add_argument("--sid", help="Use existing session id (skip password / browser).")
    p.add_argument("--syno-token", dest="syno_token", help="Optional DSM_SYNO_TOKEN / CSRF token.")
    p.add_argument(
        "--no-probe-catalog",
        dest="probe_catalog",
        action="store_false",
        help="Skip catalog probing (faster; only static endpoints + API info).",
    )
    p.set_defaults(probe_catalog=True)
    p.add_argument("--max-probe-calls", type=int, default=400, help="Cap catalog probe attempts.")
    p.add_argument("--wait-browser", type=int, default=600, help="Seconds to wait for browser session capture.")
    p.add_argument(
        "--browser-channel",
        default=None,
        metavar="CHANNEL",
        help="Browser for --browser: msedge (default on Windows), chrome, or chromium (Playwright-bundled). "
        "Overrides DSM_PLAYWRIGHT_CHANNEL.",
    )
    return p.parse_args()


def main() -> None:
    load_dotenv()
    args = parse_args()
    base = (env("DSM_URL") or "https://pnas.local:5001").rstrip("/")
    verify_ssl = (env("DSM_VERIFY_SSL") or "").lower() in ("1", "true", "yes")

    session = requests.Session()
    sid: str | None = args.sid or env("DSM_SID")
    synotoken: str | None = args.syno_token or env("DSM_SYNO_TOKEN")

    if args.browser:
        sid, synotoken = browser_capture_sid(base, args.wait_browser, args.browser_channel)
    elif not sid:
        account = env("DSM_USER")
        password = env("DSM_PASS")
        if not account or not password:
            print(
                "No session. Use --browser, or set DSM_SID (and optional DSM_SYNO_TOKEN), "
                "or DSM_USER + DSM_PASS in .env.",
                file=sys.stderr,
            )
            sys.exit(1)
        sid, synotoken = dsm_login(session, base, account, password, verify_ssl)

    assert sid is not None
    sections: list[tuple[str, dict[str, Any]]] = []

    try:
        info_json = query_info_all(session, base, sid, synotoken, verify_ssl)
        sections.append(("SYNO.API.Info (query=all)", info_json))
    except Exception as e:
        sections.append(("SYNO.API.Info (query=all)", {"error": str(e)}))

    for api, ver, method, extra in STATIC_ENDPOINTS:
        label = f"{api}.{method}"
        try:
            j = entry_request(session, base, sid, api, ver, method, extra, verify_ssl, synotoken)
            sections.append((label, j))
        except Exception as e:
            sections.append((label, {"error": str(e), "note": "may be absent on this model/DSM"}))

    if args.probe_catalog:
        info_blob = next((p for n, p in sections if n.startswith("SYNO.API.Info")), {})
        if isinstance(info_blob, dict) and info_blob.get("success") is True:
            probed = probe_catalog(
                session,
                base,
                sid,
                synotoken,
                verify_ssl,
                info_blob,
                max_calls=args.max_probe_calls,
            )
            sections.extend(probed)

    out_dir = Path(__file__).resolve().parent / "out"
    out_dir.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    json_path = out_dir / f"dsm-full-{stamp}.json"
    md_path = out_dir / f"dsm-full-{stamp}.md"

    bundle = {
        "generated_utc": stamp,
        "dsm_url": base,
        "section_count": len(sections),
        "sections": [{"title": t, "data": p} for t, p in sections],
    }
    json_path.write_text(safe_json(bundle), encoding="utf-8")

    md_lines = [
        "# Synology DSM export (automated)",
        "",
        f"- **Generated (UTC):** {stamp}",
        f"- **DSM URL:** `{base}`",
        f"- **Sections:** {len(sections)} (API info + static list + successful catalog probes)",
        "",
        f"Full machine-readable export: `{json_path.name}`",
        "",
        "Markdown shows the first chunks only (truncated). Use the JSON for the complete payload.",
        "",
    ]
    max_full_sections = 30
    for idx, (title, payload) in enumerate(sections):
        if idx >= max_full_sections:
            md_lines.append(f"_…and {len(sections) - max_full_sections} more sections; see `{json_path.name}`._")
            break
        md_lines.append(f"## {title}")
        md_lines.append("")
        text = safe_json(payload)
        if len(text) > 12000:
            text = text[:12000] + "\n... [truncated — see JSON file] ..."
        md_lines.append("```json")
        md_lines.append(text)
        md_lines.append("```")
        md_lines.append("")

    md_path.write_text("\n".join(md_lines), encoding="utf-8")
    print(f"Wrote:\n  {json_path}\n  {md_path}")


if __name__ == "__main__":
    main()
