"""Tests de scripts/micmac.py (skill prospectiva-basica, SE-376).

Casos calculados a mano o por la definición publicada de MICMAC (Godet):
clasificación indirecta por potencias sucesivas de la matriz de influencias
directas, diagonal nula, escala 0..3.
"""
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/micmac.py"
SPEC = importlib.util.spec_from_file_location("micmac", SCRIPT)
micmac = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(micmac)

CHAIN = [[0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1], [0, 0, 0, 0]]
STAR = [[0, 3, 3, 3], [1, 0, 1, 0], [1, 0, 0, 1], [1, 1, 0, 0]]


class MicmacCli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def cli(self, payload, *extra):
        path = self.dir / "in.json"
        path.write_text(payload if isinstance(payload, str) else json.dumps(payload))
        return subprocess.run([sys.executable, str(SCRIPT), "--matrix", str(path), *extra],
                              capture_output=True, text=True)

    def ok(self, matrix, names=("A", "B", "C", "D")):
        r = self.cli({"variables": list(names), "matrix": matrix})
        self.assertEqual(r.returncode, 0, r.stderr)
        return json.loads(r.stdout)

    def rejected(self, payload):
        r = self.cli(payload)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("ERROR", r.stderr)
        self.assertNotIn("Traceback", r.stderr)
        return r.stderr

    # --- cálculo -----------------------------------------------------------
    def test_chain_indirect_sums_by_hand(self):
        # A->B->C->D: M + M^2 + M^3 (M^4 = 0). Influencia A=3, B=2, C=1, D=0.
        s, power, converged = micmac.indirect(CHAIN)
        self.assertEqual(power, 3)
        self.assertTrue(converged)
        self.assertEqual([sum(r) for r in s], [3, 2, 1, 0])
        self.assertEqual([sum(s[i][j] for i in range(4)) for j in range(4)], [0, 1, 2, 3])

    def test_chain_indirect_differs_from_direct(self):
        out = self.ok(CHAIN)
        self.assertEqual(out["motrices"], ["A", "B"])
        self.assertEqual(out["dependientes"], ["C", "D"])
        self.assertEqual(out["detail"]["B"]["direct_quadrant"], "enlace")
        self.assertEqual(out["detail"]["B"]["direct_influence"], 1)
        self.assertTrue(out["converged"])

    def test_cyclic_driver_is_not_flattened_to_enlace(self):
        # A influye 3 sobre todos y recibe 1 de cada uno: motriz en directo y en indirecto.
        # La versión con tope de saturación lo clasificaba todo como enlace.
        out = self.ok(STAR)
        self.assertEqual(out["motrices"], ["A"])
        self.assertEqual(out["dependientes"], ["B", "C", "D"])
        self.assertEqual(out["enlace"], [])
        self.assertTrue(out["converged"])
        self.assertLessEqual(out["power"], 8)

    def test_shares_are_percentages_of_total(self):
        out = self.ok(CHAIN)
        self.assertAlmostEqual(sum(v["influence"] for v in out["detail"].values()), 100.0, places=1)
        self.assertAlmostEqual(sum(v["dependence"] for v in out["detail"].values()), 100.0, places=1)
        self.assertEqual(out["detail"]["A"]["influence"], 50.0)  # 3 de 6

    def test_not_converged_is_reported(self):
        original = micmac.MAX_POWER
        micmac.MAX_POWER = 2
        self.addCleanup(setattr, micmac, "MAX_POWER", original)
        _, power, converged = micmac.indirect(STAR)
        self.assertEqual(power, 2)
        self.assertFalse(converged)

    def test_fixture_keeps_known_solution(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "--matrix",
                            str(ROOT / "tests/fixtures/l30-prospectiva/micmac-fixture.json")],
                           capture_output=True, text=True)
        out = json.loads(r.stdout)
        self.assertEqual(out["motrices"], ["V1", "V2"])
        self.assertEqual(out["dependientes"], ["V9", "V10"])

    # --- validación --------------------------------------------------------
    def test_rejects_non_zero_diagonal(self):
        m = [row[:] for row in STAR]
        m[1][1] = 2
        self.assertIn("diagonal", self.rejected({"variables": list("ABCD"), "matrix": m}))

    def test_rejects_out_of_scale_in_valid_size(self):
        m = [row[:] for row in STAR]
        m[0][1] = 4
        self.assertIn("0..3", self.rejected({"variables": list("ABCD"), "matrix": m}))

    def test_rejects_non_integer_values(self):
        for bad in (2.5, True, "x", None):
            m = [row[:] for row in STAR]
            m[0][1] = bad
            self.rejected({"variables": list("ABCD"), "matrix": m})

    def test_rejects_all_zero_matrix(self):
        self.rejected({"variables": list("ABCD"), "matrix": [[0] * 4 for _ in range(4)]})

    def test_rejects_duplicate_or_empty_names(self):
        self.rejected({"variables": ["A", "A", "B", "C"], "matrix": STAR})
        self.rejected({"variables": ["A", "", "B", "C"], "matrix": STAR})

    def test_rejects_malformed_documents(self):
        self.rejected("[1, 2]")
        self.rejected({"variables": list("ABCD"), "matrix": None})
        self.rejected({"variables": list("ABCD"), "matrix": STAR, "scale_max": 0})
        self.rejected({"variables": list("ABC"), "matrix": [r[:3] for r in STAR[:3]]})

    def test_unwritable_json_output_is_exit_2(self):
        r = self.cli({"variables": list("ABCD"), "matrix": STAR},
                     "--json", str(self.dir / "no-existe" / "out.json"))
        self.assertEqual(r.returncode, 2)
        self.assertNotIn("Traceback", r.stderr)

    def test_self_test_passes(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "--self-test"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0)
        self.assertIn("SELF-TEST OK", r.stdout)


if __name__ == "__main__":
    unittest.main()
