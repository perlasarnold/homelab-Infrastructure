<#
.SYNOPSIS
    Self-Healing Movie Restore Script
.DESCRIPTION
    Compares the TrueNAS backup share against PNAS. If a movie video file is missing
    on PNAS, it copies it back from TrueNAS directly into its clean, standardized path.
.NOTES
    Date:    2026-05-16
#>

$trueNasBase = "\\truenas\seagate\Share\Movies\Human Movies"
$pnasBase = "\\PNAS\Seagate\Share\Movies\Human Movies"

Write-Host "Starting Self-Healing Restore..." -ForegroundColor Cyan
Write-Host "Source Backup: $trueNasBase"
Write-Host "Target (PNAS): $pnasBase"
Write-Host ""

# Helper to clean titles
function Get-CleanName {
    param([string]$name)
    $clean = $name -replace "\.(mkv|mp4|avi|srt)$", ""
    $years = [regex]::Matches($clean, "(?:\b|\.|_)(18\d\d|19\d\d|20[0-2]\d|2030)\b")
    if ($years.Count -eq 0) { return $null }
    
    $extractedYears = @()
    foreach ($m in $years) {
        $extractedYears += $m.Groups[1].Value
    }
    $uniqueYears = $extractedYears | Select-Object -Unique
    if ($uniqueYears.Count -gt 1) { return $null }
    
    $year = @($uniqueYears)[0]
    $titlePart = $clean -split "(?:\b|\.|_)$year\b"
    if ($titlePart.Count -eq 0) { return $null }
    $title = $titlePart[0]
    $title = $title -replace "[\._\-]", " "
    $title = $title -replace "\s*[\(\[\{\-\+]\s*$", ""
    $title = $title -replace "^\s*[\(\[\{\-\+]\s*", ""
    $title = $title.Trim() -replace "\s+", " "
    
    return "$title ($year)"
}

# Scan all directories on TrueNAS
$trueNasDirs = Get-ChildItem -LiteralPath $trueNasBase -Directory
$restoredCount = 0

foreach ($tnDir in $trueNasDirs) {
    # Find any video file inside this TrueNAS directory
    $tnVideos = Get-ChildItem -LiteralPath $tnDir.FullName -File | Where-Object { $_.Extension -in ".mkv", ".mp4", ".avi" }
    
    foreach ($video in $tnVideos) {
        # Determine the clean standardized folder and file name
        # First, try to clean the parent folder name. If it fails, clean the video name.
        $cleanFolderName = Get-CleanName -name $tnDir.Name
        if (-not $cleanFolderName) {
            $cleanFolderName = Get-CleanName -name $video.Name
        }
        
        if (-not $cleanFolderName) {
            Write-Warning "Could not parse standard name for: $($tnDir.Name) \ $($video.Name)"
            continue
        }
        
        # Define clean target path on PNAS
        $targetFolder = Join-Path $pnasBase $cleanFolderName
        $targetFile = Join-Path $targetFolder "$cleanFolderName$($video.Extension)"
        
        # Check if the video file exists on PNAS
        if (-not (Test-Path -LiteralPath $targetFile)) {
            Write-Host "Missing on PNAS: '$cleanFolderName\$cleanFolderName$($video.Extension)'" -ForegroundColor Yellow
            Write-Host "  ➡️ Copying from TrueNAS backup..." -ForegroundColor Green
            
            try {
                if (-not (Test-Path -LiteralPath $targetFolder)) {
                    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
                }
                
                # Copy the file live
                Copy-Item -LiteralPath $video.FullName -Destination $targetFile -Force -ErrorAction Stop
                $restoredCount++
                Write-Host "  ✅ Restored successfully!" -ForegroundColor Green
            } catch {
                Write-Error "  ❌ Failed to copy: $_"
            }
        }
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  RESTORE SUMMARY" -ForegroundColor White
Write-Host "  Total Movie Files Restored: $restoredCount" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Magenta
