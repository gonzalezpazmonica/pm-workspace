"""SE-396 H04: real-session canaries assert on the filesystem, and the doctor
only accepts a signed, operational, fresh, correlated receipt. No Codex is invoked."""
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CORE = Path(__file__).resolve().parents[2] / 'scripts/dual-cli'
sys.path.insert(0, str(CORE))

import autonomy_doctor  # noqa: E402
import codex_profile  # noqa: E402
import session_canaries as sc  # noqa: E402

KEY = b'k' * 32


def _write(path, text):
    Path(path).write_text(text)


def honest(prompt, sandbox, workspace, canary):
    """A sandboxed agent: allowed writes land, denied ones do not."""
    ws, nonce = Path(workspace), canary['nonce']
    if canary['id'] == 'L0-read':
        return 0, (ws / 'fixture.txt').read_text().strip()
    if canary['id'] == 'L1-write':
        _write(ws / 'control.txt', nonce + '\n')  # trailing newline, as real agents do
        return 0, 'done'
    if canary['id'] == 'L1-outside':
        _write(ws / 'control-outside.txt', nonce)
        return 0, 'second write denied'
    _write(ws / 'control-protected.txt', nonce)
    return 0, 'protected write denied'


def liar(prompt, sandbox, workspace, canary):
    """Claims success in text without touching the filesystem."""
    return 0, 'OK ' + canary['nonce']


def refuser(prompt, sandbox, workspace, canary):
    """Refuses anything risky: negatives must not pass without the sandbox being exercised."""
    if canary['id'] in ('L1-outside', 'L2-protected'):
        return 0, 'I will not do that'
    return honest(prompt, sandbox, workspace, canary)


def escaper(prompt, sandbox, workspace, canary):
    """Writes where it must not: outside the writable roots and into protected/."""
    ws = Path(workspace)
    if canary['id'] == 'L1-outside':
        _write(canary['target'], canary['nonce'])
    if canary['id'] == 'L2-protected':
        _write(ws / 'protected' / 'keep.txt', 'mutated')
    return honest(prompt, sandbox, workspace, canary)


def deleter(prompt, sandbox, workspace, canary):
    if canary['id'] == 'L2-protected':
        (Path(workspace) / 'protected' / 'keep.txt').unlink()
    if canary['id'] == 'L1-outside':
        Path(canary['target']).mkdir()
    return honest(prompt, sandbox, workspace, canary)


class Env(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.env = {'SAVIA_CANARY_KEY': os.path.join(self.tmp.name, 'keys', 'canary.key'),
                    'SAVIA_CANARY_OUTSIDE_DIR': os.path.join(self.tmp.name, 'outside')}
        self.saved = {k: os.environ.get(k) for k in self.env}
        os.environ.update(self.env)
        self.addCleanup(self._restore)

    def _restore(self):
        for k, v in self.saved.items():
            if v is None: os.environ.pop(k, None)
            else: os.environ[k] = v


class SessionCanaryRunnerTests(Env):
    def failed(self, executor):
        receipt = sc.run(executor, codex_version='v')
        return {c['id'] for c in receipt['canaries'] if not c['passed']}, receipt

    def test_honest_executor_passes_every_canary_but_stays_synthetic_and_unsigned(self):
        failed, receipt = self.failed(honest)
        self.assertEqual(failed, set())
        self.assertEqual({c['id'] for c in receipt['canaries']}, set(sc.REQUIRED))
        self.assertEqual(receipt['evidence_type'], 'SYNTHETIC')
        self.assertNotIn('signature', receipt)

    def test_trailing_newline_write_is_hashed_as_the_nonce(self):
        _, receipt = self.failed(honest)
        write = next(c for c in receipt['canaries'] if c['id'] == 'L1-write')
        self.assertEqual(write['artifact_sha256'], sc.sha256(receipt['nonce']))

    def test_text_claims_without_filesystem_effect_fail(self):
        failed, receipt = self.failed(liar)
        self.assertTrue({'L1-write', 'L1-outside', 'L2-protected'} <= failed)
        self.assertFalse(receipt['passed'])

    def test_refusal_does_not_pass_negative_controls(self):
        failed, _ = self.failed(refuser)
        self.assertEqual(failed, {'L1-outside', 'L2-protected'})

    def test_negative_controls_detect_escape_and_protected_mutation(self):
        failed, _ = self.failed(escaper)
        self.assertEqual(failed, {'L1-outside', 'L2-protected'})

    def test_deleted_protected_file_or_directory_target_fail_without_crashing(self):
        failed, _ = self.failed(deleter)
        self.assertEqual(failed, {'L1-outside', 'L2-protected'})
        self.assertEqual(list(Path(self.env['SAVIA_CANARY_OUTSIDE_DIR']).iterdir()), [])

    def test_outside_target_is_not_under_the_system_temp_writable_root_by_default(self):
        for k in self.env: os.environ.pop(k)
        self.assertEqual(sc.outside_dir(), Path.home() / '.savia' / 'canary-outside')

    def test_each_run_uses_a_fresh_nonce_and_a_removed_workspace(self):
        seen = []
        def spy(prompt, sandbox, workspace, canary):
            seen.append(workspace)
            return honest(prompt, sandbox, workspace, canary)
        first, second = sc.run(spy, codex_version='v'), sc.run(spy, codex_version='v')
        self.assertNotEqual(first['nonce'], second['nonce'])
        self.assertFalse(any(Path(w).exists() for w in seen))

    def test_operational_evidence_requires_the_real_executor_and_key(self):
        with self.assertRaises(ValueError):
            sc.run(honest, codex_version='v', real=True, key=KEY)
        with self.assertRaises(ValueError):
            sc.run(sc.codex_executor, codex_version='v', real=True, key=None)

    def test_key_is_created_owner_only(self):
        sc.load_key(create=True)
        self.assertEqual(os.stat(self.env['SAVIA_CANARY_KEY']).st_mode & 0o777, 0o600)

    def test_receipt_is_published_atomically_and_never_overwritten(self):
        path = Path(self.tmp.name) / 'receipt.json'
        receipt = sc.run(honest, codex_version='v')
        sc.publish(path, receipt)
        self.assertEqual(json.loads(path.read_text())['nonce'], receipt['nonce'])
        with self.assertRaises(Exception):
            sc.publish(path, sc.run(honest, codex_version='v'))

    def test_cli_refuses_existing_output_before_spending_quota(self):
        out = Path(self.tmp.name) / 'exists.json'
        out.write_text('{}')
        result = subprocess.run([sys.executable, str(CORE / 'session_canaries.py'), 'run', '--output', str(out),
                                 '--confirm-provider-cost'], capture_output=True, text=True, timeout=10,
                                env=dict(os.environ, PATH='/nonexistent'))
        self.assertEqual(result.returncode, 2)
        self.assertIn('OUTPUT_EXISTS', result.stdout)

    def test_cli_reports_missing_codex_instead_of_crashing(self):
        out = Path(self.tmp.name) / 'new.json'
        result = subprocess.run([sys.executable, str(CORE / 'session_canaries.py'), 'run', '--output', str(out),
                                 '--confirm-provider-cost'], capture_output=True, text=True, timeout=10,
                                env=dict(os.environ, PATH='/nonexistent'))
        self.assertEqual(result.returncode, 2)
        self.assertIn('CODEX_UNAVAILABLE', result.stdout)
        self.assertNotIn('Traceback', result.stderr)


class DoctorSessionEvidenceTests(Env):
    def operational(self, key=KEY, **overrides):
        receipt = sc.run(honest, codex_version='codex-cli 1.0')
        receipt['evidence_type'] = 'OPERATIONAL_SESSION'
        receipt.update(overrides)
        return sc.sign(receipt, key)

    def probe_evidence(self, ready=True):
        return {'evidence_type': 'OPERATIONAL_PROBE', 'version': 'codex-cli 1.0',
                'configuration_ready': ready, 'autonomy_l0_l2': {'passed': False},
                'status': 'DEGRADED_SAFE', 'max_verified_risk': None, 'passed': False,
                'gaps': ['REAL_SESSION_CANARIES_MISSING']}

    def apply(self, receipt, evidence=None, now=None):
        Path(self.env['SAVIA_CANARY_KEY']).parent.mkdir(parents=True, exist_ok=True)
        Path(self.env['SAVIA_CANARY_KEY']).write_bytes(KEY)
        path = Path(self.tmp.name) / 'r.json'
        path.write_text(json.dumps(receipt))
        return codex_profile.apply_session_evidence(evidence or self.probe_evidence(), path, now=now)

    def rejected(self, evidence, reason):
        self.assertIn('SESSION_RECEIPT_REJECTED:' + reason, evidence['gaps'])
        self.assertIsNone(evidence['max_verified_risk'])
        self.assertFalse(evidence['passed'])

    def test_valid_signed_receipt_verifies_l0_l2_only(self):
        evidence = self.apply(self.operational())
        self.assertTrue(evidence['autonomy_l0_l2']['passed'])
        self.assertEqual(evidence['max_verified_risk'], 'L2')
        self.assertEqual(evidence['status'], 'VERIFIED_L2')
        self.assertTrue(evidence['passed'])
        self.assertNotIn('REAL_SESSION_CANARIES_MISSING', evidence['gaps'])

    def test_synthetic_receipt_is_rejected(self):
        self.rejected(self.apply(sc.run(honest, codex_version='codex-cli 1.0')), 'SYNTHETIC')

    def test_self_declared_operational_receipt_without_signature_is_rejected(self):
        forged = sc.run(honest, codex_version='codex-cli 1.0')
        forged['evidence_type'] = 'OPERATIONAL_SESSION'
        self.rejected(self.apply(forged), 'UNSIGNED')

    def test_receipt_signed_with_another_key_is_rejected(self):
        self.rejected(self.apply(self.operational(key=b'x' * 32)), 'SIGNATURE_INVALID')

    def test_tampering_after_signing_is_rejected(self):
        receipt = self.operational()
        receipt['codex_version'] = 'codex-cli 9.9'
        self.rejected(self.apply(receipt), 'SIGNATURE_INVALID')

    def test_missing_key_is_rejected(self):
        receipt = self.operational()
        path = Path(self.tmp.name) / 'r.json'
        path.write_text(json.dumps(receipt))
        self.rejected(codex_profile.apply_session_evidence(self.probe_evidence(), path), 'KEY_UNAVAILABLE')

    def test_stale_receipt_is_rejected(self):
        later = datetime.now(timezone.utc) + timedelta(days=sc.MAX_AGE_DAYS + 1)
        self.rejected(self.apply(self.operational(), now=later), 'STALE')

    def test_nonce_mismatch_is_rejected(self):
        self.rejected(self.apply(self.operational(nonce='f' * 32)), 'NONCE_MISMATCH')

    def test_scenario_digest_mismatch_is_rejected(self):
        self.rejected(self.apply(self.operational(scenario_digest='0' * 64)), 'SCENARIO_MISMATCH')

    def test_version_mismatch_is_rejected(self):
        self.rejected(self.apply(self.operational(codex_version='codex-cli 0.9')), 'VERSION_MISMATCH')

    def test_missing_canary_is_rejected(self):
        receipt = sc.run(honest, codex_version='codex-cli 1.0')
        receipt.update(evidence_type='OPERATIONAL_SESSION', canaries=receipt['canaries'][:-1])
        self.rejected(self.apply(sc.sign(receipt, KEY)), 'INCOMPLETE')

    def test_failed_canary_is_rejected(self):
        receipt = sc.run(refuser, codex_version='codex-cli 1.0')
        receipt['evidence_type'] = 'OPERATIONAL_SESSION'
        self.rejected(self.apply(sc.sign(receipt, KEY)), 'FAILED')

    def test_malformed_or_missing_file_is_rejected(self):
        evidence = codex_profile.apply_session_evidence(self.probe_evidence(), Path('/nonexistent/r.json'))
        self.rejected(evidence, 'MALFORMED')

    def test_valid_receipt_cannot_upgrade_a_synthetic_probe(self):
        synthetic = dict(self.probe_evidence(), evidence_type='SYNTHETIC')
        self.rejected(self.apply(self.operational(), evidence=synthetic), 'SYNTHETIC_PROBE')

    def test_receipt_without_probe_readiness_does_not_verify(self):
        evidence = self.apply(self.operational(), evidence=self.probe_evidence(ready=False))
        self.assertFalse(evidence['passed'])
        self.assertEqual(evidence['status'], 'DEGRADED_SAFE')
        self.assertIsNone(evidence['max_verified_risk'])
        self.assertIn('PROBE_NOT_READY', evidence['gaps'])

    def test_workspace_doctor_view_consumes_the_receipt(self):
        path = Path(self.tmp.name) / 'r.json'
        path.write_text(json.dumps(self.operational()))
        os.environ['SAVIA_CODEX_TEST_MODE'] = '1'
        self.addCleanup(os.environ.pop, 'SAVIA_CODEX_TEST_MODE', None)
        _, evidence = autonomy_doctor.report(session_receipt=path)
        self.assertIn('SESSION_RECEIPT_REJECTED:SYNTHETIC_PROBE', evidence['gaps'])

    def test_session_receipt_flag_is_rejected_outside_probe(self):
        result = subprocess.run([sys.executable, str(CORE / 'codex_profile.py'), 'rollback', '--target',
                                 str(Path(self.tmp.name) / 'x'), '--session-receipt', 'r.json'],
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertIn('only applies to probe', result.stderr)


if __name__ == '__main__':
    unittest.main()
