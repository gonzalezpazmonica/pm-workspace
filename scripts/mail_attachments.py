"""SPEC-M01: Email attachments dispatcher to digest agents.

Processes files already downloaded in the mail attachments dir and emits
manifests for downstream Excel/PDF/Word/PPTX digest agents to consume.
Idempotent: skips files whose manifest already exists.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path


SUPPORTED_EXTS = {
    ".xlsx": "excel",
    ".xls": "excel",
    ".csv": "excel",
    ".pdf": "pdf",
    ".docx": "word",
    ".doc": "word",
    ".pptx": "pptx",
    ".ppt": "pptx",
}


def slugify(s):
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s[:80]


def file_hash(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def write_manifest(file_path, digest_type, manifest_dir):
    mf = {
        "file": str(file_path),
        "digest_type": digest_type,
        "detected_at": datetime.now().isoformat(),
        "sha256": file_hash(file_path),
    }
    manifest_dir.mkdir(parents=True, exist_ok=True)
    out = manifest_dir / (slugify(file_path.stem) + ".manifest.json")
    out.write_text(json.dumps(mf, ensure_ascii=False, indent=2), encoding="utf-8")
    return out


def main():
    ap = argparse.ArgumentParser(description="Mail attachments dispatcher")
    ap.add_argument("--download-dir", default=os.environ.get("SAVIA_MAIL_ATTACHMENTS_DIR", str(Path.home() / ".savia" / "mail-attachments")))
    ap.add_argument("--manifest-dir", default=str(Path.home() / ".savia" / "mail-attachments-manifests"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    download_dir = Path(args.download_dir)
    manifest_dir = Path(args.manifest_dir)
    download_dir.mkdir(parents=True, exist_ok=True)
    manifest_dir.mkdir(parents=True, exist_ok=True)

    dispatched = 0
    skipped = 0
    unsupported = 0

    for entry in download_dir.iterdir():
        if not entry.is_file():
            continue
        ext = entry.suffix.lower()
        if ext not in SUPPORTED_EXTS:
            unsupported += 1
            continue
        mf_path = manifest_dir / (slugify(entry.stem) + ".manifest.json")
        if mf_path.exists():
            skipped += 1
            continue
        digest_type = SUPPORTED_EXTS[ext]
        if args.dry_run:
            print("  DRY: " + entry.name + " -> " + digest_type)
            dispatched += 1
            continue
        out = write_manifest(entry, digest_type, manifest_dir)
        print("[attach] " + entry.name + " -> " + digest_type + " (" + out.name + ")", file=sys.stderr)
        dispatched += 1

    print("[attach] dispatched=" + str(dispatched) + " skipped=" + str(skipped) + " unsupported=" + str(unsupported), file=sys.stderr)


if __name__ == "__main__":
    main()
