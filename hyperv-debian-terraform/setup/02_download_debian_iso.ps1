#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Step 2: Download Debian 13 (Trixie) amd64 netinstall ISO.
.PARAMETER Force
    Re-download the ISO even if it already exists.
.NOTES
    The ISO is saved to C:\ISOs\ which is the default path expected by terraform\main.tf.
    Verifies the SHA512 checksum after download.
#>
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$isoDir      = "C:\ISOs"
$isoFile     = "$isoDir\debian-13-amd64-netinst.iso"
$baseUrl     = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"
$checksumUrl = "$baseUrl/SHA512SUMS"

Write-Host "[1/3] Ensuring ISO directory exists: $isoDir" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $isoDir | Out-Null

if (Test-Path $isoFile) {
    if (-not $Force) {
        Write-Host "  ISO already exists at $isoFile - skipping download." -ForegroundColor Yellow
        exit 0
    }
    Remove-Item $isoFile -Force
}

Write-Host "[2/3] Resolving latest Debian stable netinst ISO..." -ForegroundColor Cyan
$wc = New-Object System.Net.WebClient

$checksumContent = $wc.DownloadString($checksumUrl)
$latestIsoName = ($checksumContent -split "`n" |
    Where-Object { $_ -match "debian-13\.[0-9]+\.[0-9]+-amd64-netinst\.iso$" } |
    ForEach-Object { ($_ -split "\s+")[-1].Trim() } |
    Select-Object -First 1)

if (-not $latestIsoName) {
    throw "Could not determine the latest Debian stable netinst ISO from $checksumUrl"
}

$isoUrl = "$baseUrl/$latestIsoName"
Write-Host "  Latest ISO: $latestIsoName" -ForegroundColor Green
Write-Host "  URL: $isoUrl"
$wc.DownloadFile($isoUrl, $isoFile)
Write-Host "  Download complete: $isoFile" -ForegroundColor Green

Write-Host "[3/3] Verifying SHA512 checksum..." -ForegroundColor Cyan
$checksumFile = "$env:TEMP\debian_SHA512SUMS"
$wc.DownloadFile($checksumUrl, $checksumFile)

$expectedLine = (Get-Content $checksumFile) | Where-Object { $_ -match [regex]::Escape($latestIsoName) + "$" } | Select-Object -First 1
if (-not $expectedLine) {
    Write-Warning "Could not find checksum in SUMS file - skipping verification."
} else {
    $expectedHash = ($expectedLine -split "\s+")[0].ToUpper()
    $actualHash   = (Get-FileHash -Path $isoFile -Algorithm SHA512).Hash.ToUpper()

    if ($actualHash -eq $expectedHash) {
        Write-Host "  Checksum verified OK." -ForegroundColor Green
    } else {
        Write-Host "  Checksum mismatch. Delete $isoFile and retry." -ForegroundColor Red
        Remove-Item $isoFile -Force
        exit 1
    }
}

Write-Host "`nDebian 13 (Trixie) ISO ready at: $isoFile" -ForegroundColor Green
Write-Host "   Update terraform\terraform.tfvars if you chose a different path." -ForegroundColor Gray
