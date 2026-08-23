"""
installer.py — Homelab Windows All-in-One Installer
────────────────────────────────────────────────────
Packages as a standalone .exe via PyInstaller (see build.ps1).
Run as Administrator — installs everything automatically:
  Chocolatey → Git → Terraform → Hyper-V → WinRM → Debian ISO →
  Clone repo → GitHub Actions runner → print secrets checklist

Requirements: pip install rich
"""

import argparse
import ctypes
import getpass
import os
import subprocess
import sys
import tempfile
from pathlib import Path

if sys.platform != "win32":
    print("ERROR: This installer is Windows-only.")
    sys.exit(1)

import winreg  # noqa: E402 — Windows-only, confirmed above

# ── Dependency guard ──────────────────────────────────────────────────────────
try:
    from rich.console import Console  # type: ignore[import]
    from rich.panel import Panel  # type: ignore[import]
    from rich.progress import Progress, SpinnerColumn, TextColumn  # type: ignore[import]
    from rich.table import Table  # type: ignore[import]
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "rich", "--quiet"])
    from rich.console import Console  # type: ignore[import]
    from rich.panel import Panel  # type: ignore[import]
    from rich.progress import Progress, SpinnerColumn, TextColumn  # type: ignore[import]
    from rich.table import Table  # type: ignore[import]

console = Console()

REPO_DEFAULT  = "https://github.com/homelab-admin/homelab"
INSTALL_DIR   = Path("C:/Homelab")
RUNNER_DIR    = Path("C:/actions-runner")
ISO_DIR       = Path("C:/ISOs")
TERRAFORM_VER = "1.9.8"

# ─────────────────────────────────────────────────────────────────────────────
def sanitize_ps1(script: Path) -> Path:
    """Return a temp copy of a PowerShell script with lone CR bytes removed.

    Git on Windows or certain editors can embed stray \\r bytes (not part of
    \\r\\n) inside string literals, causing PowerShell to report
    'The string is missing the terminator'.  We strip them entirely.
    """
    import re
    raw = script.read_bytes()
    # Step 1: normalise \r\n -> \n (windows line endings)
    raw = raw.replace(b"\r\n", b"\n")
    # Step 2: remove any remaining lone \r (stray carriage returns inside strings)
    clean = re.sub(rb"\r", b"", raw)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f"{script.stem}.sanitized.",
        suffix=".ps1",
        dir=str(script.parent),
    )
    os.close(fd)
    tmp = Path(tmp_name)
    # PowerShell 5.1 handles UTF-8 scripts most reliably when they include a BOM.
    tmp.write_bytes(b"\xef\xbb\xbf" + clean)
    return tmp


def _setup_script(repo_dir: Path, name: str) -> Path:
    """Return the best available copy of a setup script.

    Prefers the local development copy (same repo as this installer) so that
    fixes committed locally take effect immediately without requiring a push/pull.
    Falls back to the cloned copy at repo_dir.
    """
    local = Path(__file__).parent.parent / "setup" / name
    cloned = repo_dir / "setup" / name
    return local if local.exists() else cloned


def _setup_artifact_dir(repo_dir: Path, name: str) -> Path:
    """Return the directory used by the selected setup script."""
    return _setup_script(repo_dir, name).parent

# ─────────────────────────────────────────────────────────────────────────────
def banner():
    console.print(Panel.fit(
        "[cyan bold]  Homelab Windows Installer[/cyan bold]\n"
        "[dim]  Hyper-V + Terraform + GitHub Actions + Docker[/dim]\n"
        "[dim]  github.com/homelab-admin/homelab[/dim]",
        border_style="cyan"
    ))

# ─────────────────────────────────────────────────────────────────────────────
def require_admin():
    if not ctypes.windll.shell32.IsUserAnAdmin():  # type: ignore[attr-defined]
        console.print("[red bold]✗  Must be run as Administrator.[/red bold]")
        console.print("  Right-click → 'Run as administrator'")
        sys.exit(1)
    console.print("[green]✓  Running as Administrator[/green]")

# ─────────────────────────────────────────────────────────────────────────────
def run(
    cmd: str,
    desc: str,
    shell: bool = True,
    check: bool = True,
    workdir: str | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
    """Run a shell command with a spinner."""
    with Progress(SpinnerColumn(), TextColumn(f"  {desc}..."), transient=True) as p:
        p.add_task("", total=None)
        result = subprocess.run(
            cmd,
            shell=shell,
            capture_output=True,
            text=True,
            cwd=workdir,
            env=env,
        )
    if check and result.returncode != 0:
        console.print(f"[red]✗  FAILED: {desc}[/red]")
        console.print(f"  [dim]{result.stderr.strip()[:300]}[/dim]")  # type: ignore[index]
        raise SystemExit(1)
    return result

# ─────────────────────────────────────────────────────────────────────────────
def _refresh_path():
    """Reload system PATH from the registry into the current process."""
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,  # type: ignore[attr-defined]
                             r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")
        sys_path, _ = winreg.QueryValueEx(key, "PATH")  # type: ignore[attr-defined]
        os.environ["PATH"] = sys_path + ";" + os.environ.get("PATH", "")
    except Exception:
        pass  # best-effort; non-fatal


def install_chocolatey():
    console.rule("[cyan]Step 1 — Chocolatey Package Manager[/cyan]")
    result = subprocess.run("choco --version", shell=True, capture_output=True)
    if result.returncode == 0:
        console.print("[green]✓  Chocolatey already installed[/green]")
        return
    run(
        'powershell -NoProfile -ExecutionPolicy Bypass -Command '
        '"Set-ExecutionPolicy Bypass -Scope Process -Force; '
        '[Net.ServicePointManager]::SecurityProtocol = 3072; '
        'iex ((New-Object Net.WebClient).DownloadString(\'https://community.chocolatey.org/install.ps1\'))"',
        "Installing Chocolatey"
    )
    # Chocolatey installs to a fixed path — add it now so the next step can use it
    choco_bin = r"C:\ProgramData\chocolatey\bin"
    if choco_bin not in os.environ.get("PATH", ""):
        os.environ["PATH"] = choco_bin + ";" + os.environ.get("PATH", "")
    console.print("[green]✓  Chocolatey installed[/green]")

# ─────────────────────────────────────────────────────────────────────────────
def install_prerequisites():
    console.rule("[cyan]Step 2 — Git + Terraform[/cyan]")

    # Reload system PATH first so freshly-installed choco is visible
    _refresh_path()

    packages = {"git": "git --version", "terraform": "terraform version"}
    for pkg, check_cmd in packages.items():
        r = subprocess.run(check_cmd, shell=True, capture_output=True)
        if r.returncode == 0:
            console.print(f"[green]✓  {pkg} already installed[/green]")
        else:
            run(f"choco install {pkg} -y --no-progress", f"Installing {pkg}")
            console.print(f"[green]✓  {pkg} installed[/green]")

    # Reload PATH again so git/terraform binaries are usable immediately
    _refresh_path()

# ─────────────────────────────────────────────────────────────────────────────
def enable_hyperv_winrm(repo_dir: Path) -> bool:
    console.rule("[cyan]Step 3 — Hyper-V + WinRM HTTPS[/cyan]")
    src = _setup_script(repo_dir, "01_enable_hyperv_winrm.ps1")
    cert_path = _setup_artifact_dir(repo_dir, "01_enable_hyperv_winrm.ps1") / "winrm_cacert.pem"
    script = sanitize_ps1(src)
    console.print(f"  Running: {src}")
    result = subprocess.run(
        f'powershell -NoProfile -ExecutionPolicy Bypass -File "{script}"',
        shell=True
    )
    if result.returncode != 0:
        console.print("[yellow]⚠  WinRM setup returned non-zero — a reboot may be required[/yellow]")
        return False
    if not cert_path.exists():
        console.print("[yellow]⚠  Hyper-V was enabled but WinRM is not ready yet. Reboot and rerun the installer.[/yellow]")
        return False
    console.print("[green]✓  Hyper-V + WinRM HTTPS configured[/green]")
    return True

# ─────────────────────────────────────────────────────────────────────────────
def download_debian_iso(repo_dir: Path):
    console.rule("[cyan]Step 4 — Debian 13 ISO[/cyan]")
    iso = ISO_DIR / "debian-13-amd64-netinst.iso"
    if iso.exists() and iso.stat().st_size > 100_000_000:
        console.print(f"[green]✓  ISO already present: {iso}[/green]")
        return
    src = _setup_script(repo_dir, "02_download_debian_iso.ps1")
    script = sanitize_ps1(src)
    result = subprocess.run(
        f'powershell -NoProfile -ExecutionPolicy Bypass -File "{script}" -Force',
        shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        console.print("[red]✗  ISO download failed[/red]")
        console.print(f"  [dim]{result.stderr.strip()[:300]}[/dim]")  # type: ignore[index]
        raise SystemExit(1)
    console.print(f"[green]✓  Debian 13 ISO ready at {iso}[/green]")

# ─────────────────────────────────────────────────────────────────────────────
def clone_repo(args: argparse.Namespace) -> Path:
    console.rule("[cyan]Step 5 — Clone Repository[/cyan]")
    repo_url = args.repo_url or REPO_DEFAULT
    console.print(f"  Using repo: [cyan]{repo_url}[/cyan]")
    if INSTALL_DIR.exists() and (INSTALL_DIR / ".git").exists():
        console.print(f"[yellow]⚠  Repo already exists at {INSTALL_DIR} — pulling[/yellow]")
        run(f'git -C "{INSTALL_DIR}" pull', "Pulling latest")
    else:
        run(f'git clone "{repo_url}" "{INSTALL_DIR}"', f"Cloning to {INSTALL_DIR}")

    # Detect actual project root — the repo may be a monorepo with the
    # hyperv-debian-terraform project living in a subdirectory.
    marker = Path("setup") / "01_enable_hyperv_winrm.ps1"
    if (INSTALL_DIR / marker).exists():
        repo_dir = INSTALL_DIR
    else:
        # Search one level deep for the marker
        found = [p.parent.parent for p in INSTALL_DIR.rglob(str(marker)) if p.exists()]
        if found:
            repo_dir = found[0]
            console.print(f"[dim]  Project root detected at: {repo_dir}[/dim]")
        else:
            console.print("[yellow]⚠  Could not find setup scripts — using clone root[/yellow]")
            repo_dir = INSTALL_DIR

    console.print(f"[green]✓  Repo ready at {repo_dir}[/green]")
    return repo_dir

# ─────────────────────────────────────────────────────────────────────────────
def install_runner(repo_url: str, repo_dir: Path, args: argparse.Namespace):
    console.rule("[cyan]Step 6 — GitHub Actions Self-Hosted Runner[/cyan]")
    token = args.runner_token or os.environ.get("GITHUB_RUNNER_TOKEN") or os.environ.get("HOMELAB_RUNNER_TOKEN")
    if not token:
        console.print("[yellow]⚠  No runner token provided; skipping runner installation.[/yellow]")
        console.print("  Set --runner-token or GITHUB_RUNNER_TOKEN to auto-install it.")
        console.print(f"  Register manually: {repo_url}/settings/actions/runners/new")
        return
    script = repo_dir / "setup" / "03_install_github_runner.ps1"
    result = subprocess.run(
        f'powershell -NoProfile -ExecutionPolicy Bypass -File "{script}" '
        f'-RepoUrl "{repo_url}" -Token "{token}"',
        shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        console.print("[red]✗  Runner installation failed[/red]")
        console.print(f"  [dim]{result.stderr.strip()[:300]}[/dim]")  # type: ignore[index]
        raise SystemExit(1)
    console.print("[green]✓  Runner installed as Windows service[/green]")


def _resolve_winrm_username(args: argparse.Namespace) -> str:
    return (
        args.winrm_username
        or os.environ.get("TF_VAR_winrm_username")
        or os.environ.get("WINRM_USERNAME")
        or getpass.getuser()
    )


def _resolve_winrm_password(args: argparse.Namespace) -> str | None:
    return (
        args.winrm_password
        or os.environ.get("TF_VAR_winrm_password")
        or os.environ.get("WINRM_PASSWORD")
    )


def apply_terraform(repo_dir: Path, args: argparse.Namespace) -> bool:
    console.rule("[cyan]Step 7 — Terraform Apply[/cyan]")
    terraform_dir = repo_dir / "terraform"
    if not terraform_dir.exists():
        console.print("[yellow]⚠  No terraform directory found; skipping VM provisioning.[/yellow]")
        return False

    winrm_username = _resolve_winrm_username(args)
    winrm_password = _resolve_winrm_password(args)
    if not winrm_password:
        console.print("[yellow]⚠  No WinRM password provided; skipping automatic VM provisioning.[/yellow]")
        console.print("  Set --winrm-password or TF_VAR_winrm_password for one-click bring-up.")
        return False

    cacert_path = _setup_artifact_dir(repo_dir, "01_enable_hyperv_winrm.ps1") / "winrm_cacert.pem"
    iso_path = ISO_DIR / "debian-13-amd64-netinst.iso"
    env = os.environ.copy()
    env["TF_VAR_winrm_username"] = winrm_username
    env["TF_VAR_winrm_password"] = winrm_password
    env["TF_VAR_winrm_cacert_path"] = str(cacert_path)
    env["TF_VAR_iso_path"] = str(iso_path)

    run("terraform init -input=false", "Initializing Terraform", workdir=str(terraform_dir), env=env)
    run(
        "terraform apply -auto-approve -input=false",
        "Applying Terraform to create the VM",
        workdir=str(terraform_dir),
        env=env,
    )

    output = run(
        "terraform output",
        "Reading Terraform outputs",
        check=False,
        workdir=str(terraform_dir),
        env=env,
    )
    if output.stdout.strip():
        console.print(output.stdout.strip())
    console.print("[green]✓  Terraform apply completed[/green]")
    return True

# ─────────────────────────────────────────────────────────────────────────────
def print_secrets_checklist(repo_url: str):
    console.rule("[cyan]Step 8 — GitHub Secrets Checklist[/cyan]")
    console.print(f"\n  Add these at: [yellow]{repo_url}/settings/secrets/actions[/yellow]\n")

    table = Table(show_header=True, header_style="bold cyan", show_lines=True)
    table.add_column("Secret Name", style="bold white")
    table.add_column("Value / How to get it")
    table.add_column("Done?")

    secrets = [
        ("WINRM_USERNAME",       "Your Windows username",                              "[ ]"),
        ("WINRM_PASSWORD",       "Your Windows password",                              "[ ]"),
        ("WINRM_CACERT_B64",     "Base64 printed by 01_enable_hyperv_winrm.ps1",       "[ ]"),
        ("DEBIAN_SSH_PRIVATE_KEY","ssh-keygen -t ed25519 → copy private key contents", "[ ]"),
        ("DEBIAN_VM_USER",       "debian",                                              "[ ]"),
        ("DEBIAN_VM_IP",         "VM IP (after Terraform + Debian install)",            "[ ]"),
        ("SOPS_AGE_KEY",         "age-keygen → copy keys.txt content",                 "[ ]"),
        ("WIKIJS_WEBHOOK_TOKEN", "Wiki.js Admin → Storage → Git → Webhook token",      "[ ]"),
    ]
    for name, value, done in secrets:
        table.add_row(name, value, done)
    console.print(table)

# ─────────────────────────────────────────────────────────────────────────────
def print_summary(repo_url: str, vm_created: bool):
    next_steps = (
        "[white]VM provisioned automatically:[/white]\n\n"
        "[cyan]1.[/cyan] Open Hyper-V Manager and complete the Debian installer if first boot is waiting for input\n"
        "[cyan]2.[/cyan] After Debian is reachable, continue with Ansible Bootstrap VM and Docker Deploy\n"
        "[cyan]3.[/cyan] If you use GitHub Actions, add the remaining repo secrets as needed\n\n"
    ) if vm_created else (
        "[white]Next steps:[/white]\n\n"
        "[cyan]1.[/cyan] Finish adding GitHub Secrets (list above)\n"
        "[cyan]2.[/cyan] Provide WinRM credentials to the installer for automatic Terraform apply\n"
        "[cyan]3.[/cyan] Re-run the installer or run Terraform Apply to create the Debian VM\n"
        "[cyan]4.[/cyan] Open Hyper-V Manager → install Debian (check SSH server)\n"
        "[cyan]5.[/cyan] Continue with Ansible Bootstrap VM and Docker Deploy\n\n"
    )
    console.print(Panel(
        "[green bold]  ✅  Bootstrap Complete![/green bold]\n\n"
        f"{next_steps}"
        f"[dim]Runner: {repo_url}/settings/actions/runners[/dim]",
        border_style="green",
        title="[green bold]Done![/green bold]"
    ))

# ─────────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Homelab Windows Installer")
    parser.add_argument("--yes", "-y", action="store_true", default=True,
                        help="Retained for compatibility; installer is non-interactive by default")
    parser.add_argument("--repo-url", metavar="URL",
                        default=os.environ.get("HOMELAB_REPO_URL"),
                        help="GitHub repo URL to clone")
    parser.add_argument("--runner-token", metavar="TOKEN",
                        help="GitHub Actions runner registration token")
    parser.add_argument("--winrm-username", metavar="USERNAME",
                        help="WinRM username for Terraform apply; defaults to current user")
    parser.add_argument("--winrm-password", metavar="PASSWORD",
                        help="WinRM password for Terraform apply")
    args = parser.parse_args()

    banner()
    require_admin()

    console.print()
    console.print("[bold]This installer will:[/bold]")
    for step in [
        "Install Chocolatey, Git, and Terraform",
        "Enable Hyper-V and configure WinRM HTTPS",
        "Download Debian 13 ISO (~700 MB)",
        "Clone your homelab repo to C:\\Homelab",
        "Register a self-hosted GitHub Actions runner",
        "Print the GitHub Secrets checklist",
    ]:
        console.print(f"  [cyan]•[/cyan] {step}")


    install_chocolatey()
    install_prerequisites()
    repo_dir = clone_repo(args)
    # Derive repo URL from the cloned git remote
    r = subprocess.run('git -C "' + str(repo_dir) + '" remote get-url origin',
                       shell=True, capture_output=True, text=True)
    repo_url = r.stdout.strip() if r.returncode == 0 else (args.repo_url or REPO_DEFAULT)

    winrm_ready = enable_hyperv_winrm(repo_dir)
    download_debian_iso(repo_dir)
    install_runner(repo_url, repo_dir, args)
    vm_created = apply_terraform(repo_dir, args) if winrm_ready else False
    print_secrets_checklist(repo_url)
    print_summary(repo_url, vm_created)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n\n[yellow]  Cancelled.[/yellow]")
        sys.exit(0)
