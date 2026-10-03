"""Tests de scripts/mactor.py (skill prospectiva-basica, SE-376).

Casos calculados a mano con la definición del micro-MACTOR del script:
divergencia = distancia media de posiciones ponderada por el stake común.
"""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/mactor.py"
SPEC = importlib.util.spec_from_file_location("mactor", SCRIPT)
mactor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mactor)


def actor(name, pos, stake=None, power=0.5):
    a = {"name": name, "positions": pos, "power": power}
    if stake is not None:
        a["stake"] = stake
    return a


class MactorCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def cli(self, payload, *extra):
        path = self.dir / "in.json"
        path.write_text(payload if isinstance(payload, str) else json.dumps(payload))
        return subprocess.run([sys.executable, str(SCRIPT), "--actors", str(path), *extra],
                              capture_output=True, text=True)

    def rejected(self, payload, *extra):
        r = self.cli(payload, *extra)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertNotIn("Traceback", r.stderr)
        return r.stderr

    # --- cálculo -----------------------------------------------------------
    def test_divergence_weighted_by_common_stake_by_hand(self):
        a = actor("A", {"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 0.5})
        b = actor("B", {"x": 1.0, "y": 0.5}, {"x": 0.5, "y": 1.0})
        # común x=0.5, y=0.5 -> (0.5*1 + 0.5*0.5) / 1.0 = 0.75
        self.assertEqual(mactor.divergence(a, b, ["x", "y"]), 0.75)

    def test_no_common_stake_is_neither_alliance_nor_divergence(self):
        doc = {"axes": ["x", "y"], "actors": [
            actor("A", {"x": 0.0, "y": 0.0}, {"x": 1.0, "y": 0.0}),
            actor("B", {"x": 1.0, "y": 1.0}, {"x": 0.0, "y": 1.0})]}
        r = self.cli(doc)
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout)
        self.assertIsNone(out["pairs"][0]["divergence"])
        self.assertIsNone(out["pairs"][0]["convergence"])
        self.assertEqual(out["alliances"], [])
        self.assertEqual(out["divergences"], [])

    def test_agreement_zone_center_weighted_by_power(self):
        doc = {"axes": ["x"], "actors": [actor("A", {"x": 0.0}, power=0.75),
                                         actor("B", {"x": 1.0}, power=0.25)]}
        out = json.loads(self.cli(doc).stdout)
        self.assertEqual(out["agreement_zone"]["center"]["x"], 0.25)
        self.assertEqual(out["agreement_zone"]["spread"]["x"], 1.0)

    # --- validación --------------------------------------------------------
    def test_rejects_all_zero_power(self):
        doc = {"axes": ["x"], "actors": [actor("A", {"x": 0.0}, power=0),
                                         actor("B", {"x": 1.0}, power=0)]}
        self.assertIn("poder", self.rejected(doc))

    def test_rejects_duplicate_actor_names(self):
        doc = {"axes": ["x"], "actors": [actor("A", {"x": 0.0}), actor("A", {"x": 1.0})]}
        self.rejected(doc)

    def test_rejects_empty_or_duplicate_axes(self):
        self.rejected({"axes": [], "actors": [actor("A", {}), actor("B", {})]})
        self.rejected({"axes": ["x", "x"], "actors": [actor("A", {"x": 0.1}), actor("B", {"x": 0.2})]})

    def test_rejects_boolean_or_text_positions(self):
        self.rejected({"axes": ["x"], "actors": [actor("A", {"x": True}), actor("B", {"x": 0.2})]})
        self.rejected({"axes": ["x"], "actors": [actor("A", {"x": "alto"}), actor("B", {"x": 0.2})]})

    def test_rejects_threshold_out_of_range(self):
        doc = {"axes": ["x"], "actors": [actor("A", {"x": 0.0}), actor("B", {"x": 1.0})]}
        self.rejected(doc, "--threshold", "1.5")
        self.rejected(doc, "--threshold", "-0.1")

    def test_unwritable_json_output_is_exit_2(self):
        doc = {"axes": ["x"], "actors": [actor("A", {"x": 0.0}), actor("B", {"x": 1.0})]}
        self.rejected(doc, "--json", str(self.dir / "no-existe" / "out.json"))

    def test_self_test_passes(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "--self-test"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main()
