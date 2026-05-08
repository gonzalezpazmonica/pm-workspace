"""Tests for scripts/vault-init.py — SPEC-PROJECT-UPDATE F1."""
from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
INIT_PY = REPO_ROOT / "scripts" / "vault-init.py"
VALIDATE_PY = REPO_ROOT / "scripts" / "vault-validate.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("vault_init", INIT_PY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


vault_init = _load_module()


# ─── Slug validation ────────────────────────────────────────────────────────

@pytest.mark.parametrize("slug", ["aurora", "a", "a1", "alpha-beta", "a-b-c", "x9"])
def test_validate_slug_accepts_valid(slug):
    vault_init.validate_slug(slug)  # no raise


@pytest.mark.parametrize(
    "slug",
    [
        "Aurora",       # uppercase
        "-aurora",      # leading hyphen
        "aurora-",      # trailing hyphen
        "aurora_main",  # underscore
        "aurora!",      # punctuation
        "",             # empty
        " aurora",      # leading space
    ],
)
def test_validate_slug_rejects_invalid(slug):
    with pytest.raises(SystemExit):
        vault_init.validate_slug(slug)


# ─── resolve_username ────────────────────────────────────────────────────────

def test_resolve_username_explicit_wins(tmp_path):
    assert vault_init.resolve_username("alice", tmp_path) == "alice"


def test_resolve_username_reads_active_user_md(tmp_path):
    profile = tmp_path / ".claude" / "profiles" / "active-user.md"
    profile.parent.mkdir(parents=True)
    profile.write_text(
        '---\nactive_slug: "monica"\n---\n# header\n', encoding="utf-8"
    )
    assert vault_init.resolve_username(None, tmp_path) == "monica"


def test_resolve_username_falls_back_to_user(tmp_path):
    assert vault_init.resolve_username(None, tmp_path) == "user"


# ─── vault_path layout ──────────────────────────────────────────────────────

def test_vault_path_layout(tmp_path):
    p = vault_init.vault_path(tmp_path, "aurora", "monica")
    assert p == tmp_path / "projects" / "aurora_main" / "aurora-monica" / "vault"


# ─── End-to-end: scaffold creates expected layout ───────────────────────────

def _run_init(tmp_path, *args):
    cmd = [sys.executable, str(INIT_PY), "--root", str(tmp_path), *args]
    return subprocess.run(cmd, capture_output=True, text=True)


def test_init_creates_full_layout(tmp_path):
    r = _run_init(tmp_path, "--slug", "aurora", "--username", "monica")
    assert r.returncode == 0, r.stderr
    base = tmp_path / "projects" / "aurora_main" / "aurora-monica" / "vault"
    for d in vault_init.VAULT_DIRS:
        assert (base / d).is_dir(), f"missing dir: {d}"
    assert (base / "README.md").is_file()
    for tpl in vault_init.TEMPLATES:
        assert (base / "templates" / tpl).is_file(), f"missing template: {tpl}"


def test_init_dry_run_writes_nothing(tmp_path):
    r = _run_init(tmp_path, "--slug", "aurora", "--username", "monica", "--dry-run")
    assert r.returncode == 0
    base = tmp_path / "projects" / "aurora_main"
    assert not base.exists()


def test_init_idempotent(tmp_path):
    args = ["--slug", "aurora", "--username", "monica"]
    r1 = _run_init(tmp_path, *args)
    assert r1.returncode == 0
    base = tmp_path / "projects" / "aurora_main" / "aurora-monica" / "vault"
    pbi_tpl = base / "templates" / "pbi.md"
    sentinel = "# CUSTOM CONTENT — DO NOT TOUCH\n"
    # Append user content to a template; second run must NOT overwrite it.
    pbi_tpl.write_text(pbi_tpl.read_text() + sentinel, encoding="utf-8")
    r2 = _run_init(tmp_path, *args)
    assert r2.returncode == 0
    assert sentinel in pbi_tpl.read_text()
    # And idempotency: re-run reports skipped
    assert "skip-tpl" in r2.stdout


def test_force_templates_overwrites(tmp_path):
    args = ["--slug", "aurora", "--username", "monica"]
    _run_init(tmp_path, *args)
    base = tmp_path / "projects" / "aurora_main" / "aurora-monica" / "vault"
    pbi_tpl = base / "templates" / "pbi.md"
    pbi_tpl.write_text("# wiped\n", encoding="utf-8")
    r2 = _run_init(tmp_path, *args, "--force-templates")
    assert r2.returncode == 0
    text = pbi_tpl.read_text()
    assert "entity_type: pbi" in text
    assert "# wiped" not in text


def test_user_notes_never_touched_by_force(tmp_path):
    """User-created notes outside templates/ must survive --force-templates."""
    args = ["--slug", "aurora", "--username", "monica"]
    _run_init(tmp_path, *args)
    base = tmp_path / "projects" / "aurora_main" / "aurora-monica" / "vault"
    user_note = base / "10-PBIs" / "PBI-0001-my-pbi.md"
    user_note.write_text("# my pbi — keep me\n", encoding="utf-8")
    _run_init(tmp_path, *args, "--force-templates")
    assert user_note.read_text() == "# my pbi — keep me\n"


# ─── Generated templates pass vault-validate.py ─────────────────────────────

@pytest.mark.parametrize("tpl_name", sorted(vault_init.TEMPLATES.keys()))
def test_generated_template_validates(tmp_path, tpl_name):
    args = ["--slug", "aurora", "--username", "monica"]
    r = _run_init(tmp_path, *args)
    assert r.returncode == 0
    tpl = (
        tmp_path
        / "projects"
        / "aurora_main"
        / "aurora-monica"
        / "vault"
        / "templates"
        / tpl_name
    )
    res = subprocess.run(
        [sys.executable, str(VALIDATE_PY), "--check", str(tpl)],
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, (
        f"template {tpl_name} did not validate:\n"
        f"stdout: {res.stdout}\nstderr: {res.stderr}"
    )


# ─── Slug rejection at CLI level ────────────────────────────────────────────

def test_cli_rejects_invalid_slug(tmp_path):
    r = _run_init(tmp_path, "--slug", "Aurora_Bad")
    assert r.returncode != 0
    assert "invalid slug" in (r.stdout + r.stderr).lower()
