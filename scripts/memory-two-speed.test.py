#!/usr/bin/env python3
"""Tests for memory-two-speed.py — SE-268 Slice 4.
Run: python3 scripts/memory-two-speed.test.py
"""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[0]))

_SRC_PATH = Path(__file__).resolve().parent / "memory-two-speed.py"
_ns: dict = {}
exec(_SRC_PATH.read_text(), _ns)

add = _ns["add"]
query = _ns["query"]
consolidate = _ns["consolidate"]
stats = _ns["stats"]
quality_feedback = _ns["quality_feedback"]
_connect = _ns["_connect"]
DB_PATH = _ns["DB_PATH"]

TEST_DB = Path(tempfile.mkdtemp()) / "test-memory.db"


class TestTwoSpeedMemory(unittest.TestCase):
    """AC-4.1 through AC-4.6."""

    @classmethod
    def setUpClass(cls):
        _ns["DB_PATH"] = TEST_DB

    def setUp(self):
        conn = _connect()
        conn.execute("DELETE FROM episodic")
        conn.execute("DELETE FROM semantic")
        conn.commit()
        conn.close()

    def test_two_stores_distinct(self):
        """AC-4.1: Episodic and semantic stores are distinguishable."""
        e = add("episodic entry", store="episodic", dome="test")
        s = add("semantic entry", store="semantic", dome="test")
        self.assertEqual(e["store"], "episodic")
        self.assertEqual(s["store"], "semantic")

        ep_entries = query(dome="test", store="episodic")
        sm_entries = query(dome="test", store="semantic")
        # Semantic entry should be directly queryable
        self.assertEqual(len(sm_entries), 1)
        self.assertEqual(sm_entries[0]["text"], "semantic entry")
        self.assertEqual(len(ep_entries), 1)
        self.assertEqual(ep_entries[0]["text"], "episodic entry")

    def test_selective_replay(self):
        """AC-4.2: Only recurrent/valuable engrams promote."""
        # Add entries with varying recurrence
        for i in range(3):
            add(f"recurrent topic {i}", store="episodic", dome="test",
                value=0.1)
        add("low value single", store="episodic", dome="test", value=0.0)
        add("high value single", store="episodic", dome="test", value=0.8)

        # Manually set recurrence for testing
        conn = _connect()
        conn.execute("UPDATE episodic SET recurrence=3 WHERE text LIKE 'recurrent%'")
        conn.commit()
        conn.close()

        result = consolidate(dome="test", min_recurrence=2, min_value=0.3)
        # recurrent topic entries (recurrence 3 >= 2) + high value single (0.8 >= 0.3) = 4 promoted
        # low value single (0.0 < 0.3, recurrence 1 < 2) = 1 discarded
        self.assertEqual(result["promoted"], 4)
        self.assertEqual(result["discarded"], 1)
        self.assertEqual(result["total_processed"], 5)

    def test_not_total_copy(self):
        """AC-4.3: Semantic << episodic processed."""
        for i in range(20):
            add(f"noise entry {i}", store="episodic", dome="test", value=0.01)

        # Only 2 entries have value above threshold
        add("signal A", store="episodic", dome="test", value=0.9)
        add("signal B", store="episodic", dome="test", value=0.7)

        result = consolidate(dome="test", min_recurrence=3, min_value=0.5)
        # Only 2 signal entries >= 0.5
        self.assertEqual(result["promoted"], 2)
        self.assertGreater(result["discarded"], 0)
        self.assertLess(result["promoted"], result["total_processed"])

    def test_dome_context_retrieval(self):
        """AC-4.4: Same query, different domes → different results."""
        add("sales strategy 2026", store="semantic", dome="sales", value=0.9)
        add("legal compliance note", store="semantic", dome="legal", value=0.9)

        sales_results = query(dome="sales", store="semantic")
        legal_results = query(dome="legal", store="semantic")

        self.assertEqual(len(sales_results), 1)
        self.assertIn("sales", sales_results[0]["text"])
        self.assertEqual(len(legal_results), 1)
        self.assertIn("legal", legal_results[0]["text"])

    def test_dry_run_no_mutation(self):
        """Dry run does not modify stores."""
        add("test entry", store="episodic", dome="test", value=0.9)
        result = consolidate(dome="test", min_value=0.5, dry_run=True)
        self.assertEqual(result["promoted"], 1)
        self.assertEqual(result["dry_run"], True)

        # Verify nothing was actually promoted
        sm = query(dome="test", store="semantic")
        self.assertEqual(len(sm), 0)

    def test_quality_metric(self):
        """AC-4.6: Quality metric tracks promoted-to-used ratio."""
        add("useful fact", store="semantic", dome="test", value=0.9)
        add("ignored fact", store="semantic", dome="test", value=0.5)

        # Access the first one to simulate use
        query(dome="test", store="semantic", limit=1)

        q = quality_feedback()
        self.assertEqual(q["semantic_total"], 2)
        self.assertEqual(q["used"], 1)
        self.assertEqual(q["unused"], 1)
        self.assertEqual(q["quality_ratio"], 0.5)


if __name__ == "__main__":
    unittest.main()
