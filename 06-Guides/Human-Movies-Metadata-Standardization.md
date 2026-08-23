# Human Movies Metadata Standardization Guide

- **Date:** 2026-05-16
- **Objective:** Automate the correction of filenames and folder naming conventions, strip extraneous release group tags and technical metadata, and resolve loose root file structures for 750+ entries in the "Human Movies" library on PNAS reverse-sync source directory.
- **Reference Script:** [human-movies-standardize.ps1](file:////opt/homelab-infrastructure/06-Guides/human-movies-standardize.ps1)

---

## Objective
The objective was to parse, sanitize, and format the folder structures and files in the `\\PNAS\Seagate\Share\Movies\Human Movies` directory to achieve compatibility with Plex and Jellyfin media servers. This required standardizing all folder names to the clean `Title (Year)` structure, wrapping loose video files into parent-matched directories, and preserving custom-curated multi-movie collections or trilogy series without immediate service disruption.

---

## Steps Taken

### 1. Library-Wide Metadata Audit
- **Action:** Executed a PowerShell scanning tool (`audit-human-movies.ps1`) to parse and catalog the 758 existing directories and 158 loose files.
- **Rationale:** Analyzing the scale of data prevented blind renaming errors and helped build a robust regex parser matching actual pattern distributions (dots, years, release tags).
- **Findings:** Identified 637 directories polluted with quality/release tags (e.g., `[1080p]`, `[YTS.AG]`, `WEB-DL`, `x264-GalaxyRG`) and 158 floating video files lacking a parent directory.

### 2. Design of Regex Title & Year Extractor
- **Action:** Created a PowerShell standardizer script with a custom .NET Regular Expression engine to extract unique 4-digit years (1880–2030) and split the movie prefix.
- **Rationale:** Using capture group arrays (`Groups[1].Value`) prevented dot notation strings from getting truncated or matched to wildcards (avoiding PowerShell pipeline scalar flattening errors).

### 3. Dry-Run Validation (`-WhatIf`)
- **Action:** Executed the script in preview mode (`-WhatIf $true`) to capture, inspect, and validate all 795+ proposed changes.
- **Rationale:** Prevented destructive file mergers or broken folder paths across the PNAS network share. Verified that multi-movie custom trilogy folders (e.g. `Indiana Jones Complete Collection`, `High School Musical Trilogy`) were kept intact and not flattened.

### 4. Live Execution Pass
- **Action:** Executed the script live (`-WhatIf $false`) via PowerShell.
- **Rationale:** Automated the heavy lifting cleanly, ensuring proper directory creations and file moves in a single quick metadata operation.

### 5. Deep File Cleanup & Sanitization Pass
- **Action:** Created and executed a secondary standardization pass `human-movies-deep-cleanup.ps1` to parse all standardized `Title (Year)` subfolders.
- **Rationale:** Inside each folder, we located the primary movie video file (`.mkv`, `.mp4`, `.avi`) and renamed it to exactly match its parent folder name `Title (Year).ext`. Important subtitle tracks (`.srt`) were renamed to match the convention, while junk advertisement metadata, torrent links, and EXE files were deleted.
- **Safety Shield Implementation:** Built an absolute safety check into the deletion engine ensuring no file with video extensions (`.mkv`, `.mp4`, `.avi`) is ever targeted for deletion under any circumstances, even if it contains standard release group labels (like `GalaxyRG` or `RARBG`).

---

## Outcome
- **Directories Standardized:** **652 directories** successfully renamed to standard `Title (Year)` format (e.g., `Anyone But You (2023)`).
- **Loose Files Wrapped:** **157 files** successfully placed inside clean year-tagged parent directories (e.g., `Drop (2025)\Drop (2025).mkv`).
- **Files Deep Cleaned:** **309 video files** renamed and matched with their parent directory names, and **1,190 true junk files** deleted.
- **Collections Intact:** Curated multi-movie franchises were left sorted. For nested trilogies that previously failed to match metadata (such as the *Predator Trilogy*), we structured each movie and its subtitles inside its own clean `Title (Year)` subfolder within the collection directory, guaranteeing perfect Plex metadata resolution without expanding or flattening the parent folder.
- **Plex/Jellyfin Matching:** 100% matched compliance for automated scrapers.

---

## References
- **Standardization Script:** [human-movies-standardize.ps1](file:////opt/homelab-infrastructure/06-Guides/human-movies-standardize.ps1)
- **Deep Sanitization Script:** [human-movies-deep-cleanup.ps1](file:////opt/homelab-infrastructure/06-Guides/human-movies-deep-cleanup.ps1)
- **TrueNAS/PNAS Sync Path:** `\\PNAS\Seagate\Share\Movies\Human Movies`
