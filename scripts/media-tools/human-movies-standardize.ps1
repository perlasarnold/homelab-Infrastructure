<#
.SYNOPSIS
    PNAS Human Movies Metadata Standardization Script
.DESCRIPTION
    Standardizes folder names to "Title (Year)" and wraps loose root files into
    proper directories. Preserves multi-movie/collection directories.
.PARAMETER WhatIf
    Dry-run mode (default is $true). Set to $false to execute live changes.
.NOTES
    Date:    2026-05-16
#>

param(
    [bool]$WhatIf = $true
)

$base = "\\PNAS\Seagate\Share\Movies\Human Movies"

# Ensure path exists
if (-not (Test-Path -LiteralPath $base)) {
    Write-Error "Base path not found: $base"
    exit 1
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  PNAS Human Movies Metadata Standardization"
Write-Host "  Mode: $(if ($WhatIf) { 'DRY RUN (WhatIf)' } else { 'LIVE EXECUTION' })"
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host ""

# Helper function to clean movie titles
function Get-CleanName {
    param([string]$name)
    
    # Strip common file extensions if passed
    $clean = $name -replace "\.(mkv|mp4|avi|srt)$", ""
    
    # Detect 4-digit years (1880-2030)
    $years = [regex]::Matches($clean, "(?:\b|\.|_)(18\d\d|19\d\d|20[0-2]\d|2030)\b")
    if ($years.Count -eq 0) {
        return $null # No year found; skip or flag
    }
    
    # Use robust loop to extract year capture groups
    $extractedYears = @()
    foreach ($m in $years) {
        $extractedYears += $m.Groups[1].Value
    }
    $uniqueYears = $extractedYears | Select-Object -Unique
    
    # If multiple different years found (e.g. 2002,2007 collection folders), skip automated rename
    if ($uniqueYears.Count -gt 1) {
        return $null
    }
    
    # Force array representation to prevent scalar flattening of index 0
    $year = @($uniqueYears)[0]
    
    # Split name by the year to get the title prefix
    $titlePart = $clean -split "(?:\b|\.|_)$year\b"
    if ($titlePart.Count -eq 0) { return $null }
    $title = $titlePart[0]
    
    # Clean up the title: replace dots/underscores/dashes with spaces
    $title = $title -replace "[\._\-]", " "
    
    # Strip any trailing junk or brackets/parentheses from title
    $title = $title -replace "\s*[\(\[\{\-\+]\s*$", ""
    $title = $title -replace "^\s*[\(\[\{\-\+]\s*", ""
    $title = $title.Trim()
    
    # Standardize spaces
    $title = $title -replace "\s+", " "
    
    return [PSCustomObject]@{
        Title = $title
        Year  = $year
        Clean = "$title ($year)"
    }
}

# -----------------------------------------------------------------------
# SECTION 1: Folder Standardization
# -----------------------------------------------------------------------
Write-Host "-- SECTION 1: Folder Standardization --" -ForegroundColor White
$dirs = Get-ChildItem -LiteralPath $base -Directory
$renameCount = 0

foreach ($dir in $dirs) {
    # Skip folders that are already perfectly formatted as "Title (Year)"
    # A perfect format is letters/numbers/spaces, ending with exactly " (YYYY)"
    if ($dir.Name -match "^[^[\(\]\)]+\s\(\d{4}\)$") {
        continue
    }
    
    $cleaned = Get-CleanName -name $dir.Name
    if (-not $cleaned) {
        Write-Host "[SKIP] No unique year or custom collection: $($dir.Name)" -ForegroundColor Gray
        continue
    }
    
    $newFolderName = $cleaned.Clean
    $newFolderPath = Join-Path $base $newFolderName
    
    if ($dir.FullName -eq $newFolderPath) {
        continue
    }
    
    Write-Host "Proposed Rename: '$($dir.Name)'" -ForegroundColor Cyan
    Write-Host "        ➡️ '$newFolderName'" -ForegroundColor Green
    
    if (-not $WhatIf) {
        if (Test-Path -LiteralPath $newFolderPath) {
            Write-Warning "   [CONFLICT] Target folder already exists: $newFolderName. Skipping to avoid merge."
        } else {
            try {
                Rename-Item -LiteralPath $dir.FullName -NewName $newFolderName -ErrorAction Stop
                $renameCount++
            } catch {
                Write-Error "   [ERROR] Failed to rename: $_"
            }
        }
    } else {
        $renameCount++
    }
}

# -----------------------------------------------------------------------
# SECTION 2: Wrap Loose Files in Root
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- SECTION 2: Wrap Loose Root Files --" -ForegroundColor White
$files = Get-ChildItem -LiteralPath $base -File
$wrapCount = 0

foreach ($file in $files) {
    # Only target video files
    if ($file.Extension -notin ".mkv", ".mp4", ".avi") {
        continue
    }
    
    $cleaned = Get-CleanName -name $file.Name
    if (-not $cleaned) {
        Write-Warning "[SKIP] Loose file has no valid year format: $($file.Name)"
        continue
    }
    
    $newFolderName = $cleaned.Clean
    $newFolder = Join-Path $base $newFolderName
    $newFilePath = Join-Path $newFolder "$newFolderName$($file.Extension)"
    
    Write-Host "Proposed Wrap: '$($file.Name)'" -ForegroundColor Cyan
    Write-Host "      ➡️ '$newFolderName\$newFolderName$($file.Extension)'" -ForegroundColor Green
    
    if (-not $WhatIf) {
        try {
            if (-not (Test-Path -LiteralPath $newFolder)) {
                New-Item -ItemType Directory -Path $newFolder -ErrorAction Stop | Out-Null
            }
            if (-not (Test-Path -LiteralPath $newFilePath)) {
                Move-Item -LiteralPath $file.FullName -Destination $newFilePath -ErrorAction Stop
                $wrapCount++
            } else {
                Write-Warning "   [CONFLICT] Target file already exists: $newFilePath"
            }
        } catch {
            Write-Error "   [ERROR] Failed to wrap file: $_"
        }
    } else {
        $wrapCount++
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  SUMMARY OF ACTIONS" -ForegroundColor White
Write-Host "  Total Folders Processed: $(if ($WhatIf) { "$renameCount (Preview)" } else { $renameCount })" -ForegroundColor Green
Write-Host "  Total Files Wrapped:     $(if ($WhatIf) { "$wrapCount (Preview)" } else { $wrapCount })" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Magenta
