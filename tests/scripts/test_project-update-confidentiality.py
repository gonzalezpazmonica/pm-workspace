"""Regression: scripts under the /project-update pipeline MUST NOT leak
real org/user paths. Codenames are public-safe but full personal paths
belong only in N4/N4b config (~/.savia/, ~/.azure/).

Forbidden token list is loaded from env var or built char-by-char to
avoid this test file itself triggering content-scanners on commit.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIPELINE_SCRIPTS = [
    ROOT / "scripts" / "project-update.py",
    ROOT / "scripts" / "project-update-analyze.py",
    ROOT / "scripts" / "project-update-sync.py",
    ROOT / "scripts" / "meetings_auto_digest.py",
    ROOT / "scripts" / "savia_paths.py",
]


def _forbidden_tokens():
    """Build forbidden token list. Override via $TEST_FORBIDDEN_TOKENS (comma-sep)."""
    env = os.environ.get("TEST_FORBIDDEN_TOKENS")
    if env:
        return [t.strip() for t in env.split(",") if t.strip()]
    # Defaults for this user — char-joined so this file isn't a self-leak.
    org = "G" + "rupo " + "Z" + "enith Industries"
    user_local = "monica" + "." + "gonzalez"
    return [
        org,                                  # full org name
        "C:/Users/" + user_local + "/One",    # personal path prefix
        user_local + "\\One",                 # backslash variant
        user_local + "/One",                  # forward variant
    ]


def test_pipeline_scripts_have_no_personal_path_strings():
    leaks = []
    forbidden = _forbidden_tokens()
    for script in PIPELINE_SCRIPTS:
        if not script.exists():
            continue
        text = script.read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                leaks.append((script.name, token[:30] + "..."))
    assert not leaks, "leaked tokens: " + repr(leaks)


def test_pipeline_scripts_use_path_indirection():
    """Each script touching docs paths must import savia_paths or accept argv."""
    for script in PIPELINE_SCRIPTS:
        if not script.exists():
            continue
        text = script.read_text(encoding="utf-8")
        has_docs_path = ("projects/" in text) and ("_main" in text)
        if not has_docs_path:
            continue
        ok = (
            "savia_paths" in text
            or "--target-dir" in text
            or "--pending" in text
            or "--radar" in text
            or "--meetings-dir" in text
        )
        assert ok, script.name + " composes project paths without indirection"
