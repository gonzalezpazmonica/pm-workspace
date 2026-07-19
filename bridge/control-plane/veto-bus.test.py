#!/usr/bin/env python3
"""Tests for veto-bus.py — SE-268 Slice 1.
Run: python3 bridge/control-plane/veto-bus.test.py
"""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

# Import the module-under-test by exec'ing it (control-plane has dashes, not importable)
_vb_path = Path(__file__).resolve().parent / "veto-bus.py"
_vb_src = _vb_path.read_text().split("if __name__")[0]
_vb_ns: dict = {}
exec(_vb_src, _vb_ns)

# Expose functions for testing
compile_criterio = _vb_ns["compile_criterio"]
check = _vb_ns["check"]
publish = _vb_ns["publish"]
revoke = _vb_ns["revoke"]
list_all = _vb_ns["list_all"]
_build_veto = _vb_ns["_build_veto"]
_active = _vb_ns["_active"]
_lock = _vb_ns["_lock"]


class TestCriterioCompilation(unittest.TestCase):
    """AC-1.5: Compilacion CRITERIO→vetos."""

    def setUp(self):
        with _lock:
            _active.clear()

    def _write_criterio(self, content: str) -> Path:
        f = tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False)
        f.write(content)
        f.close()
        return Path(f.name)

    def test_compiles_linea_roja_only(self):
        """Only dureza:linea_roja entries become vetos."""
        content = """### tecnicas
CRIT-001 — Test roja
  dureza: linea_roja | constitucion: T4
  principio: dato soberano
  enforcement: gate.sh

CRIT-002 — Test preferencia
  dureza: preferencia

CRIT-003 — Test estilo
  dureza: estilo
"""
        path = self._write_criterio(content)
        try:
            vetos = compile_criterio(path)
            self.assertEqual(len(vetos), 1)
            self.assertEqual(vetos[0]["id"], "crit-crit-001")
            self.assertEqual(vetos[0]["domain"], "tecnicas")
        finally:
            os.unlink(path)

    def test_domain_from_section_header(self):
        """Domain comes from ### section header."""
        content = """### comunicacion
CRIT-011 — Test
  dureza: linea_roja
  principio: formal

### riesgo
CRIT-023 — Test
  dureza: linea_roja
  principio: fail closed
"""
        path = self._write_criterio(content)
        try:
            vetos = compile_criterio(path)
            self.assertEqual(len(vetos), 2)
            self.assertEqual(vetos[0]["domain"], "comunicacion")
            self.assertEqual(vetos[1]["domain"], "riesgo")
        finally:
            os.unlink(path)

    def test_empty_file(self):
        path = self._write_criterio("")
        try:
            vetos = compile_criterio(path)
            self.assertEqual(len(vetos), 0)
        finally:
            os.unlink(path)

    def test_real_criterio(self):
        """Verify compilation against real CRITERIO.md."""
        real = Path(__file__).resolve().parents[2] / "CRITERIO.md"
        if not real.exists():
            self.skipTest("CRITERIO.md not found")
        vetos = compile_criterio(real)
        self.assertEqual(len(vetos), 19, "Should have 19 linea_roja entries")
        ids = [v["id"] for v in vetos]
        self.assertIn("crit-crit-001", ids)
        self.assertIn("crit-crit-023", ids)
        self.assertIn("crit-crit-031", ids)
        for v in vetos:
            self.assertIsNone(v["ttl"], "All compiled vetos must be permanent")
            self.assertEqual(v["scope"], "domain")
            self.assertEqual(v["source"], "criterio-compiled")


class TestVetoCheck(unittest.TestCase):
    """AC-1.1, AC-1.3, AC-1.4: Veto check semantics."""

    def setUp(self):
        with _lock:
            _active.clear()

    def test_no_vetos_allows(self):
        blocked, vetos = check("any-action")
        self.assertFalse(blocked)
        self.assertEqual(len(vetos), 0)

    def test_global_veto_blocks_all(self):
        publish(action="*", scope="global", reason="test global")
        blocked, _ = check("any-action")
        self.assertTrue(blocked)
        blocked2, _ = check("other-action")
        self.assertTrue(blocked2)

    def test_domain_veto_scoped(self):
        publish(action="domain:sales:*", scope="domain", domain="sales", reason="test")
        self.assertTrue(check("domain:sales:commit")[0])
        self.assertFalse(check("domain:legal:commit")[0])

    def test_instance_veto_scoped(self):
        publish(action="instance-abc", scope="instance", instance="abc", reason="test")
        self.assertTrue(check("action-on-instance-abc-123")[0])
        self.assertFalse(check("action-on-instance-xyz")[0])

    def test_ttl_expiry(self):
        """AC-1.4: TTL veto expires."""
        publish(action="*", scope="global", ttl=0, reason="zero ttl")
        import time
        time.sleep(0.05)  # allow TTL thread to run or explicit expiry
        blocked, _ = check("action")
        self.assertFalse(blocked, "Zero-TTL veto should expire immediately")

    def test_revoke(self):
        v = publish(action="*", scope="global", reason="revocable")
        self.assertTrue(check("action")[0])
        ok = revoke(v["id"])
        self.assertTrue(ok)
        self.assertFalse(check("action")[0])

    def test_revoke_nonexistent(self):
        self.assertFalse(revoke("nonexistent-id"))

    def test_list_all(self):
        publish(action="a", reason="first")
        publish(action="b", reason="second")
        all_v = list_all()
        self.assertEqual(len(all_v), 2)


if __name__ == "__main__":
    unittest.main()
