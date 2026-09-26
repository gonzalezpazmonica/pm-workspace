import hashlib
import importlib.util
import tempfile
import unittest
from datetime import date
from pathlib import Path


SPEC = importlib.util.spec_from_file_location("grc_audit", Path(__file__).resolve().parents[1] / "scripts/grc-audit.py")
grc = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(grc)


class GRCAuditTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        (self.base / "proof.txt").write_text("independent test: pass\n")
        digest = hashlib.sha256((self.base / "proof.txt").read_bytes()).hexdigest()
        self.data = {
            "scope": {"id": "test-project", "systems": ["app"], "owner": "control-owner"},
            "frameworks": [{"id": "ENS", "version": "RD 311/2022", "status": "current", "official_source": "https://www.boe.es/eli/es/rd/2022/05/03/311/con", "last_verified": "2026-09-26"}],
            "controls": [{"id": "GRC-IAM-001", "title": "Revisión de accesos", "system_scope": "app"}],
            "requirements": [{"id": "REQ-1", "framework": "ENS", "control": "GRC-IAM-001", "source_ref": "referencia verificada por auditor", "applicability": "IN_SCOPE"}],
            "evidence": [{"id": "E-1", "title": "Prueba de acceso", "source": "proof.txt", "source_type": "test", "owner": "control-owner", "collected_at": "2026-09-20", "valid_from": "2026-09-01", "valid_until": "2026-12-31", "hash": digest, "classification": "internal", "frameworks": ["ENS"], "controls": ["GRC-IAM-001"], "system_scope": ["app"], "trust_level": "HIGH", "verification_status": "VERIFIED", "test_result": "PASS"}]
        }

    def run_assessment(self):
        return grc.assess(self.data, self.base, date(2026, 9, 26))

    def state(self):
        return self.run_assessment()["matrix"][0]["state"]

    def test_verified_pass_is_preliminary_and_traced(self):
        result = self.run_assessment()
        self.assertEqual(result["kind"], "PRELIMINARY_GRC_ASSESSMENT")
        self.assertEqual(self.state(), "COMPLIANT")
        self.assertEqual(result["matrix"][0]["evidence"], ["E-1"])
        self.assertEqual(result["evidence_provenance"][0]["sha256"], self.data["evidence"][0]["hash"])

    def test_invented_evidence_rejected(self):
        self.data["evidence"][0]["source"] = "fiction.txt"
        with self.assertRaisesRegex(grc.AssessmentError, "inaccesible"):
            self.run_assessment()

    def test_certification_and_risk_acceptance_forbidden(self):
        for action in ("CERTIFY", "LEGAL_SIGN_OFF", "ACCEPT_RISK", "CLOSE_FINDING", "APPROVE_POLICY", "MODIFY_CONTROL_STATE"):
            with self.subTest(action=action):
                self.data["actions"] = [action]
                with self.assertRaises(grc.AssessmentError):
                    self.run_assessment()

    def test_missing_scope_rejected(self):
        del self.data["scope"]["systems"]
        with self.assertRaisesRegex(grc.AssessmentError, "systems"):
            self.run_assessment()

    def test_missing_evidence_never_compliant(self):
        self.data["evidence"] = []
        self.assertEqual(self.state(), "INSUFFICIENT_EVIDENCE")

    def test_obsolete_reference_rejected(self):
        self.data["frameworks"][0]["status"] = "superseded"
        with self.assertRaisesRegex(grc.AssessmentError, "obsoleta"):
            self.run_assessment()

    def test_stale_verification_rejected(self):
        self.data["frameworks"][0]["last_verified"] = "2025-01-01"
        with self.assertRaisesRegex(grc.AssessmentError, "caducada"):
            self.run_assessment()

    def test_conflicting_evidence_never_compliant(self):
        second = self.data["evidence"][0].copy()
        second.update(id="E-2", test_result="FAIL")
        self.data["evidence"].append(second)
        self.assertEqual(self.state(), "INSUFFICIENT_EVIDENCE")

    def test_expired_evidence_needs_review(self):
        self.data["evidence"][0]["valid_until"] = "2026-09-25"
        self.assertEqual(self.state(), "NEEDS_REVIEW")

    def test_future_evidence_rejected(self):
        self.data["evidence"][0]["valid_from"] = "2026-09-27"
        with self.assertRaisesRegex(grc.AssessmentError, "Periodo"):
            self.run_assessment()

    def test_duplicate_controls_rejected(self):
        self.data["controls"].append(self.data["controls"][0].copy())
        with self.assertRaisesRegex(grc.AssessmentError, "duplicados"):
            self.run_assessment()

    def test_unverified_and_low_trust_never_compliant(self):
        self.data["evidence"][0]["verification_status"] = "SELF_ATTESTED"
        self.assertEqual(self.state(), "INSUFFICIENT_EVIDENCE")
        self.data["evidence"][0]["verification_status"] = "VERIFIED"
        self.data["evidence"][0]["trust_level"] = "LOW"
        self.assertEqual(self.state(), "INSUFFICIENT_EVIDENCE")

    def test_failing_test_creates_traced_draft_finding(self):
        self.data["evidence"][0]["test_result"] = "FAIL"
        result = self.run_assessment()
        self.assertEqual(result["matrix"][0]["state"], "NON_COMPLIANT")
        self.assertEqual(result["findings"][0]["evidence"], ["E-1"])
        self.assertEqual(result["risks"][0]["status"], "PROPOSED")

    def test_control_out_of_scope_rejected(self):
        self.data["controls"][0]["system_scope"] = "other"
        with self.assertRaisesRegex(grc.AssessmentError, "fuera del alcance"):
            self.run_assessment()

    def test_hash_mismatch_rejected(self):
        self.data["evidence"][0]["hash"] = "0" * 64
        with self.assertRaisesRegex(grc.AssessmentError, "Hash"):
            self.run_assessment()

    def test_path_escape_rejected(self):
        self.data["evidence"][0]["source"] = "../private.txt"
        with self.assertRaisesRegex(grc.AssessmentError, "inaccesible"):
            self.run_assessment()

    def test_not_applicable_needs_human_review(self):
        self.data["requirements"][0]["applicability"] = "NOT_APPLICABLE"
        row = self.run_assessment()["matrix"][0]
        self.assertEqual(row["state"], "NOT_APPLICABLE")
        self.assertIn("revisión humana", row["reason"])


if __name__ == "__main__":
    unittest.main()
