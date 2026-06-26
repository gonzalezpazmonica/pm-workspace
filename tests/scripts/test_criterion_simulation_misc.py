"""tests/scripts/test_criterion_simulation_misc.py — SPEC-194

Miscellaneous tests for SPEC-194 components.

AC7:  reaffirmation-log.py accepts reason >= 20 chars, rejects < 20 chars (exit 2)
AC14: kg-schema-migrate-cs.py is idempotent (2 runs don't duplicate table)
"""
from __future__ import annotations

import importlib
import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

# ── Path setup ────────────────────────────────────────────────────────────────
REPO_ROOT   = Path(__file__).resolve().parent.parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts" / "criterion-simulation"
sys.path.insert(0, str(SCRIPTS_DIR))
sys.path.insert(0, str(REPO_ROOT / "scripts"))


def _load_module(filepath: Path, mod_name: str):
    """Load a Python module from a file path."""
    spec = importlib.util.spec_from_file_location(mod_name, filepath)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestReaffirmationLog(unittest.TestCase):
    """AC7: reaffirmation-log.py reason validation."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.log_path = os.path.join(self.tmpdir, "reaffirmations.jsonl")
        # Point module to temp log
        os.environ["SAVIA_CS_REAFFIRMATION_LOG"] = self.log_path
        os.environ["CLAUDE_PROJECT_DIR"] = self.tmpdir
        self.mod = _load_module(
            SCRIPTS_DIR / "reaffirmation-log.py",
            "reaffirmation_log"
        )

    def tearDown(self):
        os.environ.pop("SAVIA_CS_REAFFIRMATION_LOG", None)
        os.environ.pop("CLAUDE_PROJECT_DIR", None)
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_ac7_reaffirm_accepts_long_reason(self):
        """AC7: reaffirm with reason >= 20 chars writes entry and exits 0."""
        reason = "I reviewed all dependencies and the approach is sound."
        self.assertGreaterEqual(len(reason), 20)
        # Should NOT raise SystemExit
        try:
            self.mod.cmd_reaffirm("TASK-001", reason)
        except SystemExit as e:
            self.fail(f"cmd_reaffirm raised SystemExit({e.code}) for valid reason")

        # Log file should exist with a valid entry
        self.assertTrue(os.path.exists(self.log_path))
        with open(self.log_path) as f:
            entries = [json.loads(line) for line in f if line.strip()]
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]["type"], "reaffirm")
        self.assertEqual(entries[0]["task_id"], "TASK-001")
        self.assertEqual(entries[0]["reason"], reason)

    def test_ac7_reaffirm_rejects_short_reason_exit2(self):
        """AC7: reaffirm with reason < 20 chars exits with code 2."""
        short_reason = "too short"
        self.assertLess(len(short_reason), 20)
        with self.assertRaises(SystemExit) as ctx:
            self.mod.cmd_reaffirm("TASK-002", short_reason)
        self.assertEqual(ctx.exception.code, 2)

    def test_reaffirm_rejects_empty_reason(self):
        """Empty reason (0 chars) exits with code 2."""
        with self.assertRaises(SystemExit) as ctx:
            self.mod.cmd_reaffirm("TASK-003", "")
        self.assertEqual(ctx.exception.code, 2)

    def test_reaffirm_rejects_19_char_reason(self):
        """Exactly 19 chars exits with code 2."""
        reason = "x" * 19
        self.assertEqual(len(reason), 19)
        with self.assertRaises(SystemExit) as ctx:
            self.mod.cmd_reaffirm("TASK-004", reason)
        self.assertEqual(ctx.exception.code, 2)

    def test_reaffirm_accepts_exactly_20_char_reason(self):
        """Exactly 20 chars is accepted."""
        reason = "x" * 20
        self.assertEqual(len(reason), 20)
        try:
            self.mod.cmd_reaffirm("TASK-005", reason)
        except SystemExit as e:
            self.fail(f"cmd_reaffirm rejected 20-char reason: SystemExit({e.code})")

    def test_reframe_accepts_valid_statement(self):
        """reframe with non-empty new_statement writes entry."""
        try:
            self.mod.cmd_reframe("TASK-006", "Focus only on the auth service, defer bulk import.")
        except SystemExit as e:
            self.fail(f"cmd_reframe raised SystemExit({e.code}) for valid statement")
        self.assertTrue(os.path.exists(self.log_path))
        with open(self.log_path) as f:
            entries = [json.loads(line) for line in f if line.strip()]
        self.assertEqual(entries[0]["type"], "reframe")

    def test_reframe_rejects_empty_statement(self):
        """reframe with empty new_statement exits 2."""
        with self.assertRaises(SystemExit) as ctx:
            self.mod.cmd_reframe("TASK-007", "")
        self.assertEqual(ctx.exception.code, 2)

    def test_reframe_rejects_whitespace_only_statement(self):
        """reframe with whitespace-only new_statement exits 2."""
        with self.assertRaises(SystemExit) as ctx:
            self.mod.cmd_reframe("TASK-008", "   ")
        self.assertEqual(ctx.exception.code, 2)

    def test_log_entry_has_timestamp(self):
        """Log entry has a ts field."""
        reason = "A sufficiently detailed reason for this test."
        self.mod.cmd_reaffirm("TASK-009", reason)
        with open(self.log_path) as f:
            entry = json.loads(f.readline())
        self.assertIn("ts", entry)
        self.assertTrue(entry["ts"])

    def test_multiple_entries_appended(self):
        """Multiple reaffirmations are appended to the same file."""
        self.mod.cmd_reaffirm("TASK-010", "First reason of at least twenty characters.")
        self.mod.cmd_reaffirm("TASK-011", "Second reason of at least twenty characters.")
        with open(self.log_path) as f:
            entries = [json.loads(line) for line in f if line.strip()]
        self.assertEqual(len(entries), 2)


class TestKGSchemaMigrateCS(unittest.TestCase):
    """AC14: kg-schema-migrate-cs.py is idempotent."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.db_path = os.path.join(self.tmpdir, "graph.db")
        os.environ["SAVIA_KG_DB"] = self.db_path
        os.environ["CLAUDE_PROJECT_DIR"] = self.tmpdir
        self.mod = _load_module(
            REPO_ROOT / "scripts" / "kg-schema-migrate-cs.py",
            "kg_schema_migrate_cs"
        )

    def tearDown(self):
        os.environ.pop("SAVIA_KG_DB", None)
        os.environ.pop("CLAUDE_PROJECT_DIR", None)
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _count_tables(self, name: str) -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute(
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?", (name,)
        )
        count = cursor.fetchone()[0]
        conn.close()
        return count

    def test_ac14_idempotent_first_run(self):
        """First run creates frame_reaffirmations table."""
        from pathlib import Path
        result = self.mod.migrate(Path(self.db_path))
        self.assertTrue(result["success"])
        self.assertEqual(self._count_tables("frame_reaffirmations"), 1)

    def test_ac14_idempotent_second_run_no_duplicate(self):
        """AC14: Second run does NOT duplicate the table."""
        from pathlib import Path
        db = Path(self.db_path)
        # First run
        r1 = self.mod.migrate(db)
        self.assertTrue(r1["success"])
        # Second run
        r2 = self.mod.migrate(db)
        self.assertTrue(r2["success"])

        # Table count must still be exactly 1
        self.assertEqual(
            self._count_tables("frame_reaffirmations"), 1,
            "frame_reaffirmations table was duplicated on second migration run"
        )
        # Second run should have skipped, not applied
        self.assertEqual(
            len(r2["applied"]), 0,
            f"Second run should have skipped all (already exists), but applied: {r2['applied']}"
        )

    def test_schema_has_required_columns(self):
        """frame_reaffirmations has required columns."""
        from pathlib import Path
        self.mod.migrate(Path(self.db_path))
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("PRAGMA table_info(frame_reaffirmations)")
        cols = {row[1] for row in cursor.fetchall()}
        conn.close()
        required = {"task_id", "ts", "operator", "reason", "verdict_before"}
        missing = required - cols
        self.assertEqual(missing, set(), f"Missing columns: {missing}")

    def test_verify_after_migrate(self):
        """verify() returns valid=True after migrate()."""
        from pathlib import Path
        db = Path(self.db_path)
        self.mod.migrate(db)
        result = self.mod.verify(db)
        self.assertTrue(result["valid"])
        self.assertEqual(result["missing"], [])

    def test_verify_before_migrate_returns_invalid(self):
        """verify() returns valid=False on empty DB."""
        from pathlib import Path
        # Create an empty DB without migrating
        conn = sqlite3.connect(self.db_path)
        conn.close()
        result = self.mod.verify(Path(self.db_path))
        self.assertFalse(result["valid"])

    def test_third_run_still_idempotent(self):
        """Three runs in a row: table count stays at 1."""
        from pathlib import Path
        db = Path(self.db_path)
        for _ in range(3):
            r = self.mod.migrate(db)
            self.assertTrue(r["success"])
        self.assertEqual(self._count_tables("frame_reaffirmations"), 1)


if __name__ == "__main__":
    unittest.main()
