#!/usr/bin/env python3
"""
speculative-cache-manager.py — Cache manager for SE-220 speculative execution (Slice 2).

API (CLI):
  get  --tool TOOL_NAME --args-hash HASH [--ttl SECONDS]
  set  --tool TOOL_NAME --args-hash HASH --result JSON [--ttl SECONDS]
  del  --tool TOOL_NAME --args-hash HASH
  clean         Remove all expired entries from the cache directory
  stats         Print JSON stats: total, expired, active, cache_dir

Cache directory: /tmp/savia-speculative-cache/ (overrideable via SAVIA_SPECULATIVE_CACHE_DIR)
TTL default: SAVIA_SPECULATIVE_TTL env var (default 30s)

Thread/process safety: atomic file rename (tmp → final) prevents partial reads.

Ref: SE-220 — Speculative Tool Execution, Slice 2
"""
from __future__ import annotations

import fcntl
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────
CACHE_DIR = Path(os.environ.get("SAVIA_SPECULATIVE_CACHE_DIR", "/tmp/savia-speculative-cache"))
DEFAULT_TTL = int(os.environ.get("SAVIA_SPECULATIVE_TTL", "30"))


# ─────────────────────────────────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────────────────────────────────

def _cache_path(tool_name: str, args_hash: str) -> Path:
    return CACHE_DIR / f"{tool_name}_{args_hash}.json"


def _lock_path(tool_name: str, args_hash: str) -> Path:
    return CACHE_DIR / f"{tool_name}_{args_hash}.lock"


def _is_expired(data: dict[str, Any]) -> bool:
    age = time.time() - data.get("_cached_at", 0)
    ttl = data.get("_ttl", DEFAULT_TTL)
    return age > ttl


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def cache_get(tool_name: str, args_hash: str, ttl: int = DEFAULT_TTL) -> Any | None:
    """
    Retrieve a cached result by (tool_name, args_hash).

    Returns the stored result value, or None if:
    - entry does not exist
    - entry has expired (age > ttl)
    - file is corrupt

    Uses a shared file lock for concurrent read safety.
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = _cache_path(tool_name, args_hash)
    lock = _lock_path(tool_name, args_hash)

    if not path.exists():
        return None

    try:
        lock_fh = open(lock, "w")
        try:
            fcntl.flock(lock_fh, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:
            # Another process holds exclusive lock; return None (safe miss)
            return None
        try:
            data = json.loads(path.read_text())
        finally:
            fcntl.flock(lock_fh, fcntl.LOCK_UN)
            lock_fh.close()
    except Exception:
        return None

    if _is_expired(data):
        # Lazy eviction
        try:
            path.unlink(missing_ok=True)
        except Exception:
            pass
        return None

    return data.get("result")


def cache_set(tool_name: str, args_hash: str, result: Any, ttl: int = DEFAULT_TTL) -> None:
    """
    Store a result in the cache.

    Uses exclusive file lock + atomic rename for concurrent write safety.
    """
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = _cache_path(tool_name, args_hash)
    lock = _lock_path(tool_name, args_hash)

    payload: dict[str, Any] = {
        "_cached_at": time.time(),
        "_ttl": ttl,
        "_tool": tool_name,
        "_args_hash": args_hash,
        "result": result,
    }
    serialized = json.dumps(payload)

    tmp = path.with_suffix(".tmp")
    lock_fh = open(lock, "w")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX)
        tmp.write_text(serialized)
        tmp.replace(path)
    finally:
        fcntl.flock(lock_fh, fcntl.LOCK_UN)
        lock_fh.close()


def cache_delete(tool_name: str, args_hash: str) -> bool:
    """Remove a cache entry. Returns True if removed, False if not found."""
    path = _cache_path(tool_name, args_hash)
    lock = _lock_path(tool_name, args_hash)
    lock_fh = open(lock, "w")
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX)
        if path.exists():
            path.unlink()
            return True
        return False
    finally:
        fcntl.flock(lock_fh, fcntl.LOCK_UN)
        lock_fh.close()


def cache_clean() -> dict[str, int]:
    """Remove all expired entries. Returns {removed, kept}."""
    if not CACHE_DIR.exists():
        return {"removed": 0, "kept": 0}

    removed = 0
    kept = 0
    for path in CACHE_DIR.glob("*.json"):
        try:
            data = json.loads(path.read_text())
            if _is_expired(data):
                path.unlink(missing_ok=True)
                removed += 1
            else:
                kept += 1
        except Exception:
            # Corrupt file: remove it
            try:
                path.unlink(missing_ok=True)
                removed += 1
            except Exception:
                pass
    # Clean up orphaned lock files
    for lock in CACHE_DIR.glob("*.lock"):
        try:
            lock.unlink(missing_ok=True)
        except Exception:
            pass
    return {"removed": removed, "kept": kept}


def cache_stats() -> dict[str, Any]:
    """Return stats dict: total, expired, active, cache_dir."""
    if not CACHE_DIR.exists():
        return {"total": 0, "expired": 0, "active": 0, "cache_dir": str(CACHE_DIR)}

    total = 0
    expired = 0
    active = 0
    for path in CACHE_DIR.glob("*.json"):
        total += 1
        try:
            data = json.loads(path.read_text())
            if _is_expired(data):
                expired += 1
            else:
                active += 1
        except Exception:
            expired += 1  # corrupt = treat as expired

    return {
        "total": total,
        "expired": expired,
        "active": active,
        "cache_dir": str(CACHE_DIR),
        "default_ttl": DEFAULT_TTL,
    }


# ─────────────────────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────────────────────

def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="SE-220 S2 — Speculative cache manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    # get
    p_get = sub.add_parser("get", help="Retrieve a cached result")
    p_get.add_argument("--tool", required=True)
    p_get.add_argument("--args-hash", required=True, dest="args_hash")
    p_get.add_argument("--ttl", type=int, default=DEFAULT_TTL)

    # set
    p_set = sub.add_parser("set", help="Store a result in cache")
    p_set.add_argument("--tool", required=True)
    p_set.add_argument("--args-hash", required=True, dest="args_hash")
    p_set.add_argument("--result", required=True, help="JSON string for the result value")
    p_set.add_argument("--ttl", type=int, default=DEFAULT_TTL)

    # del
    p_del = sub.add_parser("del", help="Remove a cache entry")
    p_del.add_argument("--tool", required=True)
    p_del.add_argument("--args-hash", required=True, dest="args_hash")

    # clean
    sub.add_parser("clean", help="Remove all expired entries")

    # stats
    sub.add_parser("stats", help="Print cache statistics")

    args = parser.parse_args()

    if args.command == "get":
        result = cache_get(args.tool, args.args_hash, ttl=args.ttl)
        if result is None:
            print(json.dumps({"hit": False, "result": None}))
            return 1  # miss → exit 1 so scripts can check $?
        print(json.dumps({"hit": True, "result": result}))
        return 0

    elif args.command == "set":
        try:
            result_value = json.loads(args.result)
        except json.JSONDecodeError as exc:
            print(json.dumps({"error": f"--result is not valid JSON: {exc}"}), file=sys.stderr)
            return 1
        cache_set(args.tool, args.args_hash, result_value, ttl=args.ttl)
        key = _cache_path(args.tool, args.args_hash)
        print(json.dumps({"stored": True, "path": str(key), "ttl": args.ttl}))
        return 0

    elif args.command == "del":
        removed = cache_delete(args.tool, args.args_hash)
        print(json.dumps({"removed": removed}))
        return 0

    elif args.command == "clean":
        counts = cache_clean()
        print(json.dumps(counts))
        return 0

    elif args.command == "stats":
        print(json.dumps(cache_stats()))
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
