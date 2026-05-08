"""savia_paths.py — Confidential path resolver (N4b config, N1 code).

Centralizes resolution of user-specific document roots so that no script
under scripts/ ever hardcodes organization or username strings. Resolution
order (first hit wins):

  1. Environment variable SAVIA_DOCS_ROOT
  2. ~/.savia/savia-paths.json with {"docs_root": "..."}
  3. ConfigError (no fallback — explicit failure beats silent leak)

The codenames (e.g. "Project Aurora") are public-safe and ARE composed
into paths in scripts. Only the user-specific ROOT must come from config.
"""
import json
import os
from pathlib import Path


CONFIG_FILE = Path.home() / ".savia" / "savia-paths.json"


class ConfigError(RuntimeError):
    pass


def docs_root():
    """Return Path to the savia documents root.

    Sources, in order:
      1. $SAVIA_DOCS_ROOT
      2. ~/.savia/savia-paths.json -> "docs_root"

    Raises ConfigError if neither is set. NO fallback to a hardcoded path.
    """
    env = os.environ.get("SAVIA_DOCS_ROOT")
    if env:
        return Path(env)
    if CONFIG_FILE.exists():
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict) and data.get("docs_root"):
                return Path(data["docs_root"])
        except Exception:
            pass
    raise ConfigError(
        "SAVIA_DOCS_ROOT not configured. Either:\n"
        "  export SAVIA_DOCS_ROOT=/path/to/savia/docs\n"
        "or create " + str(CONFIG_FILE) + ' with {"docs_root": "..."}'
    )


def project_paths(slug):
    """Return dict of canonical project paths for a given codename slug.

    Keys:
      base, monica, pm, meetings, digests, reports, radar, notes, pending
    """
    root = docs_root()
    base = root / "projects" / (slug + "_main")
    monica = base / (slug + "-monica")
    pm = base / (slug + "-pm")
    return {
        "root": root,
        "base": base,
        "monica": monica,
        "pm": pm,
        "meetings": monica / "meetings",
        "digests": base / "digests",
        "reports": monica / "reports",
        "radar": monica / "reports" / "radar",
        "notes": monica / "notes",
        "pending": monica / "notes" / "PENDING.md",
    }
