#!/usr/bin/env python3
"""memvid-backup.py — SE-041 Slice 2 portable memory backup via memvid.

Evalua memvid (.mv2 format) como alternativa a tar-gzip para backup de memoria
externa. Fallback a tar-gzip cuando memvid no esta instalado.

Usage:
    python3 scripts/memvid-backup.py pack --src DIR --out FILE
    python3 scripts/memvid-backup.py restore --src FILE --out DIR
    python3 scripts/memvid-backup.py verify --src FILE

Exit codes:
    0 - OK
    1 - runtime error (IO, missing file)
    2 - usage error

Ref: SE-041, docs/propuestas/SE-041-memvid-portable-memory.md
Safety: backup/restore operations write files; verify is read-only.
"""

import argparse
import hashlib
import json
import sys
import tarfile
import time
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser(
        description="Portable memory backup wrapper (SE-041 memvid).",
    )
    sub = p.add_subparsers(dest="cmd", required=True)

    pack = sub.add_parser("pack", help="Pack directory to portable backup")
    pack.add_argument("--src", required=True, help="Source directory")
    pack.add_argument("--out", required=True, help="Output file")
    pack.add_argument("--format", choices=["auto", "memvid", "tar-gzip"],
                      default="auto", help="Format selection (auto picks memvid if available)")

    rest = sub.add_parser("restore", help="Restore from backup to directory")
    rest.add_argument("--src", required=True, help="Source backup file")
    rest.add_argument("--out", required=True, help="Output directory")

    ver = sub.add_parser("verify", help="Verify backup integrity")
    ver.add_argument("--src", required=True, help="Source backup file")

    for sp in (pack, rest, ver):
        sp.add_argument("--json", action="store_true", help="JSON output")

    return p.parse_args()


def try_memvid_available():
    """Detect memvid availability without loading it."""
    try:
        import importlib.util
        spec = importlib.util.find_spec("memvid")
        return spec is not None
    except (ImportError, ValueError):
        return False


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def pack_tar_gzip(src_dir, out_file):
    """Fallback: tar.gz packing."""
    src = Path(src_dir)
    if not src.is_dir():
        return {"ok": False, "error": f"not a directory: {src_dir}"}
    start = time.time()
    with tarfile.open(out_file, "w:gz") as tar:
        tar.add(src, arcname=src.name)
    return {
        "ok": True,
        "format": "tar-gzip",
        "size_bytes": Path(out_file).stat().st_size,
        "sha256": sha256_file(out_file),
        "latency_ms": int((time.time() - start) * 1000),
    }


def pack_memvid(src_dir, out_file):
    """Memvid packing when available. Currently falls through to informative stub."""
    try:
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            import memvid  # noqa: F401
        sys.stderr.write(buf.getvalue())
    except ImportError:
        return None

    # Real memvid integration is Slice 3 work. For Slice 2 we acknowledge availability
    # and fall through to tar-gzip with a marker indicating memvid was detected.
    return {
        "ok": False,
        "reason": "memvid_detected_but_integration_pending",
        "note": "Slice 3 will wire actual memvid .mv2 encoding; Slice 2 uses tar-gzip.",
    }


def restore_tar_gzip(src_file, out_dir):
    src = Path(src_file)
    if not src.is_file():
        return {"ok": False, "error": f"not a file: {src_file}"}
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    start = time.time()
    with tarfile.open(src, "r:gz") as tar:
        tar.extractall(out)
    return {
        "ok": True,
        "format": "tar-gzip",
        "files_extracted": len(list(out.rglob("*"))),
        "latency_ms": int((time.time() - start) * 1000),
    }


def verify_backup(src_file):
    src = Path(src_file)
    if not src.is_file():
        return {"ok": False, "error": f"not a file: {src_file}"}
    size = src.stat().st_size
    if size == 0:
        return {"ok": False, "error": "empty file"}
    try:
        with tarfile.open(src, "r:gz") as tar:
            members = tar.getmembers()
        return {
            "ok": True,
            "format": "tar-gzip",
            "size_bytes": size,
            "sha256": sha256_file(src_file),
            "members": len(members),
        }
    except tarfile.TarError as e:
        return {"ok": False, "error": f"invalid tar.gz: {e}"}


def emit(result, use_json):
    if use_json:
        sys.stdout.write(json.dumps(result, ensure_ascii=False))
    else:
        for k, v in result.items():
            sys.stdout.write(f"{k}: {v}\n")
    sys.stdout.write("\n")


def main():
    args = parse_args()
    use_json = getattr(args, "json", False)

    if args.cmd == "pack":
        fmt = args.format
        if fmt == "auto":
            fmt = "memvid" if try_memvid_available() else "tar-gzip"

        result = None
        if fmt == "memvid":
            result = pack_memvid(args.src, args.out)
            if result is None or not result.get("ok"):
                # Graceful fallback
                result = pack_tar_gzip(args.src, args.out)
        else:
            result = pack_tar_gzip(args.src, args.out)

        emit(result, use_json)
        return 0 if result.get("ok") else 1

    elif args.cmd == "restore":
        result = restore_tar_gzip(args.src, args.out)
        emit(result, use_json)
        return 0 if result.get("ok") else 1

    elif args.cmd == "verify":
        result = verify_backup(args.src)
        emit(result, use_json)
        return 0 if result.get("ok") else 1

    return 2


if __name__ == "__main__":
    sys.exit(main())
