<#
.SYNOPSIS
    TV Show Migration and Restructuring Engine
.DESCRIPTION
    Restructures and copies TV shows from PNAS to TrueNAS:
    1. Audits both paths to only process shows that don't exist in the destination.
    2. Renames show folders to standardized clean Plex titles.
    3. Recursively scans video files and maps them to "Season XX" folders.
    4. Renames episode files to perfect "Show Title - SXXEXX.ext" metadata format.
    5. Copies subtitles (.srt/.sub) and matches them accordingly.
    6. Safely filters out junk files (.txt torrent links, thumbs, images).
.PARAMETER WhatIf
    Dry-run mode (default is $true). Set to $false to execute live changes.
#>

param(
    [bool]$WhatIf = $true
)

$sourceBase = "\\PNAS\PlexMediaStorage\Plex\TV Shows"
$destBase = "\\truenas\seagate\Share\TV Shows"

if (-not (Test-Path -LiteralPath $sourceBase)) {
    Write-Error "Source base path not found: $sourceBase"
    exit 1
}
if (-not (Test-Path -LiteralPath $destBase)) {
    Write-Error "Destination base path not found: $destBase"
    exit 1
}

# Advanced helper to clean show name
function Get-CleanShowName {
    param([string]$name)
    # Strip common release tags, season tags, and trailing bracketed junk
    $clean = $name
    $clean = $clean -replace "\.(S\d+|Season\s*\d+|COMPLETE).*$", ""
    $clean = $clean -replace "\b(S\d+|Season\s*\d+)\b.*$", ""
    $clean = $clean -replace "[\._\-]", " "
    
    # Extract year if in brackets/parentheses or at end, but keep it in standard format: Title (Year)
    $yearMatch = [regex]::Match($clean, "\b(19\d\d|20[0-2]\d|2030)\b")
    $year = $null
    if ($yearMatch.Success) {
        $year = $yearMatch.Groups[1].Value
        # Strip year and everything after it to get the base title
        $clean = $clean -split "\b$year\b" | Select-Object -First 1
    }
    
    # Strip trailing punctuation
    $clean = $clean -replace "\s*[\(\[\{\-\+]\s*$", ""
    $clean = $clean -replace "^\s*[\(\[\{\-\+]\s*", ""
    $clean = $clean.Trim() -replace "\s+", " "
    
    # Restore year in standard parentheses if it existed
    if ($year -and $clean -notlike "*$year*") {
        return "$clean ($year)"
    }
    return $clean
}

# Parse Season & Episode from file name
function Parse-SeasonEpisode {
    param([string]$fileName)
    # Patterns to match: S01E02, S1E2, S01.E02, 1x02, etc.
    $patterns = @(
        "S(\d+)\s*[Ee](\d+)",           # S01E02 or S1E2
        "S(\d+)\s*\.\s*[Ee](\d+)",       # S01.E02
        "(\d+)x(\d+)",                  # 1x02
        "\b[Ee][Pp](\d+)\b"             # EP02 (defaults to Season 1)
    )
    
    foreach ($p in $patterns) {
        $match = [regex]::Match($fileName, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $season = 1 # Default if not matched
            $episode = 1
            
            if ($match.Groups.Count -eq 3) {
                $season = [int]$match.Groups[1].Value
                $episode = [int]$match.Groups[2].Value
            } elseif ($match.Groups.Count -eq 2) {
                $episode = [int]$match.Groups[1].Value
            }
            
            return @{
                Season = $season
                Episode = $episode
                Success = $true
            }
        }
    }
    
    # Fallback: Check if file has just a number like "01.mkv"
    $numMatch = [regex]::Match($fileName, "^\s*(\d+)\b")
    if ($numMatch.Success) {
        return @{
            Season = 1
            Episode = [int]$numMatch.Groups[1].Value
            Success = $true
        }
    }
    
    return @{ Success = $false }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  TV Show Migration and Restructuring Engine"
Write-Host "  Mode: $(if ($WhatIf) { 'DRY RUN (WhatIf)' } else { 'LIVE EXECUTION' })"
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host ""

# Get Source and Destination listings
$sourceDirs = Get-ChildItem -LiteralPath $sourceBase -Directory
$destDirs = Get-ChildItem -LiteralPath $destBase -Directory

# Map destination cleaned names
$destCleanNames = @{}
foreach ($d in $destDirs) {
    $clean = Get-CleanShowName -name $d.Name
    if (-not $destCleanNames.ContainsKey($clean.ToLower())) {
        $destCleanNames[$clean.ToLower()] = $d.Name
    }
}

$showsToProcess = @()
foreach ($s in $sourceDirs) {
    if ($s.Name -in @("fs-config", "Share2", "share")) { continue }
    
    $clean = Get-CleanShowName -name $s.Name
    $lowerClean = $clean.ToLower()
    
    if (-not $destCleanNames.ContainsKey($lowerClean)) {
        $showsToProcess += @{
            OriginalName = $s.Name
            CleanName = $clean
            SourcePath = $s.FullName
        }
    }
}

Write-Host "Found $($showsToProcess.Count) shows to migrate." -ForegroundColor Cyan
Write-Host ""

$videoExtensions = @(".mkv", ".mp4", ".avi")
$subExtensions = @(".srt", ".sub")

# Process each show
foreach ($show in $showsToProcess) {
    $cleanShowName = $show.CleanName
    $targetShowPath = Join-Path $destBase $cleanShowName
    
    Write-Host "------------------------------------------------------" -ForegroundColor Gray
    Write-Host "Migrating Show: '$($show.OriginalName)'" -ForegroundColor White
    Write-Host "  -> Target Directory: '$cleanShowName'" -ForegroundColor Green
    
    # Scan all video files inside source show path recursively
    $videoFiles = Get-ChildItem -LiteralPath $show.SourcePath -File -Recurse | Where-Object { $_.Extension -in $videoExtensions }
    
    if ($videoFiles.Count -eq 0) {
        Write-Warning "  [WARN] No video files found for '$($show.OriginalName)' in source!"
        continue
    }
    
    Write-Host "  Found $($videoFiles.Count) episodes to process." -ForegroundColor Gray
    
    if (-not $WhatIf) {
        if (-not (Test-Path -LiteralPath $targetShowPath)) {
            New-Item -ItemType Directory -Path $targetShowPath -Force | Out-Null
        }
    }
    
    foreach ($file in $videoFiles) {
        $parsed = Parse-SeasonEpisode -fileName $file.Name
        if (-not $parsed.Success) {
            Write-Warning "  [WARN] Could not parse season/episode for file: '$($file.Name)'. Skipping."
            continue
        }
        
        $seasonStr = "Season " + $parsed.Season.ToString("00")
        $episodeStr = "S" + $parsed.Season.ToString("00") + "E" + $parsed.Episode.ToString("00")
        
        $destSeasonPath = Join-Path $targetShowPath $seasonStr
        $newFileName = "$cleanShowName - $episodeStr$($file.Extension)"
        # Strip single quotes from filename for maximum SAMBA network compatibility
        $newFileName = $newFileName -replace "'", ""
        
        $targetFilePath = Join-Path $destSeasonPath $newFileName
        
        Write-Host "    [Episode] '$seasonStr' -> '$newFileName'" -ForegroundColor Cyan
        
        # Look for matching subtitles in the same source directory
        $parentDir = $file.DirectoryName
        $subs = @()
        if (Test-Path -LiteralPath $parentDir) {
            $subs = Get-ChildItem -LiteralPath $parentDir -File | Where-Object { 
                $_.Extension -in $subExtensions -and 
                $_.BaseName -like "$($file.BaseName)*" 
            }
        }
        
        if (-not $WhatIf) {
            # Create Season folder
            if (-not (Test-Path -LiteralPath $destSeasonPath)) {
                New-Item -ItemType Directory -Path $destSeasonPath -Force | Out-Null
            }
            
            # Copy video file safely using Copy-Item
            if (-not (Test-Path -LiteralPath $targetFilePath)) {
                Copy-Item -LiteralPath $file.FullName -Destination $targetFilePath -Force -ErrorAction Stop
            }
            
            # Copy matched subtitles
            foreach ($sub in $subs) {
                # Preserve language tag if present (e.g. .eng.srt)
                $langTag = ""
                $subMatch = [regex]::Match($sub.Name, "\.(eng|en|spa|fre|ger|ind)\.[^.]+$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                if ($subMatch.Success) {
                    $langTag = "." + $subMatch.Groups[1].Value.ToLower()
                }
                
                $newSubName = "$cleanShowName - $episodeStr$langTag$($sub.Extension)"
                $newSubName = $newSubName -replace "'", ""
                $targetSubPath = Join-Path $destSeasonPath $newSubName
                
                if (-not (Test-Path -LiteralPath $targetSubPath)) {
                    Copy-Item -LiteralPath $sub.FullName -Destination $targetSubPath -Force -ErrorAction Stop
                }
            }
        } else {
            if ($subs.Count -gt 0) {
                Write-Host "      [Subtitles] Found $($subs.Count) matching subtitle files" -ForegroundColor DarkGray
            }
        }
    }
    
    Write-Host "  [OK] Show '$cleanShowName' successfully queued/processed!" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  TV SHOW RESTRUCTURING COMPLETED"
Write-Host "======================================================" -ForegroundColor Magenta
