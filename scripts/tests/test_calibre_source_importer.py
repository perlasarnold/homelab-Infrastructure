import importlib.util
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "calibre-source-importer.py"
SPEC = importlib.util.spec_from_file_location("calibre_source_importer", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class SourceDiscoveryTests(unittest.TestCase):
    def test_scan_excludes_managed_library_hidden_backups_and_small_text(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "Incoming").mkdir()
            (root / "Calibre").mkdir()
            (root / ".calibre-import-backup-test").mkdir()
            (root / "Incoming" / "book.epub").write_bytes(b"book")
            (root / "Incoming" / "marker.txt").write_bytes(b"small")
            (root / "Incoming" / "novel.txt").write_bytes(
                b"x" * MODULE.MINIMUM_TEXT_SIZE
            )
            (root / "Calibre" / "managed.epub").write_bytes(b"managed")
            (root / ".calibre-import-backup-test" / "old.epub").write_bytes(b"old")

            discovered = MODULE.scan_source_files(root)

            self.assertEqual(
                set(discovered), {"Incoming/book.epub", "Incoming/novel.txt"}
            )


class StabilityTests(unittest.TestCase):
    def test_new_file_requires_two_unchanged_polls(self):
        state = {"version": 1, "known": {}, "pending": {}}
        current = {"new.epub": {"size": 10, "mtime_ns": 20}}

        self.assertEqual(MODULE.classify_stable_changes(state, current), [])
        self.assertEqual(MODULE.classify_stable_changes(state, current), ["new.epub"])

    def test_changed_known_file_requires_two_unchanged_polls(self):
        state = {
            "version": 1,
            "known": {"book.epub": {"size": 10, "mtime_ns": 20, "sha256": "old"}},
            "pending": {},
        }
        changed = {"book.epub": {"size": 11, "mtime_ns": 30}}

        self.assertEqual(MODULE.classify_stable_changes(state, changed), [])
        self.assertEqual(MODULE.classify_stable_changes(state, changed), ["book.epub"])

    def test_disappeared_pending_file_is_removed(self):
        state = {
            "version": 1,
            "known": {},
            "pending": {"gone.epub": {"size": 10, "mtime_ns": 20}},
        }

        self.assertEqual(MODULE.classify_stable_changes(state, {}), [])
        self.assertEqual(state["pending"], {})


if __name__ == "__main__":
    unittest.main()

