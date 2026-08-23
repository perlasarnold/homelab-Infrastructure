#!/usr/bin/env python3
"""
TrueNAS/Homelab Photo Renaming Automation Script
Author: Antigravity / Homelab Admin
Description: Automatically renames photos based on EXIF timestamp and city/country name.
             Supports RAW+JPEG pairing, duplicate resolution, geocoding, and multiple schemas.
             SAFE BY DEFAULT (Dry-run mode unless --apply is specified).
"""

import os
import sys
import subprocess
import json
import argparse
import time
from pathlib import Path

# Optional dependency check for geocoding
try:
    from geopy.geocoders import Nominatim
    from geopy.exc import GeocoderTimedOut
    GEOPY_AVAILABLE = True
except ImportError:
    GEOPY_AVAILABLE = False

# Optional dependency check for Pillow fallback
try:
    from PIL import Image
    from PIL.ExifTags import TAGS, GPSTAGS
    PILLOW_AVAILABLE = True
except ImportError:
    PILLOW_AVAILABLE = False


def check_exiftool():
    """Checks if ExifTool is installed and accessible in the system path."""
    try:
        # Run exiftool -ver to check availability
        result = subprocess.run(["exiftool", "-ver"], capture_output=True, text=True, check=True)
        return True, result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False, None


def get_exif_with_exiftool(file_path):
    """
    Uses ExifTool to extract creation date and numeric GPS coordinates.
    This is extremely reliable and supports raw formats (.RAF, .ARW, .CR3, etc.).
    """
    try:
        # -n flag forces numeric coordinates (decimal degrees) instead of DMS (Degrees Minutes Seconds)
        # -j flag returns JSON output
        cmd = ["exiftool", "-j", "-n", "-DateTimeOriginal", "-CreateDate", "-GPSLatitude", "-GPSLongitude", str(file_path)]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        metadata_list = json.loads(result.stdout)
        if metadata_list:
            return metadata_list[0]
    except Exception as e:
        # Silent fallback or logging can be added here
        pass
    return None


def get_exif_with_pillow(file_path):
    """
    Fallback method using Pillow to extract EXIF from standard images (JPEGs) if ExifTool is missing.
    Does not support RAW formats natively.
    """
    if not PILLOW_AVAILABLE:
        return None
    
    try:
        img = Image.open(file_path)
        exif = img._getexif()
        if not exif:
            return None
        
        data = {}
        gps_info = {}
        for tag_id, value in exif.items():
            tag = TAGS.get(tag_id, tag_id)
            if tag == "GPSInfo":
                for gps_tag_id in value:
                    gps_tag = GPSTAGS.get(gps_tag_id, gps_tag_id)
                    gps_info[gps_tag] = value[gps_tag_id]
            elif tag in ["DateTimeOriginal", "DateTime"]:
                data[tag] = value
                
        # Parse standard EXIF date
        date_val = data.get("DateTimeOriginal") or data.get("DateTime")
        metadata = {}
        if date_val:
            metadata["DateTimeOriginal"] = date_val
            
        # Parse Pillow GPS to decimal degrees
        if gps_info:
            def _to_degrees(value):
                # Helper to convert DMS tuple to float
                d = float(value[0])
                m = float(value[1])
                s = float(value[2])
                return d + (m / 60.0) + (s / 3600.0)

            lat_ref = gps_info.get("GPSLatitudeRef")
            lat_val = gps_info.get("GPSLatitude")
            lon_ref = gps_info.get("GPSLongitudeRef")
            lon_val = gps_info.get("GPSLongitude")

            if lat_val and lat_ref and lon_val and lon_ref:
                lat = _to_degrees(lat_val)
                if lat_ref != "N":
                    lat = -lat
                lon = _to_degrees(lon_val)
                if lon_ref != "E":
                    lon = -lon
                
                metadata["GPSLatitude"] = lat
                metadata["GPSLongitude"] = lon
                
        return metadata
    except Exception:
        return None


# Cache for geocoding lookups to avoid repetitive API requests
GEOCODE_CACHE = {}

def reverse_geocode(lat, lon):
    """
    Converts decimal lat/lon to a sanitized 'City-Country' string.
    Respects OpenStreetMap Nominatim guidelines (cache, user agent, 1s delay).
    """
    if not GEOPY_AVAILABLE:
        return None
    
    # Check cache first
    coord_key = f"{round(lat, 4)},{round(lon, 4)}"
    if coord_key in GEOCODE_CACHE:
        return GEOCODE_CACHE[coord_key]
    
    try:
        # Nominatim usage requires a distinct, descriptive user agent
        geolocator = Nominatim(user_agent="homelab_photo_renamer_arnold")
        
        # 1-second polite rate-limiting delay
        time.sleep(1.0)
        
        location = geolocator.reverse((lat, lon), language="en")
        if not location:
            return None
        
        address = location.raw.get("address", {})
        
        # Sift through location tokens starting from finest to broadest
        city = (address.get("city") or 
                address.get("town") or 
                address.get("village") or 
                address.get("suburb") or 
                address.get("county") or 
                "UnknownCity")
        
        country = address.get("country", "UnknownCountry")
        
        # Clean special chars, spaces, and forward slashes for filesystem safety
        city_clean = city.replace(" ", "-").replace("/", "-").replace("\\", "-")
        country_clean = country.replace(" ", "-").replace("/", "-").replace("\\", "-")
        
        location_str = f"{city_clean}-{country_clean}"
        GEOCODE_CACHE[coord_key] = location_str
        return location_str
    except (GeocoderTimedOut, Exception) as e:
        print(f"  [Warning] Geocoding timed out or failed for coordinates ({lat}, {lon}): {e}", file=sys.stderr)
        return None


def get_folder_inherited_location(file_path):
    """
    Extracts a location name from the parent directory's name
    if it matches a folder format like '2024-10 Tokyo_Japan' or 'Tokyo-Japan'.
    """
    parent_name = Path(file_path).parent.name
    # Strip dates from the folder name if they exist (e.g. '2024-10 Tokyo-Japan' -> 'Tokyo-Japan')
    parts = parent_name.split()
    if len(parts) > 1 and (parts[0].replace("-", "").isdigit() or parts[0].isdigit()):
        return "-".join(parts[1:]).replace(" ", "-")
    return parent_name.replace(" ", "-")


def parse_exif_timestamp(exif_date_str):
    """Parses standard EXIF datetime string 'YYYY:MM:DD HH:MM:SS' to a clean timestamp."""
    try:
        # Remove any leading/trailing spaces
        clean_str = exif_date_str.strip()
        parts = clean_str.split(" ")
        ymd = parts[0].replace(":", "")
        hms = parts[1].replace(":", "")
        return f"{ymd}-{hms}"
    except Exception:
        return None


def get_renamed_base(timestamp, location, schema, original_stem):
    """Generates the new base filename according to the selected schema."""
    if schema == "compact":
        # Option A: YYYYMMDD-HHMMSS-City-Country.ext
        return f"{timestamp}-{location}"
    elif schema == "readable":
        # Option B: YYYY-MM-DD_HH-MM-SS_City_Country.ext
        # Convert YYYYMMDD-HHMMSS to YYYY-MM-DD_HH-MM-SS
        formatted_time = f"{timestamp[0:4]}-{timestamp[4:6]}-{timestamp[6:8]}_{timestamp[9:11]}-{timestamp[11:13]}-{timestamp[13:15]}"
        location_underscore = location.replace("-", "_")
        return f"{formatted_time}_{location_underscore}"
    elif schema == "sequence":
        # Option C: YYYYMMDD-HHMMSS_City-Country_DSCXXXX.ext
        return f"{timestamp}_{location}_{original_stem}"
    return f"{timestamp}-{location}"


def scan_directory(directory, recursive, raw_extensions):
    """Finds all photos and groupings in the target directory."""
    target_dir = Path(directory)
    if not target_dir.exists():
        print(f"Error: Target directory '{directory}' does not exist.")
        sys.exit(1)

    # Standard supported photo extensions (including raw formats)
    supported_extensions = {".jpg", ".jpeg"} | {f".{ext.lower().strip()}" for ext in raw_extensions.split(",")}
    
    # Locate all matching files
    glob_pattern = "**/*" if recursive else "*"
    all_files = []
    
    for item in target_dir.glob(glob_pattern):
        if item.is_file() and item.suffix.lower() in supported_extensions:
            all_files.append(item)
            
    # Group files by parent directory and their lowercased stem (name without extension)
    # This keeps RAW+JPEG pairs matched exactly together (e.g. DSCF001.RAF and DSCF001.JPG)
    file_groups = {}
    for file_path in all_files:
        group_key = (file_path.parent, file_path.stem.lower())
        file_groups.setdefault(group_key, []).append(file_path)
        
    return file_groups


def main():
    parser = argparse.ArgumentParser(
        description="Chronological Photo Renaming Utility (TrueNAS & Photography Archives)"
    )
    parser.add_argument("directory", help="The target directory containing the photos.")
    parser.add_argument(
        "--apply", action="store_true", help="Actually rename files (by default, the script runs in DRY-RUN mode)."
    )
    parser.add_argument(
        "--location", "-l", help="Override dynamic locations with this explicit location (e.g., 'Tokyo-Japan')."
    )
    parser.add_argument(
        "--schema", "-s", choices=["compact", "readable", "sequence"], default="compact",
        help="Rename syntax: 'compact' (Option A: YYYYMMDD-HHMMSS-Loc), 'readable' (Option B: YYYY-MM-DD_HH-MM-SS_Loc), or 'sequence' (Option C: YYYYMMDD-HHMMSS_Loc_DSCXXXX)."
    )
    parser.add_argument(
        "--recursive", "-r", action="store_true", help="Recursively process subdirectories."
    )
    parser.add_argument(
        "--raw-ext", default="raf,arw,cr3,cr2,nef,dng",
        help="Comma-separated list of raw extensions to include (default: raf,arw,cr3,cr2,nef,dng)."
    )
    parser.add_argument(
        "--no-gps", action="store_true", help="Skip GPS geocoding and fall back to folder-based location naming."
    )
    args = parser.parse_args()

    print("=" * 70)
    print("               PHOTO RENAMER AUTOMATION UTILITY")
    print("=" * 70)
    print(f" Target Directory : {args.directory}")
    print(f" Operating Mode   : {'[ACTIVE WRITE MODE]' if args.apply else '[DRY-RUN / PREVIEW ONLY]'}")
    print(f" Renaming Schema  : {args.schema.upper()}")
    print(f" Recursive Scan   : {'ENABLED' if args.recursive else 'DISABLED'}")
    print("=" * 70)

    # 1. Environment and tool auditing
    exiftool_available, exiftool_ver = check_exiftool()
    if exiftool_available:
        print(f" [OK] ExifTool detected (v{exiftool_ver}). Complete metadata support enabled.")
    else:
        print(" [!] ExifTool not found in system PATH.")
        if PILLOW_AVAILABLE:
            print("     Pillow (Python-native) is available. Running JPEG-only fallback mode.")
            print("     RAW files (.RAF, .ARW, etc.) will be SKIPPED unless ExifTool is installed.")
        else:
            print(" [CRITICAL] Neither ExifTool nor Pillow are available. Cannot parse EXIF metadata.")
            print("            Please install ExifTool or run 'pip install Pillow' to proceed.")
            sys.exit(1)

    if not GEOPY_AVAILABLE and not args.no_gps and not args.location:
        print(" [!] Python library 'geopy' is missing. Automatic geocoding is disabled.")
        print("     Falling back to folder-inherited location names.")
        print("     To enable geocoding, run: pip install geopy")
        args.no_gps = True

    # 2. Scanning files
    print("\n Scanning directory...")
    groups = scan_directory(args.directory, args.recursive, args.raw_ext)
    print(f" Found {sum(len(v) for v in groups.values())} files across {len(groups)} distinct photo groups.")

    if not groups:
        print(" No supported files found. Exiting.")
        sys.exit(0)

    # 3. Planning rename operations
    print("\n Analyzing metadata and planning renames...")
    rename_plan = {}  # Source Path -> Target Path
    
    # To keep track of files already renamed in this run, preventing self-collisions
    planned_destinations = set()

    total_groups = len(groups)
    processed_groups = 0

    for (parent_dir, stem_lower), files in sorted(groups.items()):
        processed_groups += 1
        if processed_groups % 50 == 0 or processed_groups == total_groups:
            print(f"  [Progress] Analyzed {processed_groups}/{total_groups} photo groups...")
            sys.stdout.flush()
        # Step A: Gather date and GPS coordinate metadata
        metadata = None
        
        # Try ExifTool first
        if exiftool_available:
            for f in files:
                metadata = get_exif_with_exiftool(f)
                if metadata and ("DateTimeOriginal" in metadata or "CreateDate" in metadata):
                    break
        # Try Pillow fallback next (JPEGs only)
        elif PILLOW_AVAILABLE:
            for f in files:
                if f.suffix.lower() in [".jpg", ".jpeg"]:
                    metadata = get_exif_with_pillow(f)
                    if metadata and "DateTimeOriginal" in metadata:
                        break

        # Step B: Parse date
        timestamp = None
        if metadata:
            raw_date = metadata.get("DateTimeOriginal") or metadata.get("CreateDate")
            if raw_date:
                timestamp = parse_exif_timestamp(raw_date)

        if not timestamp:
            # Fallback to filesystem mtime if EXIF date is missing
            mtime = os.path.getmtime(files[0])
            formatted_mtime = time.strftime("%Y%m%d-%H%M%S", time.localtime(mtime))
            print(f"  [Notice] Missing EXIF date for '{files[0].name}'. Using file modified date: {formatted_mtime}")
            timestamp = formatted_mtime

        # Step C: Resolve Location
        location = "Unknown-Location"
        if args.location:
            location = args.location
        elif not args.no_gps and metadata and "GPSLatitude" in metadata and "GPSLongitude" in metadata:
            lat = float(metadata["GPSLatitude"])
            lon = float(metadata["GPSLongitude"])
            resolved = reverse_geocode(lat, lon)
            if resolved:
                location = resolved
                print(f"  [Geocoding] Resolved {files[0].name} location -> {location}")
            else:
                location = get_folder_inherited_location(files[0])
        else:
            location = get_folder_inherited_location(files[0])

        # Ensure location string has no filesystem-breaking characters
        location = location.replace(" ", "-").replace("/", "-").replace("\\", "-").replace(":", "-")

        # Step D: Formulate base name and resolve clashing (burst shots)
        # Use the stem of the FIRST file in the group as the original reference
        original_stem = files[0].stem
        base_candidate = get_renamed_base(timestamp, location, args.schema, original_stem)
        
        # Loop to ensure uniqueness
        counter = 0
        final_base = base_candidate
        while True:
            suffix = f"-{counter}" if counter > 0 else ""
            test_base = f"{final_base}{suffix}"
            
            # Check if this name causes a collision with existing files outside this group,
            # or with names we have already planned during this run.
            clash = False
            for f in files:
                ext = f.suffix.lower()
                test_path = parent_dir / f"{test_base}{ext}"
                
                # It is a clash if:
                # 1. The file already exists on disk and is NOT one of the source files in this group
                # 2. Or the exact same destination path has been allocated to a previous group
                if (test_path.exists() and test_path not in files) or (test_path in planned_destinations):
                    clash = True
                    break
            
            if not clash:
                final_base = test_base
                break
            counter += 1

        # Step E: Add to rename map
        for f in files:
            ext = f.suffix.lower()
            new_path = parent_dir / f"{final_base}{ext}"
            rename_plan[f] = new_path
            planned_destinations.add(new_path)

    # 4. Reporting & Executing
    print("\n" + "=" * 70)
    print("                     PLANNED OPERATIONS SUMMARY")
    print("=" * 70)
    
    unchanged_count = 0
    change_count = 0
    
    for old_path, new_path in sorted(rename_plan.items()):
        if old_path.name == new_path.name:
            unchanged_count += 1
            # Uncomment below if you want to preview files already perfectly named
            # print(f"  [OK]  {old_path.name} (Already matches schema)")
        else:
            change_count += 1
            print(f"  [RENAME] {old_path.name}  -->  {new_path.name}")

    print("-" * 70)
    print(f" Scheduled for renaming: {change_count} files")
    print(f" Already matches schema : {unchanged_count} files")
    print("=" * 70)

    if change_count == 0:
        print("\n No renaming required. All files are already matching the schema!")
        sys.exit(0)

    # If in dry-run mode, prompt how to apply
    if not args.apply:
        print("\n [!] THIS WAS A DRY-RUN PREVIEW ONLY. No changes have been written to disk.")
        print(f"     To apply these changes, run the command again and append the '--apply' flag:")
        print(f"     python photo-renamer.py \"{args.directory}\" --apply")
        print("=" * 70)
    else:
        print("\n Applying rename operations to disk...")
        success_count = 0
        error_count = 0
        
        for old_path, new_path in sorted(rename_plan.items()):
            if old_path.name == new_path.name:
                continue
            
            try:
                # Capture original modification and access timestamps
                stat_info = os.stat(old_path)
                old_mtime = stat_info.st_mtime
                old_atime = stat_info.st_atime
                
                # Perform the OS level rename
                os.rename(old_path, new_path)
                
                # Explicitly restore original timestamps to be absolutely safe (prevent timeline drift)
                os.utime(new_path, (old_atime, old_mtime))
                
                success_count += 1
            except Exception as e:
                print(f"  [ERROR] Failed to rename {old_path.name}: {e}", file=sys.stderr)
                error_count += 1
                
        print("\n" + "=" * 70)
        print("                      EXECUTION REPORT")
        print("=" * 70)
        print(f" Successfully Renamed : {success_count} files")
        print(f" Failed to Rename     : {error_count} files")
        print("=" * 70)
        print(" Rename operations completed.")


if __name__ == "__main__":
    main()
