"""Tests for scripts/project-update.py — graceful degrade and job building."""
import importlib.util
import json
import os
import sys
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "project-update.py"


def _load():
    spec = importlib.util.spec_from_file_location("project_update", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mod = _load()


def test_build_jobs_skips_only_cdp_dependent_for_bad_accounts():
    """SH02 graceful: when account daemon is down, only CDP-dependent
    sources are skipped; saved-session sources (mail/calendar/teams-chats)
    are still attempted because their session cookies may be fresh."""
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


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
