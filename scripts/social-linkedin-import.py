#!/usr/bin/env python3
"""social-linkedin-import.py — SE-385 MVP1: import del export oficial de LinkedIn.

Convierte el ZIP de export del propio miembro en SocialArtifacts neutral
model (JSONL), con provenance, dedupe idempotente y retention metadata.
Local-only: ~/.savia/social/linkedin/. Sin red. CRIT-001.
"""
from __future__ import annotations

import argparse
import csv
import datetime
import hashlib
import io
import json
import os
import sys
import zipfile

STORE = os.path.expanduser("~/.savia/social/linkedin")


def sha(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8", errors="replace")).hexdigest()


def now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def provenance(source_file: str, source_hash: str) -> dict:
    return {
        "provider": "linkedin",
        "acquisition": "manual_export",
        "acquired_at": now_iso(),
        "authenticated_subject": "self",
        "source_file": source_file,
        "source_hash": "sha256:" + source_hash,
        "trust": "untrusted",
    }


def rows_from_zip(zf: zipfile.ZipFile, member: str):
    with zf.open(member) as f:
        reader = csv.DictReader(io.TextIOWrapper(f, encoding="utf-8", errors="replace"))
        for row in reader:
            yield row


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--zip", required=True, help="ruta al export ZIP de LinkedIn")
    ap.add_argument("--store", default=STORE)
    args = ap.parse_args()

    if not os.path.exists(args.zip):
        print("ERROR: export no encontrado:", args.zip)
        return 1

    raw_dir = os.path.join(args.store, "raw")
    norm_dir = os.path.join(args.store, "normalized")
    receipts_dir = os.path.join(args.store, "receipts")
    for d in (raw_dir, norm_dir, receipts_dir):
        os.makedirs(d, exist_ok=True)

    # RAW: copia literal del export (idempotente por hash)
    zip_bytes = open(args.zip, "rb").read()
    zip_hash = hashlib.sha256(zip_bytes).hexdigest()
    raw_copy = os.path.join(raw_dir, f"export-{zip_hash[:12]}.zip")
    if not os.path.exists(raw_copy):
        with open(raw_copy, "wb") as f:
            f.write(zip_bytes)

    # Índice de dedupe: claves ya normalizadas
    seen = set()
    norm_path = os.path.join(norm_dir, "artifacts.jsonl")
    if os.path.exists(norm_path):
        for line in open(norm_path, encoding="utf-8"):
            try:
                a = json.loads(line)
                seen.add(a.get("dedupe_key", ""))
            except json.JSONDecodeError:
                continue

    created = updated = skipped = 0
    artifact_batches = []

    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        members = {os.path.basename(n): n for n in zf.namelist()}
        # Posts (Share.csv) — artifact_type=post, SELF_AUTHORED
        for src_name, atype, text_cols in (
            ("Share.csv", "post", ["ShareCommentary", "ShareMediaDescription"]),
            ("Articles.csv", "article", ["ArticleTitle", "ArticleDescription"]),
            ("Comments.csv", "comment", ["Comment"]),
        ):
            key = next((v for k, v in members.items() if k == src_name), None)
            if not key:
                continue
            for row in rows_from_zip(zf, key):
                text = " ".join((row.get(c) or "").strip() for c in text_cols).strip()
                if not text:
                    continue
                pid = row.get("ShareLink") or row.get("Permalink") or row.get("Url") or sha(text)[:16]
                dedupe = f"linkedin:{atype}:{sha(pid + text)[:24]}"
                if dedupe in seen:
                    skipped += 1
                    continue
                artifact = {
                    "id": f"linkedin:{atype}:{sha(dedupe)[:20]}",
                    "provider": "linkedin",
                    "provider_id": pid,
                    "artifact_type": atype,
                    "owner": "self",
                    "authored": "SELF_AUTHORED" if atype in ("post", "article") else "MIXED",
                    "created_at": row.get("Date") or row.get("CreatedAt") or row.get("Posted At") or "",
                    "imported_at": now_iso(),
                    "source": "manual_export",
                    "visibility": row.get("Visibility") or "unknown",
                    "text": text,
                    "title": (row.get("ArticleTitle") or "").strip(),
                    "canonical_url": row.get("ShareLink") or row.get("Permalink") or row.get("Url") or "",
                    "language": row.get("Language") or "",
                    "tags": [],
                    "concepts": [],
                    "origin": provenance(src_name, sha(text)),
                    "retention_policy": "user_owned_source",
                    "raw_reference": "raw/" + os.path.basename(raw_copy),
                    "dedupe_key": dedupe,
                }
                artifact_batches.append(artifact)
                seen.add(dedupe)
                created += 1

    if artifact_batches:
        with open(norm_path, "a", encoding="utf-8") as f:
            for a in artifact_batches:
                f.write(json.dumps(a, ensure_ascii=False, sort_keys=True) + "\n")

    # Manifest
    manifest_path = os.path.join(args.store, "manifest.json")
    manifest = {"provider": "linkedin", "last_sync": now_iso(), "source": "manual_export",
                "exports": []}
    if os.path.exists(manifest_path):
        try:
            manifest = json.load(open(manifest_path, encoding="utf-8"))
            manifest["last_sync"] = now_iso()
        except json.JSONDecodeError:
            pass
    manifest.setdefault("exports", []).append(
        {"file": os.path.basename(raw_copy), "sha256": "sha256:" + zip_hash,
         "imported_at": now_iso(), "created": created, "skipped_duplicates": skipped})

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    receipt = {"provider": "linkedin", "operation": "import", "subject": "self",
               "source_sha": "sha256:" + zip_hash, "created": created,
               "skipped_duplicates": skipped, "timestamp": now_iso(), "result": "success"}
    with open(os.path.join(receipts_dir, f"import-{zip_hash[:12]}.json"), "w", encoding="utf-8") as f:
        json.dump(receipt, f, indent=2)

    print(f"import: {created} creados, {skipped} duplicados omitidos → {norm_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
