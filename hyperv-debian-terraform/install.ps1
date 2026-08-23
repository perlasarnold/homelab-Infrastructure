#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Homelab Bootstrap — Windows Hyper-V Edition
    One-liner: irm https://raw.githubusercontent.com/YOUR_USER/hyperv-debian-terraform/main/install.ps1 | iex
.DESCRIPTION
    1. Installs prerequisites (Git, Terraform, Chocolatey if needed)
    2. Enables Hyper-V + configures WinRM HTTPS
    3. Downloads Debian 12 ISO
    4. Clones this repo to C:\Homelab
    5. Registers a self-hosted GitHub Actions runner as a Windows service
    After that: push to GitHub → everything runs remotely, no RDP needed.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"  # Faster downloads

# ── Colours ───────────────────────────────────────────────────────────────────
function Write-Banner {
    $c = [char]27
    Write-Host ""
    Write-Host "  ${c}[96m${c}[1m" -NoNewline
    Write-Host "  ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ "
    Write-Host "  ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗"
    Write-Host "  ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝"
    Write-Host "  ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗"
    Write-Host "  ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝"
    Write-Host "  ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ "
    Write-Host "${c}[0m"
    Write-Host "  Homelab Bootstrap — Windows Hyper-V + GitHub Actions + Terraform"
    Write-Host ""
}

function Step($msg)  { Write-Host "`n  $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Ask($prompt) {
    Write-Host -NoNewline "  $prompt " -ForegroundColor White
    return Read-Host
}

# ── Install Chocolatey (package manager) ──────────────────────────────────────
function Install-Choco {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Step "Installing Chocolatey package manager..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Ok "Chocolatey installed"
    } else {
        Ok "Chocolatey already present"
    }
}

# ── Install prerequisites ──────────────────────────────────────────────────────
function Install-Prereqs {
    Step "Installing prerequisites (Git, Terraform)..."

    Install-Choco

    $packages = @{
        "git"       = "git"
        "terraform" = "terraform"
    }
    foreach ($name in $packages.Keys) {
        if (-not (Get-Command $packages[$name] -ErrorAction SilentlyContinue)) {
            choco install $name -y --no-progress | Out-Null
            Ok "$name installed"
        } else {
            Ok "$name already installed"
        }
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

# ── Enable Hyper-V + WinRM ────────────────────────────────────────────────────
function Setup-HyperV {
    Step "Enabling Hyper-V and configuring WinRM HTTPS..."
    $repoDir = $script:RepoDir
    & "$repoDir\setup\01_enable_hyperv_winrm.ps1"
}

# ── Download Debian ISO ────────────────────────────────────────────────────────
function Download-DebianISO {
    Step "Downloading Debian 12 ISO..."
    $repoDir = $script:RepoDir
    & "$repoDir\setup\02_download_debian_iso.ps1"
}

# ── Clone repo ─────────────────────────────────────────────────────────────────
function Clone-Repo {
    Step "Cloning homelab repo..."
    $script:RepoUrl = Ask "GitHub repo URL (e.g., https://github.com/YOU/hyperv-debian-terraform):"
    $script:RepoDir = "C:\Homelab"

    if (Test-Path "$($script:RepoDir)\.git") {
        Warn "Repo already exists — pulling latest."
        git -C $script:RepoDir pull
    } else {
        git clone $script:RepoUrl $script:RepoDir
    }
    Ok "Repo ready at $($script:RepoDir)"
}

# ── Register Actions runner ────────────────────────────────────────────────────
function Install-Runner {
    Step "Installing self-hosted GitHub Actions runner..."
    Write-Host ""
    Write-Host "  Get token from: $($script:RepoUrl)/settings/actions/runners/new" -ForegroundColor Yellow
    Write-Host ""
    $token = Ask "Runner registration token:"
    & "$($script:RepoDir)\setup\03_install_github_runner.ps1" `
        -RepoUrl $script:RepoUrl `
        -Token   $token
}

# ── Print summary ──────────────────────────────────────────────────────────────
function Print-Summary {
    Write-Host ""
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "    ✅  Bootstrap complete!" -ForegroundColor Green
    Write-Host "  ══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps (all from GitHub — no RDP needed):" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. Add GitHub Secrets → $($script:RepoUrl)/settings/secrets/actions"
    Write-Host "       WINRM_USERNAME, WINRM_PASSWORD, WINRM_CACERT_B64"
    Write-Host "       DEBIAN_SSH_PRIVATE_KEY, DEBIAN_VM_IP, DEBIAN_VM_USER"
    Write-Host ""
    Write-Host "  2. Push terraform/ changes → Terraform creates the Debian VM"
    Write-Host "  3. Trigger 'Ansible Bootstrap' → Docker installed"
    Write-Host "  4. Trigger 'Docker Deploy' → choose a service to deploy"
    Write-Host ""
    Write-Host "  Runner: $($script:RepoUrl)/settings/actions/runners" -ForegroundColor Yellow
    Write-Host ""
}

# ── Main ───────────────────────────────────────────────────────────────────────
Write-Banner
Clone-Repo
Install-Prereqs
Setup-HyperV
Download-DebianISO
Install-Runner
Print-Summary
