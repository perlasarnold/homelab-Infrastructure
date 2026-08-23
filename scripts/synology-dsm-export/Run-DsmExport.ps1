#Requires -Version 5.1
<#
.SYNOPSIS
  Install dependencies and run a full DSM export with browser (Chromium) login.

.DESCRIPTION
  Opens Playwright Chromium to DSM_URL — log in (2FA OK). Session is captured from API
  traffic; then static + catalog exports are written to .\out\

  Requires Python 3.10+ (not the Windows Store stub):
  https://www.python.org/downloads/  or  winget install Python.Python.3.12
#>
param(
    [string]$DsmUrl = "https://pnas.local:5001"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

function Test-PythonOk {
    param([string]$Py)
    try {
        $out = & $Py -c "import sys; print(sys.version_info[:2] >= (3, 10))" 2>$null
        return ($out -as [string]).Trim() -eq "True"
    } catch {
        return $false
    }
}

$python = $null
$preferred = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
if ((Test-Path $preferred) -and (Test-PythonOk $preferred)) {
    $python = $preferred
}
if (-not $python) {
    foreach ($name in @("python3", "python")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -and (Test-PythonOk $cmd.Source)) {
            $python = $cmd.Source
            break
        }
    }
}

if (-not $python) {
    Write-Host "Python 3.10+ not found in PATH." -ForegroundColor Yellow
    Write-Host "Install from https://www.python.org/downloads/ or: winget install Python.Python.3.12" -ForegroundColor Cyan
    exit 1
}

Write-Host "Using: $python"
& $python -m pip install -r "$here\requirements-browser.txt"
& $python -m playwright install chromium

$env:DSM_URL = $DsmUrl
# Prefer system Edge on Windows so a window reliably appears (bundled Chromium can be blocked or invisible).
if ($env:OS -like "*Windows*") {
    $env:DSM_PLAYWRIGHT_CHANNEL = "msedge"
}
Write-Host "`nA browser window (Edge on Windows) should open — check the taskbar if you don't see it.`nLog in to DSM at $DsmUrl`n" -ForegroundColor Green
& $python "$here\dump_dsm_settings.py" --browser
