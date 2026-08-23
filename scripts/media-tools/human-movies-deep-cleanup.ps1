<#
.SYNOPSIS
    PNAS Human Movies - Deep File Standardization Script
.DESCRIPTION
    Iterates through all standardized "Title (Year)" directories in PNAS Human Movies:
    1. Locates the primary video file (.mkv, .mp4, .avi).
    2. Renames it to "Title (Year).ext" to match the folder.
    3. Safe-renames subtitles (.srt) to match the new convention.
    4. Deletes junk files (.txt, .url, banners, empty logs).
.PARAMETER WhatIf
    Dry-run mode (default is $true). Set to $false to execute live changes.
.NOTES
    Date:    2026-05-16
#>

param(
    [bool]$WhatIf = $true
)

$base = "\\PNAS\Seagate\Share\Movies\Human Movies"

if (-not (Test-Path -LiteralPath $base)) {
    Write-Error "Base path not found: $base"
    exit 1
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  PNAS Human Movies - Deep File Sanitization"
Write-Host "  Mode: $(if ($WhatIf) { 'DRY RUN (WhatIf)' } else { 'LIVE EXECUTION' })"
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host ""

$dirs = Get-ChildItem -LiteralPath $base -Directory
$renameCount = 0
$deleteCount = 0

# Common junk extensions and names to delete
$junkExtensions = @(".txt", ".url", ".url", ".htm", ".html", ".nfo")
$junkNames = @("Downloaded from", "TorrentGalaxy", "YTS", "sparrow", "RARBG", "PSA", "GalaxyRG", "advertisement", "join us", "subscribe")

foreach ($dir in $dirs) {
    # Only target standardized folders ending with (YYYY)
    if ($dir.Name -notmatch "\s\(\d{4}\)$") {
        continue
    }
    
    $folderName = $dir.Name
    $subFiles = Get-ChildItem -LiteralPath $dir.FullName -File
    
    # 1. Process and clean up junk files
    foreach ($file in $subFiles) {
        $shouldDelete = $false
        
        # Check by extension
        if ($file.Extension -in $junkExtensions) {
            $shouldDelete = $true
        }
        
        # Check by known junk keywords in name
        foreach ($keyword in $junkNames) {
            if ($file.Name -like "*$keyword*") {
                $shouldDelete = $true
                break
            }
        }
        
        # Safety Shield: Never delete video files under any circumstances!
        if ($file.Extension -in ".mkv", ".mp4", ".avi") {
            $shouldDelete = $false
        }
        
        if ($shouldDelete) {
            Write-Host "Proposed Delete: '$($dir.Name)\$($file.Name)'" -ForegroundColor Red
            if (-not $WhatIf) {
                try {
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                    $deleteCount++
                } catch {
                    Write-Error "   [ERROR] Failed to delete: $_"
                }
            } else {
                $deleteCount++
            }
        }
    }
    
    # Re-fetch files after potential deletes
    $subFiles = Get-ChildItem -LiteralPath $dir.FullName -File
    
    # 2. Locate and process primary video file
    $videoFiles = $subFiles | Where-Object { $_.Extension -in ".mkv", ".mp4", ".avi" }
    
    if ($videoFiles.Count -eq 1) {
        $video = $videoFiles[0]
        $newVideoName = "$folderName$($video.Extension)"
        $newVideoPath = Join-Path $dir.FullName $newVideoName
        
        if ($video.Name -ne $newVideoName) {
            Write-Host "Proposed File Rename: '$($dir.Name)\$($video.Name)'" -ForegroundColor Cyan
            Write-Host "                 ➡️ '$newVideoName'" -ForegroundColor Green
            
            if (-not $WhatIf) {
                try {
                    if (Test-Path -LiteralPath $newVideoPath) {
                        Write-Warning "   [CONFLICT] Target video file already exists: $newVideoName"
                    } else {
                        Rename-Item -LiteralPath $video.FullName -NewName $newVideoName -ErrorAction Stop
                        $renameCount++
                    }
                } catch {
                    Write-Error "   [ERROR] Failed to rename video: $_"
                }
            } else {
                $renameCount++
            }
        }
    } elseif ($videoFiles.Count -gt 1) {
        Write-Warning "[MULTI-VIDEO] Multiple video files in '$folderName'. Skipping auto-rename for safety."
    }
    
    # 3. Process subtitle files if any
    $srtFiles = $subFiles | Where-Object { $_.Extension -eq ".srt" }
    foreach ($srt in $srtFiles) {
        # Check if srt is already matching folderName
        if ($srt.Name -notlike "$folderName*") {
            # Try to preserve language code (e.g. .eng.srt or .ita.srt)
            $langCode = ""
            if ($srt.Name -match "\.([a-zA-Z]{3})\.srt$") {
                $langCode = ".$($Matches[1])"
            }
            
            $newSrtName = "$folderName$langCode.srt"
            $newSrtPath = Join-Path $dir.FullName $newSrtName
            
            if ($srt.Name -ne $newSrtName) {
                Write-Host "Proposed Subtitle Rename: '$($dir.Name)\$($srt.Name)'" -ForegroundColor Yellow
                Write-Host "                     ➡️ '$newSrtName'" -ForegroundColor Green
                
                if (-not $WhatIf) {
                    try {
                        if (-not (Test-Path -LiteralPath $newSrtPath)) {
                            Rename-Item -LiteralPath $srt.FullName -NewName $newSrtName -ErrorAction Stop
                        }
                    } catch {
                        Write-Error "   [ERROR] Failed to rename subtitle: $_"
                    }
                }
            }
        }
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  SUMMARY OF DEEP CLEANUP" -ForegroundColor White
Write-Host "  Total Video Files Renamed: $(if ($WhatIf) { "$renameCount (Preview)" } else { $renameCount })" -ForegroundColor Green
Write-Host "  Total Junk Files Deleted:  $(if ($WhatIf) { "$deleteCount (Preview)" } else { $deleteCount })" -ForegroundColor Red
Write-Host "======================================================" -ForegroundColor Magenta
