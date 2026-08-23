<#
.SYNOPSIS
    Animated Movies Library - IMDB Metadata Rename Script
.DESCRIPTION
    Renames folder and file names in the Animated Movies library to match
    standard Plex/Jellyfin naming: "Title (Year)" format.
    Run with -WhatIf first to preview all changes before applying.
.PARAMETER WhatIf
    Preview changes without actually renaming anything.
.EXAMPLE
    .\animated-movies-rename.ps1 -WhatIf
    .\animated-movies-rename.ps1
.NOTES
    Date:    2026-05-16
    Author:  Antigravity / Homelab Automation
    Version: 1.1
#>

param(
    [switch]$WhatIf = $false
)

$Base = "\\truenas\seagate\Share\Movies\Animated Movies"

function Rename-Item-Safe {
    param($OldPath, $NewName)
    $parent = Split-Path $OldPath
    $newPath = Join-Path $parent $NewName
    if ($OldPath -eq $newPath) {
        Write-Host "[SKIP] Already correct: $NewName" -ForegroundColor Gray
        return
    }
    if (Test-Path -LiteralPath $newPath) {
        Write-Warning "[CONFLICT] Target already exists: $newPath - skipping"
        return
    }
    if ($WhatIf) {
        Write-Host "[PREVIEW] '$OldPath'" -ForegroundColor Cyan
        Write-Host "       -> '$newPath'" -ForegroundColor Yellow
    }
    else {
        Rename-Item -LiteralPath $OldPath -NewName $NewName
        Write-Host "[RENAMED] $NewName" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Animated Movies - IMDB Metadata Rename Script"
if ($WhatIf) {
    Write-Host "  MODE: PREVIEW (no changes will be made)" -ForegroundColor Yellow
}
else {
    Write-Host "  MODE: LIVE (changes will be applied)" -ForegroundColor Red
}
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host ""

# -----------------------------------------------------------------------
# SECTION 1: Rename directories
# -----------------------------------------------------------------------
Write-Host "-- SECTION 1: Folder Renames --" -ForegroundColor White

$folderRenames = @(
    ,@("Angry.Birds.2016.1080p.BluRay.6CH.ShAaNiG",                                                                        "The Angry Birds Movie (2016)")
    ,@("DC.League.of.Super-Pets.2022.1080p.WEBRip.DDP5.1.Atmos.x264-CM",                                                  "DC League of Super-Pets (2022)")
    ,@("Despicable.Me.4.2024.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                               "Despicable Me 4 (2024)")
    ,@("Encanto.2021.1080p.WEBRip.x264-RARBG",                                                                             "Encanto (2021)")
    ,@("Incredibles.2.2018.1080p.WEB-DL.DD5.1.H264-CMRG[EtHD]",                                                           "Incredibles 2 (2018)")
    ,@("Injustice.2021.1080p.BluRay.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                                     "Injustice (2021)")
    ,@("Inside.Out.2.2024.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                                  "Inside Out 2 (2024)")
    ,@("Justice.League.Crisis.on.Infinite.Earths.Part.One.2024.1080p.AMZN.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",       "Justice League Crisis on Infinite Earths Part One (2024)")
    ,@("Justice.League.Crisis.on.Infinite.Earths.Part.Two.2024.1080p.BluRay.1400MB.DD5.1.x264-GalaxyRG[TGx]",             "Justice League Crisis on Infinite Earths Part Two (2024)")
    ,@("Justice.League.Crisis.on.Infinite.Earths.Part.Three.2024.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",           "Justice League Crisis on Infinite Earths Part Three (2024)")
    ,@("Kingsglaive.Final.Fantasy.XV.2016.1080p.BluRay.DTS.x264-ETRG",                                                    "Kingsglaive Final Fantasy XV (2016)")
    ,@("Kung.Fu.Panda.4.2024.1080p.AMZN.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                         "Kung Fu Panda 4 (2024)")
    ,@("Lightyear.2022.1080p.WEBRip.x264-RARBG",                                                                           "Lightyear (2022)")
    ,@("Luca.2021.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                                          "Luca (2021)")
    ,@("Minions.The.Rise.of.Gru.2022.1080p.AMZN.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                 "Minions The Rise of Gru (2022)")
    ,@("Mononoke.The.Movie.The.Phantom.in.the.Rain.2024.JAPANESE.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",           "Mononoke The Movie The Phantom in the Rain (2024)")
    ,@("Mufasa.The.Lion.King.2024.1080p.WEBRip.Multi.AAC.x265.HNY",                                                       "Mufasa The Lion King (2024)")
    ,@("Puss.in.Boots.The.Last.Wish.2022.1080p.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                                  "Puss in Boots The Last Wish (2022)")
    ,@("Sing.2.2021.1080p.WEBRip.DDP5.1.Atmos.x264-NOGRP",                                                                "Sing 2 (2021)")
    ,@("South.Park.Post.Covid.The.Return.of.Covid.2021.1080p.AMZN.WEBRip.DD5.1.X.264-EVO",                                "South Park Post Covid The Return of Covid (2021)")
    ,@("South.Park.The.Movie.Bigger.Longer.And.Uncut.1999.720p.BluRay.x264-HDCLASSiCS [PublicHD]",                        "South Park Bigger Longer and Uncut (1999)")
    ,@("South.Park.The.Streaming.Wars.2022.1080p.WEB.H264-NAISU[rarbg]",                                                   "South Park The Streaming Wars (2022)")
    ,@("The.Addams.Family.2.2021.1080p.BluRay.H264.AAC-RARBG",                                                             "The Addams Family 2 (2021)")
    ,@("The.Bad.Guys.2022.1080p.WEBRip.x264-RARBG",                                                                        "The Bad Guys (2022)")
    ,@("The.Boy.and.the.Heron.2023.DUBBED.1080p.AMZN.WEBRip.1400MB.DD5.1.x264-GalaxyRG[TGx]",                            "The Boy and the Heron (2023)")
    ,@("The.Lego.Batman.The.Movie.2017.HDRip.XviD.AC3-EVO[SN]",                                                            "The Lego Batman Movie (2017)")
    ,@("The.Lord.Of.The.Rings.The.War.Of.The.Rohirrim.2024.1080p.WEBRip.10Bit.DDP5.1.x265-Asiimov",                      "The Lord of the Rings The War of the Rohirrim (2024)")
    ,@("The.Super.Mario.Bros.Movie.2023.1080p.WebRip.X264.Will1869",                                                       "The Super Mario Bros Movie (2023)")
    ,@("The.Witcher.Nightmare.of.the.Wolf.2021.720p.NF.WEBRip.800MB.x264-GalaxyRG[TGx]",                                  "The Witcher Nightmare of the Wolf (2021)")
    ,@("The.Witcher.Sirens.of.the.Deep.2025.1080p.NF.WEB-DL.AAC5.1.H.265-HDRush",                                         "The Witcher Sirens of the Deep (2025)")
    ,@("Ultraman.Rising.2024.1080p.NF.WEB-DL.DDP5.1.Atmos.H.264-FLUX[TGx]",                                               "Ultraman Rising (2024)")
    ,@("Big Hero 6 (2014) [1080p]",                                                                                         "Big Hero 6 (2014)")
    ,@("Brave (2012) [1080p]",                                                                                              "Brave (2012)")
    ,@("Coco (2017) [YTS.AG]",                                                                                              "Coco (2017)")
    ,@("Deathstroke Knights Dragons (2020) [1080p] [WEBRip] [5.1] [YTS.MX]",                                              "Deathstroke Knights and Dragons (2020)")
    ,@("Final Fantasy VII Advent Children (2005) [1080p]",                                                                  "Final Fantasy VII Advent Children (2005)")
    ,@("Inside Out (2015) [1080p]",                                                                                         "Inside Out (2015)")
    ,@("Kung Fu Panda (2008) [1080p] [YTS.AG]",                                                                            "Kung Fu Panda (2008)")
    ,@("Kung Fu Panda 3 (2016) [YTS.AG]",                                                                                  "Kung Fu Panda 3 (2016)")
    ,@("Moana 2016 1080p BluRay x264 DTS-JYK",                                                                             "Moana (2016)")
    ,@("Ne Zha (2019) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                                   "Ne Zha (2019)")
    ,@("PAW Patrol The Mighty Movie (2023) [720p] [WEBRip] [YTS.MX]",                                                     "PAW Patrol The Mighty Movie (2023)")
    ,@("PAW.Patrol.The.Movie.2021.720p.AMZN.WEBRip.800MB.x264-GalaxyRG[TGx]",                                             "PAW Patrol The Movie (2021)")
    ,@("Paw Patrol Jet To The Rescue (2020) [720p] [WEBRip] [YTS.MX]",                                                    "PAW Patrol Jet to the Rescue (2020)")
    ,@("Raya And The Last Dragon (2021) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                 "Raya and the Last Dragon (2021)")
    ,@("Sing (2016) [1080p] [YTS.AG]",                                                                                     "Sing (2016)")
    ,@("Space Jam A New Legacy (2021) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                   "Space Jam A New Legacy (2021)")
    ,@("Spider-Man Into The Spider-Verse (2018) [WEBRip] [1080p] [YTS.AM]",                                               "Spider-Man Into the Spider-Verse (2018)")
    ,@("Suzume (2022) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                                   "Suzume (2022)")
    ,@("Tangled (2010) [1080p]",                                                                                            "Tangled (2010)")
    ,@("The Addams Family (2019) [WEBRip] [1080p] [YTS.LT]",                                                              "The Addams Family (2019)")
    ,@("The Angry Birds Movie 2 (2019) [WEBRip] [720p] [YTS.LT]",                                                         "The Angry Birds Movie 2 (2019)")
    ,@("Tom And Jerry & The Wizard Of Oz (2011) [720p] [BluRay] [YTS.MX]",                                                "Tom and Jerry and the Wizard of Oz (2011)")
    ,@("Tom and Jerry (2021) 2160p HDR 5.1 x265 10bit Phun Psyz",                                                         "Tom and Jerry (2021)")
    ,@("Trolls (2016) [1080p] [YTS.AG]",                                                                                   "Trolls (2016)")
    ,@("Trolls World Tour (2020) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                       "Trolls World Tour (2020)")
    ,@("WALL-E (2008) [1080p]",                                                                                             "WALL-E (2008)")
    ,@("Weathering With You (2019) [1080p] [BluRay] [5.1] [YTS.MX]",                                                     "Weathering with You (2019)")
    ,@("Zootopia 2016 1080p HDRip x264 AC3-JYK",                                                                           "Zootopia (2016)")
    ,@("Cars",                                                                                                              "Cars (2006)")
    ,@("Frozen",                                                                                                            "Frozen (2013)")
    ,@("How to Train Your Dragon",                                                                                          "How to Train Your Dragon (2010)")
    ,@("Kung Fu Panda 2",                                                                                                   "Kung Fu Panda 2 (2011)")
    ,@("Shrek",                                                                                                             "Shrek (2001)")
    ,@("Toy Story",                                                                                                         "Toy Story (1995)")
    ,@("To Every You I’ve Loved Before",                                                                                    "To Every You Ive Loved Before (2022)")
    ,@("To me, the one who loved you",                                                                                      "To Me the One Who Loved You (2022)")
    ,@("5 Centimeter per second (dub)",                                                                                     "5 Centimeters per Second (2007)")
    ,@("FateStay night Unlimited Blade Works [1080p]",                                                                     "Fate Stay Night Unlimited Blade Works (2010)")
    ,@("I want to eat your pancreas",                                                                                       "I Want to Eat Your Pancreas (2018)")
    ,@("[EMBER] Fate Stay Night Heaven s Feel - III Spring Song (2020) [BD 1080p HEVC 10 bits DD]",                        "Fate Stay Night Heavens Feel III Spring Song (2020)")
    ,@("[MCE][Violet Evergarden 2020][Movie][Trial Version][GB][1080P][x264 AAC]",                                         "Violet Evergarden The Movie (2020)")
    ,@("space.jam.1996.1080p.bluray.dd5.1.hevc.x265",                                                                      "Space Jam (1996)")
    ,@("Superman Batman Apocalypse (2010)",                                                                                  "Superman Batman Apocalypse (2010)")
    ,@("Superman Red Son (2020) [1080p] [WEBRip] [5.1] [YTS.MX]",                                                         "Superman Red Son (2020)")
    ,@("[Omar Hidan] Studio Ghibli - Hayao Miyazaki Collection [BD720P] Sub(Ara,Jap,Eng,Fre)",                             "Studio Ghibli Collection")
)

foreach ($pair in $folderRenames) {
    $oldPath = Join-Path $Base $pair[0]
    if (Test-Path -LiteralPath $oldPath) {
        Rename-Item-Safe -OldPath $oldPath -NewName $pair[1]
    }
    else {
        Write-Warning "[NOT FOUND] $($pair[0])"
    }
}

# -----------------------------------------------------------------------
# SECTION 2: Create folders for loose .mkv files and move them in
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- SECTION 2: Wrap Loose Files Into Subfolders --" -ForegroundColor White

$looseFileMoves = @(
    ,@("Aztec.Batman.Clash.of.Empires.2025.1080p.DS4K.WEBRip.DUAL.10Bit.DDP5.1.x265-NeoNoir.mkv",                                                     "Batman Aztec (2025)",                                    "Batman Aztec (2025).mkv")
    ,@("Demon.Slayer.Kimetsu.No.Yaiba,Infinity.Castle.2025.1080p.HDTS.x265.10Bit.HEVC.(Jap DD 2.0).VITOENCODES.mkv",                                   "Demon Slayer Infinity Castle (2025)",                    "Demon Slayer Infinity Castle (2025).mkv")
    ,@("GOAT 2026 1080p WEB-DL HEVC x265 5.1 BONE.mkv",                                                                                                "G.O.A.T. (2025)",                                       "G.O.A.T. (2025).mkv")
    ,@("KPop.Demon.Hunters.2025.1080p.WEB.h264-EDITH.mkv",                                                                                             "K-Pop Demon Hunters (2025)",                             "K-Pop Demon Hunters (2025).mkv")
    ,@("Ne Zha 2 2025 1080p WEB-DL HEVC x265 5.1 BONE.mkv",                                                                                            "Ne Zha 2 (2025)",                                       "Ne Zha 2 (2025).mkv")
    ,@("Plankton.The.Movie.2025.1080p.NF.WEB-DL.DDP5.1.H.264-EniaHD.mkv",                                                                             "Plankton The Movie (2025)",                              "Plankton The Movie (2025).mkv")
    ,@("Smurfs.2025.1080p.WEBRip.AAC5.1.10bits.x265-Rapta.mkv",                                                                                        "The Smurfs Movie (2025)",                               "The Smurfs Movie (2025).mkv")
    ,@("Sonic The Hedgehog 3 2024 1080p WEB-DL HEVC x265 5.1 BONE.mkv",                                                                                "Sonic the Hedgehog 3 (2024)",                           "Sonic the Hedgehog 3 (2024).mkv")
    ,@("The SpongeBob Movie Search for SquarePants 2025 1080p WEBRIP READNFO AC3 2.0 x264.mkv",                                                         "The SpongeBob Movie Search for SquarePants (2025)",      "The SpongeBob Movie Search for SquarePants (2025).mkv")
    ,@("The Super Mario Galaxy Movie 2026 1080p Multi Webrip HEVC x265-RMTeam.mkv",                                                                     "The Super Mario Galaxy Movie (2026)",                   "The Super Mario Galaxy Movie (2026).mkv")
    ,@("Zootopia 2 2025 1080p WEB-DL HEVC x265 5.1 BONE.mkv",                                                                                          "Zootopia 2 (2025)",                                     "Zootopia 2 (2025).mkv")
    ,@("[AnimeRG] The Last - Naruto the Movie [1080p]v2[10bit][BRip][English Soft Subbed][JRR].mkv",                                                    "The Last Naruto the Movie (2014)",                      "The Last Naruto the Movie (2014).mkv")
)

foreach ($entry in $looseFileMoves) {
    $srcFile   = Join-Path $Base $entry[0]
    $newFolder = Join-Path $Base $entry[1]
    $dstFile   = Join-Path $newFolder $entry[2]

    if (-not (Test-Path -LiteralPath $srcFile)) {
        Write-Warning "[NOT FOUND] $($entry[0])"
        continue
    }

    if ($WhatIf) {
        Write-Host "[PREVIEW] Create folder  : $($entry[1])" -ForegroundColor Cyan
        Write-Host "          Move and rename: $($entry[0])" -ForegroundColor Cyan
        Write-Host "                       -> $($entry[2])" -ForegroundColor Yellow
    }
    else {
        if (-not (Test-Path -LiteralPath $newFolder)) {
            New-Item -ItemType Directory -Path $newFolder | Out-Null
        }
        Move-Item -LiteralPath $srcFile -Destination $dstFile
        Write-Host "[MOVED] $($entry[1])\$($entry[2])" -ForegroundColor Green
    }
}

# -----------------------------------------------------------------------
# SECTION 3: Spam URL file rename
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- SECTION 3: Strip Spam URL From Tom and Jerry 1992 --" -ForegroundColor White

$spamFile    = Join-Path $Base "www.3MovieRulz.vc - Tom and Jerry The Movie (1992) 720p HDRip - Original [Tel + Tam + Hin +Eng] - 650MB - ESub.mkv"
$tjFolder    = Join-Path $Base "Tom and Jerry The Movie (1992)"
$tjCleanFile = Join-Path $tjFolder "Tom and Jerry The Movie (1992).mkv"

if (Test-Path -LiteralPath $spamFile) {
    if ($WhatIf) {
        Write-Host "[PREVIEW] Create folder: Tom and Jerry The Movie (1992)" -ForegroundColor Cyan
        Write-Host "          Rename spam file -> Tom and Jerry The Movie (1992).mkv" -ForegroundColor Yellow
    }
    else {
        if (-not (Test-Path -LiteralPath $tjFolder)) {
            New-Item -ItemType Directory -Path $tjFolder | Out-Null
        }
        Move-Item -LiteralPath $spamFile -Destination $tjCleanFile
        Write-Host "[MOVED] Tom and Jerry The Movie (1992).mkv" -ForegroundColor Green
    }
}
else {
    Write-Warning "[NOT FOUND] Tom and Jerry spam file"
}

# -----------------------------------------------------------------------
# SECTION 4: Duplicate Tom and Jerry 2021 info
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- SECTION 4: Duplicate Tom and Jerry 2021 --" -ForegroundColor White
Write-Host "   Keeping  : Tom and Jerry (2021) [2160p 4K MKV - 2.6 GB]" -ForegroundColor Gray
Write-Host "   To delete: Tom.and.Jerry.2021.1080p.WEBRip.x264-RARBG [1080p MP4 - 2.0 GB]" -ForegroundColor Gray

$dupFolder = Join-Path $Base "Tom.and.Jerry.2021.1080p.WEBRip.x264-RARBG"
if (Test-Path -LiteralPath $dupFolder) {
    if ($WhatIf) {
        Write-Host "[PREVIEW] Would DELETE: $dupFolder" -ForegroundColor Red
        Write-Host "          Skipped in preview for safety. Delete manually or re-run script with -DeleteDupes flag." -ForegroundColor Red
    }
    else {
        Write-Warning "[SAFETY] Skipping auto-delete of duplicate. Please manually delete:"
        Write-Host "  $dupFolder" -ForegroundColor Yellow
    }
}

# -----------------------------------------------------------------------
# SECTION 5: Manual Review Items
# -----------------------------------------------------------------------
Write-Host ""
Write-Host "-- SECTION 5: Items Requiring Manual Review --" -ForegroundColor White
Write-Host ""
Write-Host "  1. Pinocchio 2022" -ForegroundColor Yellow
Write-Host "     -> Contains Disney+ live-action version (Robert Zemeckis)" -ForegroundColor Gray
Write-Host "     -> NOT animated - should be moved to Live Action Movies" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. The Rats A Witchers Tale 2025" -ForegroundColor Yellow
Write-Host "     -> Confirmed live-action Netflix film, NOT animated" -ForegroundColor Gray
Write-Host "     -> Should be moved to Live Action Movies" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. The Legend of Aang - The Last Airbender 2026" -ForegroundColor Yellow
Write-Host "     -> Film not officially released yet (Paramount+, Oct 2026)" -ForegroundColor Gray
Write-Host "     -> Verify file authenticity then rename to: Avatar Aang The Last Airbender (2026)" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Justice League Animated (16 films inside)" -ForegroundColor Yellow
Write-Host "     -> Collection folder - not a single movie" -ForegroundColor Gray
Write-Host "     -> Recommendation: Move all subfolders to root Animated Movies, delete parent" -ForegroundColor Gray
Write-Host ""
Write-Host "  5. Disney Collection 1937-2008 (125 .avi files, flat)" -ForegroundColor Yellow
Write-Host "     -> 125 movies need individual folders plus year tagging" -ForegroundColor Gray
Write-Host "     -> Recommendation: Run separate Disney collection expansion script" -ForegroundColor Gray
Write-Host ""
Write-Host "  6. Studio Ghibli Collection (10 .mkv files, flat)" -ForegroundColor Yellow
Write-Host "     -> 10 films need individual folders plus year tagging" -ForegroundColor Gray
Write-Host "     -> Recommendation: Run separate Ghibli expansion script" -ForegroundColor Gray
Write-Host ""
Write-Host "  7. Cells At Work - Lavori in corpo (2024)" -ForegroundColor Yellow
Write-Host "     -> Italian subtitle in folder name; IMDB match unconfirmed" -ForegroundColor Gray
Write-Host "     -> Verify IMDB entry then rename accordingly" -ForegroundColor Gray
Write-Host ""

Write-Host "======================================================" -ForegroundColor Magenta
if ($WhatIf) {
    Write-Host "  PREVIEW COMPLETE - Run without -WhatIf to apply" -ForegroundColor Yellow
}
else {
    Write-Host "  RENAME COMPLETE" -ForegroundColor Green
}
Write-Host "======================================================" -ForegroundColor Magenta
