"""Tests for scripts/project-update.py — graceful degrade and job building."""
import importlib.util
import json
import os
import sys
from pathlib import Path
from unittest import mock

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "project-update.py"


def _load():
    spec = importlib.util.spec_from_file_location("project_update", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()


def test_build_jobs_skips_only_cdp_dependent_for_bad_accounts():
    """build_jobs contract: when account_skip contains an alias, only
    CDP-dependent sources are skipped for that alias; saved-session sources
    (mail/calendar/teams-chats) are still attempted because session cookies
    may be fresh.

    NOTE: F0 no longer populates account_skip via silent degrade (strict
    mode aborts on any daemon failure). This test still guards build_jobs
    behaviour for explicit per-source --skip flags or future use cases.
    """
    accounts = {
        "account1": {"cdp_port": 9222},
        "account2": {"cdp_port": 9223},
    }
    opts = {"skip": set(), "account_skip": {"account2"}}
    jobs = mod.build_jobs("Test", accounts, Path("/tmp/cfg.json"), opts)
    labels = [j[0] for j in jobs]
    # account1: all 6 sources attempted
    for src in ("mail", "calendar", "teams-chats", "sp-recordings", "onedrive", "teams-transcripts"):
        assert (src + "-account1") in labels, src + "-account1 missing"
    # account2: ONLY saved-session sources attempted
    assert "mail-account2" in labels
    assert "calendar-account2" in labels
    assert "teams-chats-account2" in labels
    # account2: CDP-dependent sources skipped
    assert "sp-recordings-account2" not in labels
    assert "onedrive-account2" not in labels
    assert "teams-transcripts-account2" not in labels
    # devops still runs (slug-scoped, not per-account)
    assert "devops" in labels


def test_build_jobs_with_no_account_skip_keeps_all():
    accounts = {"account1": {"cdp_port": 9222}, "account2": {"cdp_port": 9223}}
    opts = {"skip": set(), "account_skip": set()}
    jobs = mod.build_jobs("Test", accounts, Path("/tmp/cfg.json"), opts)
    labels = [j[0] for j in jobs]
    # 6 per-account jobs × 2 accounts + devops = 13
    assert len(labels) == 13
    assert any(l == "mail-account2" for l in labels)


def test_cdp_dependent_sources_constant_is_explicit():
    assert mod.CDP_DEPENDENT_SOURCES == {"sp-recordings", "onedrive", "teams-transcripts"}


def test_probe_auth_parses_check_daemon_auth_json():
    payload = json.dumps({
        "accounts": {
            "account1": {"status": "running"},
            "account2": {"status": "error"},
        }
    })
    fake = mock.MagicMock(stdout=payload, returncode=1)
    with mock.patch.object(mod.subprocess, "run", return_value=fake):
        bad, raw = mod.probe_auth_per_account()
    assert bad == {"account2"}
    assert raw["accounts"]["account1"]["status"] == "running"


def test_probe_auth_returns_probe_failed_on_exception():
    with mock.patch.object(mod.subprocess, "run", side_effect=RuntimeError("x")):
        bad, raw = mod.probe_auth_per_account()
    assert "_probe_failed" in bad
    assert raw == {}


def test_probe_auth_handles_empty_stdout():
    fake = mock.MagicMock(stdout="", returncode=2)
    with mock.patch.object(mod.subprocess, "run", return_value=fake):
        bad, raw = mod.probe_auth_per_account()
    # Empty stdout → no accounts parseable → bad set is empty (caller decides)
    assert bad == set()
    assert raw == {}


def test_build_jobs_skip_devops_works():
    accounts = {"account1": {"cdp_port": 9222}}
    opts = {"skip": {"devops"}, "account_skip": set()}
    jobs = mod.build_jobs("Test", accounts, Path("/tmp/cfg.json"), opts)
    labels = [j[0] for j in jobs]
    assert "devops" not in labels


# ---------------------------------------------------------------------------
# F0 strict mode tests (no silent degrade)
# ---------------------------------------------------------------------------

def _run_main_with_args(monkeypatch, argv, ensure_fake, probe_fake=None):
    """Helper: run mod.main() with argv and patched ensure/probe."""
    monkeypatch.setattr(sys, "argv", ["project-update.py"] + argv)
    monkeypatch.setattr(mod.subprocess, "run", ensure_fake)
    if probe_fake is not None:
        monkeypatch.setattr(mod, "probe_auth_per_account", probe_fake)
    # Stub heavy phases so main() doesn't actually run F1-F4
    monkeypatch.setattr(mod, "phase_refresh", lambda jobs, opts: [])
    monkeypatch.setattr(mod, "phase_digest", lambda slug: [])
    monkeypatch.setattr(mod, "phase_analyze", lambda slug: [])
    monkeypatch.setattr(mod, "phase_sync", lambda slug: [])
    monkeypatch.setattr(mod, "load_accounts", lambda: {"account1": {"cdp_port": 9222}})
    monkeypatch.setattr(mod, "resolve_project", lambda slug: Path("/tmp/cfg.json"))


def test_f0_aborts_on_ensure_nonzero_exit(monkeypatch, capsys):
    """F0 strict: if ensure-daemons-auth.sh exits non-zero, orchestrator aborts."""
    fake_proc = mock.MagicMock(returncode=1, stdout="", stderr="auth failed for account2")
    fake_run = mock.MagicMock(return_value=fake_proc)
    _run_main_with_args(monkeypatch, ["--slug", "Test"], fake_run)
    with pytest.raises(SystemExit) as exc_info:
        mod.main()
    err = capsys.readouterr().err
    msg = str(exc_info.value)
    assert "ABORT" in msg
    assert "rc=1" in msg
    assert "auth failed" in msg


def test_f0_aborts_on_ensure_timeout(monkeypatch, capsys):
    """F0 strict: if ensure-daemons-auth.sh times out, orchestrator aborts."""
    def raise_timeout(*a, **kw):
        raise mod.subprocess.TimeoutExpired(cmd="x", timeout=600)
    _run_main_with_args(monkeypatch, ["--slug", "Test"], raise_timeout)
    with pytest.raises(SystemExit) as exc_info:
        mod.main()
    msg = str(exc_info.value)
    assert "ABORT" in msg
    assert "timed out" in msg


def test_f0_aborts_when_probe_finds_bad_accounts(monkeypatch):
    """F0 strict: even if ensure script returned 0, abort if probe inconsistent."""
    fake_proc = mock.MagicMock(returncode=0, stdout="{}", stderr="")
    fake_run = mock.MagicMock(return_value=fake_proc)
    fake_probe = mock.MagicMock(return_value=({"account2"}, {"accounts": {}}))
    _run_main_with_args(monkeypatch, ["--slug", "Test"], fake_run, fake_probe)
    with pytest.raises(SystemExit) as exc_info:
        mod.main()
    msg = str(exc_info.value)
    assert "ABORT" in msg
    assert "account2" in msg
    assert "inconsistent" in msg


def test_f0_passes_when_ensure_ok_and_probe_clean(monkeypatch, capsys):
    """F0 strict: ensure rc=0 + probe clean => continue to F1+."""
    fake_proc = mock.MagicMock(returncode=0, stdout="{}", stderr="")
    fake_run = mock.MagicMock(return_value=fake_proc)
    fake_probe = mock.MagicMock(return_value=(set(), {"accounts": {"account1": {"status": "running"}}}))
    _run_main_with_args(monkeypatch, ["--slug", "Test"], fake_run, fake_probe)
    # Should not raise
    mod.main()
    err = capsys.readouterr().err
    assert "[F0] OK" in err


def test_f0_skipped_with_skip_auth_flag(monkeypatch, capsys):
    """--skip-auth bypasses F0 entirely (explicit user opt-out)."""
    # subprocess.run should NOT be called for ensure-daemons-auth.sh
    fake_run = mock.MagicMock()
    _run_main_with_args(monkeypatch, ["--slug", "Test", "--skip-auth"], fake_run)
    mod.main()
    err = capsys.readouterr().err
    assert "[F0] auth gate skipped" in err
    # subprocess.run was patched but should not have been invoked for ensure script
    # (it's still the global mock; we just check the gate message)


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
