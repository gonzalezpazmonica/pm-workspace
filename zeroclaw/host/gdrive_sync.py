"""Google Drive memory sync for SaviaClaw — persist memory forever.

Uses OpenCode with Google Drive MCP to upload critical memory
files. Falls back gracefully if MCP not configured.

Usage:
    python3 gdrive_sync.py sync [--dry-run]
    python3 gdrive_sync.py status
"""
import subprocess, os, json, time
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent.parent))
SYNC_LOG = os.path.expanduser("~/.savia/gdrive-sync.log")

# Critical files to persist (relative to workspace root)
SYNC_FILES = [
    "docs/memory-architecture.md",
    "docs/propuestas/SPEC-036-agent-evaluation.md",
    "docs/propuestas/SPEC-038-knowledge-domain-routing.md",
    "docs/propuestas/SPEC-039-context-auto-prime.md",
    "docs/propuestas/SPEC-040-memory-research-experiments.md",
    "docs/propuestas/SPEC-041-brain-context-reasoning.md",
    "docs/rules/domain/savia-foundational-principles.md",
    "zeroclaw/host/identity.json",
]

# Memory files (local only, not in repo)
LOCAL_MEMORY = [
    "~/.savia/zeroclaw/task-results.jsonl",
    "~/.savia/nextcloud-config",
]

def _llm_cmd(prompt, timeout=30):
    try:
        from .llm_backend import execute
        return execute(prompt)
    except Exception:
        return None

def sync(dry_run=False):
    """Upload critical files to Google Drive via OpenCode MCP."""
    results = []
    ts = datetime.now(timezone.utc).isoformat()

    for f in SYNC_FILES:
        full = ROOT / f
        if not full.exists():
            results.append({"file": f, "status": "missing"}); continue
        if dry_run:
            results.append({"file": f, "status": "would_sync",
                            "size": full.stat().st_size}); continue
        prompt = (f"Upload the file at {full} to Google Drive in a folder "
                  f"called 'savia-memory'. Use the Google Drive MCP tool.")
        resp = _llm_cmd(prompt, timeout=60)
        ok = resp is not None and "error" not in (resp or "").lower()
        results.append({"file": f, "status": "synced" if ok else "failed",
                        "response": (resp or "")[:100]})

    # Log results
    os.makedirs(os.path.dirname(SYNC_LOG), exist_ok=True)
    with open(SYNC_LOG, "a") as log:
        log.write(json.dumps({"ts": ts, "results": results}) + "\n")

    return {"ts": ts, "synced": sum(1 for r in results if r["status"]=="synced"),
            "failed": sum(1 for r in results if r["status"]=="failed"),
            "total": len(results), "details": results}

def status():
    if not os.path.isfile(SYNC_LOG):
        return {"last_sync": "never", "total_syncs": 0}
    with open(SYNC_LOG) as f:
        lines = f.readlines()
    if not lines:
        return {"last_sync": "never", "total_syncs": 0}
    last = json.loads(lines[-1])
    return {"last_sync": last["ts"], "total_syncs": len(lines),
            "last_result": f'{last["synced"]}/{last["total"]} synced'}

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "sync":
        dry = "--dry-run" in sys.argv
        r = sync(dry_run=dry)
        print(json.dumps(r, indent=2))
    elif cmd == "status":
        print(json.dumps(status(), indent=2))
    else:
        print("Usage: gdrive_sync.py {sync|status} [--dry-run]")
