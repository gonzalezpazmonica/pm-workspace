#!/usr/bin/env python3
"""social-linkedin-import.py — SE-385 MVP1: import del export oficial de LinkedIn.

Convierte el ZIP de export del propio miembro en SocialArtifacts neutral
model (JSONL), con provenance, dedupe idempotente y retention metadata.
Local-only: ~/.savia/social/linkedin/ (o $SOCIAL_STORE). Sin red. CRIT-001.

Reconoce los nombres de la exportación oficial: Shares.csv (y Shares_<id>.csv de
la exportación completa; Share.csv por compatibilidad), Comments.csv /
Comments_<id>.csv y Articles.csv. Nunca extrae el ZIP a disco: lee los CSV en
memoria por nombre base, así que rutas maliciosas (../) no escriben nada.

Exit codes: 0 ok · 1 ZIP inexistente o inválido · 2 uso incorrecto o almacén
dentro de un repositorio git (la copia raw lleva PII de terceros).
"""
from __future__ import annotations

import argparse
import csv
import datetime
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import zipfile

STORE = os.environ.get("SOCIAL_STORE") or os.path.expanduser("~/.savia/social/linkedin")

# Nombre base (minúsculas) -> (artifact_type, columnas de texto, dialecto)
# Comments.csv de LinkedIn escapa comillas con \" en vez de "" (RFC 4180).
SOURCES = (
    (re.compile(r"^shares?(_\d+)?\.csv$"), "post", ["ShareCommentary", "ShareMediaDescription"], False),
    (re.compile(r"^articles(_\d+)?\.csv$"), "article", ["ArticleTitle", "ArticleDescription"], False),
    (re.compile(r"^comments(_\d+)?\.csv$"), "comment", ["Message", "Comment"], True),
)

csv.field_size_limit(min(sys.maxsize, 2**31 - 1))


def err(*a) -> None:
    print("ERROR:", *a, file=sys.stderr)


def inside_git_repo(path: str) -> str:
    """Raíz del work tree git que contendría `path` ("" si ninguno)."""
    d = os.path.abspath(path)
    while not os.path.isdir(d):
        d = os.path.dirname(d)
    try:
        r = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError) as e:
        print(f"AVISO: no se pudo comprobar si {d} está en un repo git ({e})", file=sys.stderr)
        return ""
    return r.stdout.strip() if r.returncode == 0 else ""


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


def rows_from_zip(zf: zipfile.ZipFile, member: str, backslash_escape: bool):
    # utf-8-sig quita el BOM; newline="" conserva saltos de línea dentro de campos.
    with zf.open(member) as f:
        text = io.TextIOWrapper(f, encoding="utf-8-sig", errors="replace", newline="")
        kw = {"escapechar": "\\"} if backslash_escape else {}
        for row in csv.DictReader(text, **kw):
            yield {k: v for k, v in row.items() if k is not None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--zip", required=True, help="ruta al export ZIP de LinkedIn")
    ap.add_argument("--store", default=STORE)
    args = ap.parse_args()

    if not os.path.isfile(args.zip):
        err("export no encontrado:", args.zip)
        return 1

    repo = inside_git_repo(args.store)
    if repo:
        err(f"el almacén {args.store} está dentro del repositorio git {repo}; "
            "el export contiene PII de terceros (contactos, mensajes) y no puede "
            "quedar en ficheros versionables. Usa ~/.savia/social/linkedin o SOCIAL_STORE.")
        return 2

    zip_bytes = open(args.zip, "rb").read()
    if not zipfile.is_zipfile(io.BytesIO(zip_bytes)):
        err("no es un ZIP válido:", args.zip)
        return 1

    raw_dir = os.path.join(args.store, "raw")
    norm_dir = os.path.join(args.store, "normalized")
    receipts_dir = os.path.join(args.store, "receipts")
    os.makedirs(args.store, mode=0o700, exist_ok=True)
    os.chmod(args.store, 0o700)
    for d in (raw_dir, norm_dir, receipts_dir):
        os.makedirs(d, mode=0o700, exist_ok=True)

    # RAW: copia literal del export (idempotente por hash), solo legible por la propietaria
    zip_hash = hashlib.sha256(zip_bytes).hexdigest()
    raw_copy = os.path.join(raw_dir, f"export-{zip_hash[:12]}.zip")
    if not os.path.exists(raw_copy):
        fd = os.open(raw_copy, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as f:
            f.write(zip_bytes)

    # Índice de dedupe: claves ya normalizadas
    seen = set()
    norm_path = os.path.join(norm_dir, "artifacts.jsonl")
    if os.path.exists(norm_path):
        bad = 0
        for line in open(norm_path, encoding="utf-8"):
            try:
                a = json.loads(line)
            except json.JSONDecodeError:
                a = None
            if isinstance(a, dict) and a.get("dedupe_key"):
                seen.add(a["dedupe_key"])
            elif line.strip():
                bad += 1
        if bad:
            print(f"AVISO: {bad} líneas inválidas en {norm_path} ignoradas para el dedupe",
                  file=sys.stderr)

    created = skipped = 0
    artifact_batches = []

    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        # Solo lectura en memoria por nombre base: nada se extrae a disco (zip-slip inerte).
        members = sorted(n for n in zf.namelist() if not n.endswith("/"))
        for pattern, atype, text_cols, backslash in SOURCES:
            for key in (m for m in members if pattern.match(os.path.basename(m).lower())):
                src_name = os.path.basename(key)
                for row in rows_from_zip(zf, key, backslash):
                    text = " ".join((row.get(c) or "").strip() for c in text_cols).strip()
                    text = text.replace("\r\n", "\n").replace("\r", "\n")
                    if not text:
                        continue
                    url = (row.get("ShareLink") or row.get("Link") or row.get("Permalink")
                           or row.get("Url") or "")
                    pid = url or sha(text)[:16]
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
                        "canonical_url": url,
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
            loaded = json.load(open(manifest_path, encoding="utf-8"))
            if not isinstance(loaded, dict):
                raise ValueError("no es un objeto JSON")
            manifest = loaded
            manifest["last_sync"] = now_iso()
        except ValueError as e:  # JSONDecodeError es subclase de ValueError
            backup = f"{manifest_path}.corrupt-{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
            os.replace(manifest_path, backup)
            print(f"AVISO: manifest.json corrupto ({e}); apartado en {backup} y regenerado",
                  file=sys.stderr)
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
