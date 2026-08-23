#!/usr/bin/env python3
"""Poll loose ebook folders and add stable new files to a Calibre library."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import time
from typing import Any


SUPPORTED_EXTENSIONS = {
    ".azw",
    ".azw3",
    ".cbr",
    ".cbz",
    ".djvu",
    ".docx",
    ".epub",
    ".fb2",
    ".lit",
    ".lrf",
    ".mobi",
    ".odt",
    ".pdf",
    ".rtf",
    ".txt",
}
MINIMUM_TEXT_SIZE = 100 * 1024
STATE_VERSION = 1


def fingerprint(path: Path) -> dict[str, int]:
    stat = path.stat()
    return {"size": stat.st_size, "mtime_ns": stat.st_mtime_ns}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def scan_source_files(root: Path, library_name: str = "Calibre") -> dict[str, dict[str, int]]:
    discovered: dict[str, dict[str, int]] = {}
    for current_root, directories, filenames in os.walk(root, topdown=True, followlinks=False):
        current = Path(current_root)
        directories[:] = [
            name
            for name in directories
            if not (
                (current == root and name == library_name)
                or name.startswith(".calibre-import-")
            )
        ]
        for filename in filenames:
            path = current / filename
            extension = path.suffix.lower()
            if extension not in SUPPORTED_EXTENSIONS or path.is_symlink():
                continue
            try:
                details = fingerprint(path)
            except FileNotFoundError:
                continue
            if extension == ".txt" and details["size"] < MINIMUM_TEXT_SIZE:
                continue
            discovered[path.relative_to(root).as_posix()] = details
    return discovered


def classify_stable_changes(
    state: dict[str, Any], current: dict[str, dict[str, int]]
) -> list[str]:
    known = state.setdefault("known", {})
    pending = state.setdefault("pending", {})
    stable: list[str] = []

    for relative_path, details in current.items():
        if known.get(relative_path, {}).get("size") == details["size"] and known.get(
            relative_path, {}
        ).get("mtime_ns") == details["mtime_ns"]:
            pending.pop(relative_path, None)
            continue
        if pending.get(relative_path) == details:
            stable.append(relative_path)
        else:
            pending[relative_path] = details

    for relative_path in list(pending):
        if relative_path not in current:
            pending.pop(relative_path, None)
    return sorted(stable, key=str.casefold)


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"version": STATE_VERSION, "known": {}, "pending": {}}
    state = json.loads(path.read_text(encoding="utf-8"))
    if state.get("version") != STATE_VERSION:
        raise RuntimeError(f"Unsupported state version: {state.get('version')}")
    state.setdefault("known", {})
    state.setdefault("pending", {})
    return state


def save_state(path: Path, state: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def initialize_state(root: Path, state_path: Path) -> None:
    current = scan_source_files(root)
    known: dict[str, dict[str, Any]] = {}
    total = len(current)
    for index, (relative_path, details) in enumerate(sorted(current.items()), start=1):
        path = root / relative_path
        known[relative_path] = {**details, "sha256": sha256_file(path)}
        if index % 50 == 0 or index == total:
            print(f"Baseline hashing progress: {index}/{total}", flush=True)
    save_state(
        state_path,
        {"version": STATE_VERSION, "known": known, "pending": {}},
    )
    print(f"Initialized baseline with {total} source files.", flush=True)


def backup_database(library: Path, backup_directory: Path) -> Path:
    backup_directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    timestamp = time.strftime("%Y%m%d-%H%M%S")
    destination = backup_directory / f"metadata-{timestamp}.db"
    source_connection = sqlite3.connect(f"file:{library / 'metadata.db'}?mode=ro", uri=True)
    backup_connection = sqlite3.connect(destination)
    try:
        source_connection.backup(backup_connection)
    finally:
        backup_connection.close()
        source_connection.close()
    os.chmod(destination, 0o600)
    return destination


def prune_backups(backup_directory: Path, keep: int = 7) -> None:
    backups = sorted(backup_directory.glob("metadata-*.db"), key=lambda path: path.stat().st_mtime)
    for old_backup in backups[:-keep]:
        old_backup.unlink()


def run_command(arguments: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, check=check, text=True, capture_output=True)


def verify_database(library: Path) -> None:
    connection = sqlite3.connect(f"file:{library / 'metadata.db'}?mode=ro", uri=True)
    try:
        result = connection.execute("pragma integrity_check").fetchone()[0]
    finally:
        connection.close()
    if result != "ok":
        raise RuntimeError(f"Calibre database integrity failed: {result}")


def import_stable_files(
    root: Path,
    library: Path,
    state_path: Path,
    backup_directory: Path,
    service_name: str,
) -> int:
    state = load_state(state_path)
    current = scan_source_files(root)
    stable_paths = classify_stable_changes(state, current)
    if not stable_paths:
        save_state(state_path, state)
        print(f"No stable new files. Observed {len(current)} source files.")
        return 0

    known_hashes = {
        entry.get("sha256") for entry in state["known"].values() if entry.get("sha256")
    }
    import_queue: list[tuple[str, str]] = []
    for relative_path in stable_paths:
        content_hash = sha256_file(root / relative_path)
        if content_hash in known_hashes:
            state["known"][relative_path] = {
                **current[relative_path],
                "sha256": content_hash,
            }
            state["pending"].pop(relative_path, None)
            print(f"Skipped exact duplicate: {relative_path}")
            continue
        import_queue.append((relative_path, content_hash))
        known_hashes.add(content_hash)

    save_state(state_path, state)
    if not import_queue:
        return 0

    backup = backup_database(library, backup_directory)
    print(f"Database backup created: {backup}")
    run_command(["systemctl", "stop", service_name])
    failures: list[str] = []
    try:
        for relative_path, content_hash in import_queue:
            source = root / relative_path
            result = run_command(
                [
                    "calibredb",
                    "--with-library",
                    str(library),
                    "add",
                    "--automerge",
                    "new_record",
                    str(source),
                ],
                check=False,
            )
            if result.returncode:
                failures.append(relative_path)
                print(f"Import failed: {relative_path}: {result.stderr.strip()}", file=sys.stderr)
                continue
            state["known"][relative_path] = {
                **current[relative_path],
                "sha256": content_hash,
            }
            state["pending"].pop(relative_path, None)
            save_state(state_path, state)
            print(f"Imported: {relative_path}")
        verify_database(library)
    finally:
        run_command(["systemctl", "start", service_name], check=False)

    prune_backups(backup_directory)
    if failures:
        print(f"{len(failures)} file(s) will be retried on the next poll.", file=sys.stderr)
        return 1
    return 0


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--initialize-only", action="store_true")
    parser.add_argument("--root", type=Path, default=Path("/books"))
    parser.add_argument("--library", type=Path, default=Path("/books/Calibre"))
    parser.add_argument(
        "--state", type=Path, default=Path("/var/lib/calibre-source-importer/state.json")
    )
    parser.add_argument(
        "--backup-directory",
        type=Path,
        default=Path("/var/lib/calibre-source-importer/backups"),
    )
    parser.add_argument("--service", default="calibre-web.service")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if not (arguments.library / "metadata.db").is_file():
        raise RuntimeError(f"Calibre database is missing: {arguments.library / 'metadata.db'}")

    import fcntl

    lock_path = Path("/run/calibre-source-importer.lock")
    with lock_path.open("w", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("Another importer run is active; exiting.")
            return 0
        if arguments.initialize_only:
            initialize_state(arguments.root, arguments.state)
            return 0
        return import_stable_files(
            arguments.root,
            arguments.library,
            arguments.state,
            arguments.backup_directory,
            arguments.service,
        )


if __name__ == "__main__":
    raise SystemExit(main())
