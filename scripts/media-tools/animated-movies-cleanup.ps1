<#
.SYNOPSIS
    Animated Movies Library - Remaining Manual Cleanup Script
.DESCRIPTION
    Executes remaining manual actions after the main rename pass:
    1. Rename "To Every You I've Loved Before" (Unicode apostrophe)
    2. Delete Tom and Jerry 2021 duplicate (1080p MP4)
    3. Move Pinocchio 2022 to Live Action Movies
    4. Move The Rats A Witchers Tale 2025 to Live Action Movies
    5. Move Cells At Work 2024 to Live Action Movies (confirmed live-action)
    6. Rename The Legend of Aang loose file + wrap in folder
    7. Rename Cells At Work folder (after move)
    Multi-movie collection folders are left as-is per user preference.
.NOTES
    Date:    2026-05-16
    Version: 1.0
#>

$AnimBase   = "\\truenas\seagate\Share\Movies\Animated Movies"
$LiveAction = "\\truenas\seagate\Share\Movies\Human Movies"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Animated Movies - Remaining Cleanup Script"
Write-Host "  Live Action target: $LiveAction"
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host ""

# -----------------------------------------------------------------------
# STEP 1: Rename "To Every You I've Loved Before" (Unicode apostrophe)
# -----------------------------------------------------------------------
Write-Host "-- STEP 1: To Every You I've Loved Before --" -ForegroundColor White

$lovedSrc = Get-ChildItem -LiteralPath $AnimBase -Directory |
    Where-Object { $_.Name -like "*Loved Before*" } |
    Select-Object -First 1

if ($lovedSrc) {
    $lovedDst = "To Every You Ive Loved Before (2022)"
    $lovedDstPath = Join-Path $AnimBase $lovedDst
    if (Test-Path -LiteralPath $lovedDstPath) {
        Write-Warning "[CONFLICT] '$lovedDst' already exists. Skipping."
    } else {
        Rename-Item -LiteralPath $lovedSrc.FullName -NewName $lovedDst
        Write-Host "[RENAMED] '$($lovedSrc.Name)' -> '$lovedDst'" -ForegroundColor Green
    }
} else {
    Write-Warning "[NOT FOUND] Could not locate 'To Every You...Loved Before' folder."
}

# -----------------------------------------------------------------------
# STEP 2: Delete Tom and Jerry 2021 duplicate (1080p MP4 folder)
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- STEP 2: Delete Tom and Jerry 2021 Duplicate (1080p) --" -ForegroundColor White

$dupFolder = Join-Path $AnimBase "Tom.and.Jerry.2021.1080p.WEBRip.x264-RARBG"
if (Test-Path -LiteralPath $dupFolder) {
    Remove-Item -LiteralPath $dupFolder -Recurse -Force
    Write-Host "[DELETED] Tom.and.Jerry.2021.1080p.WEBRip.x264-RARBG" -ForegroundColor Green
    Write-Host "          (Kept: Tom and Jerry (2021) [2160p 4K MKV])" -ForegroundColor Gray
} else {
    Write-Warning "[NOT FOUND] Duplicate folder already gone or already renamed."
}

# -----------------------------------------------------------------------
# STEP 3: Move live-action mismatches to Live Action Movies
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- STEP 3: Move Live-Action Films Out of Animated Folder --" -ForegroundColor White

$liveActionMoves = @(
    ,@("Pinocchio 2022",                         "Pinocchio (2022)")
    ,@("The Rats A Witchers Tale 2025",           "The Rats A Witchers Tale (2025)")
    ,@("Cells At Work - Lavori in corpo (2024) 1080p WEBDL x265 iTA JAP AC3 Sub eng - iDN_CreW", "Cells at Work (2024)")
)

if ($LiveAction) {
    foreach ($pair in $liveActionMoves) {
        $srcPath = Join-Path $AnimBase $pair[0]
        $dstPath = Join-Path $LiveAction $pair[1]

        if (-not (Test-Path -LiteralPath $srcPath)) {
            Write-Warning "[NOT FOUND] $($pair[0])"
            continue
        }
        if (Test-Path -LiteralPath $dstPath) {
            Write-Warning "[CONFLICT] '$($pair[1])' already exists in target. Skipping."
            continue
        }
        # Move and rename simultaneously by moving to parent then renaming
        Move-Item -LiteralPath $srcPath -Destination $dstPath
        Write-Host "[MOVED] '$($pair[0])'" -ForegroundColor Green
        Write-Host "     -> Live Action Movies\$($pair[1])" -ForegroundColor Green
    }
} else {
    Write-Warning "[SKIPPED] Live Action path not resolved. Skipping all live-action moves."
}

# -----------------------------------------------------------------------
# STEP 4: Wrap The Legend of Aang loose file into a clean folder
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- STEP 4: The Legend of Aang - Wrap and Rename --" -ForegroundColor White

$aangFile = Get-ChildItem -LiteralPath $AnimBase -File |
    Where-Object { $_.Name -like "*Aang*" -or $_.Name -like "*Last Airbender*" } |
    Select-Object -First 1

if ($aangFile) {
    $aangFolderName = "Avatar The Last Airbender (2026)"
    $aangFolder     = Join-Path $AnimBase $aangFolderName
    $aangDstFile    = Join-Path $aangFolder "Avatar The Last Airbender (2026).mkv"

    if (Test-Path -LiteralPath $aangFolder) {
        Write-Warning "[CONFLICT] '$aangFolderName' folder already exists. Skipping."
    } else {
        New-Item -ItemType Directory -Path $aangFolder | Out-Null
        Move-Item -LiteralPath $aangFile.FullName -Destination $aangDstFile
        Write-Host "[MOVED] '$($aangFile.Name)'" -ForegroundColor Green
        Write-Host "     -> $aangFolderName\Avatar The Last Airbender (2026).mkv" -ForegroundColor Green
    }
} else {
    Write-Warning "[NOT FOUND] Legend of Aang / Last Airbender file."
}

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  CLEANUP COMPLETE" -ForegroundColor Green
Write-Host ""
Write-Host "  Collection folders left untouched (per user request):"
Write-Host "    - Justice League Animated"
Write-Host "    - Disney Collection 1937-2008"
Write-Host "    - Studio Ghibli Collection"
Write-Host "======================================================" -ForegroundColor Magenta
