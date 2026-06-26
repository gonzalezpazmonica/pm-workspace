#!/usr/bin/env python3
"""
context-capability-metadata.py — SE-221 Slice 3 — Capability metadata extractor

Para un fichero dado, produce un objeto JSON con los campos de metadatos.
Spec: docs/propuestas/SE-221-inverted-security-patterns-as-context-engineering.md (AC-12..AC-14)
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List


def find_workspace(start: str) -> str:
    p = Path(start).resolve()
    while p != p.parent:
        if (p / ".git").exists() or (p / "AGENTS.md").exists():
            return str(p)
        p = p.parent
    return start


def resolve_tier(file_path: str, ws: str) -> str:
    tag_script = Path(ws) / "scripts" / "context-origin-tag.sh"
    if not tag_script.exists():
        return "N4b-on-demand"
    try:
        result = subprocess.run(
            ["bash", str(tag_script), file_path],
            capture_output=True, text=True, timeout=5
        )
        tier = result.stdout.strip()
        return tier if tier else "N4b-on-demand"
    except Exception:
        return "N4b-on-demand"


def extract_frontmatter(text: str) -> Dict[str, Any]:
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return {}
    fm_text = m.group(1)
    result: Dict[str, Any] = {}
    lines = fm_text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        kv = re.match(r"^(\w[\w_-]*):\s*(.*)$", line)
        if kv:
            key = kv.group(1)
            val = kv.group(2).strip()
            if val.startswith("["):
                items = [
                    x.strip().strip('"').strip("'")
                    for x in val.strip("[]").split(",")
                    if x.strip().strip('"').strip("'")
                ]
                result[key] = items
            elif val == "":
                items = []
                j = i + 1
                while j < len(lines):
                    ml = re.match(r"^\s*-\s*(.+)$", lines[j])
                    if ml:
                        v = ml.group(1).strip().strip('"').strip("'")
                        if v:
                            items.append(v)
                        j += 1
                    elif re.match(r"^\s*$", lines[j]):
                        j += 1
                    else:
                        break
                if items:
                    result[key] = items
                    i = j - 1
                else:
                    result[key] = val
            else:
                result[key] = val.strip('"').strip("'")
        i += 1
    return result


def extract_audience(text: str) -> List[str]:
    fm = extract_frontmatter(text)
    raw = fm.get("audience") or fm.get("target_audience")
    if raw is None:
        return ["all"]
    if isinstance(raw, list):
        out = [str(x).strip() for x in raw if str(x).strip()]
        return out if out else ["all"]
    val = str(raw).strip()
    return [val] if val else ["all"]


CROSS_REF_PATTERN = re.compile(r"\b(SPEC-\d+|SE-\d+|Rule\s+#\d+)\b")


def extract_cross_concept_refs(text: str) -> List[str]:
    matches = CROSS_REF_PATTERN.findall(text)
    seen: set = set()
    out: List[str] = []
    for m in matches:
        norm = re.sub(r"\s+", " ", m.strip())
        if norm not in seen:
            seen.add(norm)
            out.append(norm)
    return out


def file_hash_short(text: str) -> str:
    h = hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()
    return "sha256:" + h[:8]


def estimate_tokens(text: str) -> int:
    return max(0, len(text.encode("utf-8", errors="replace")) // 4)


def emit_kg_edges(ws: str) -> bool:
    kg_script = Path(ws) / "scripts" / "knowledge-graph.sh"
    if not kg_script.exists():
        return False
    try:
        subprocess.run(
            ["bash", str(kg_script), "import-audience"],
            input="",
            capture_output=True, text=True, timeout=10
        )
        return True
    except Exception:
        return False


def build_metadata(file_path: str, ws: str, emit_kg: bool = False) -> Dict[str, Any]:
    abs_path = Path(file_path)
    if not abs_path.is_absolute():
        abs_path = Path(ws) / file_path
    abs_path = abs_path.resolve()

    try:
        text = abs_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        text = ""

    rel = os.path.relpath(str(abs_path), ws) if text else str(file_path)
    tier = resolve_tier(str(abs_path), ws)
    audience = extract_audience(text)
    cross_refs = extract_cross_concept_refs(text)
    size_tokens = estimate_tokens(text)
    h = file_hash_short(text) if text else "sha256:00000000"
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    meta: Dict[str, Any] = {
        "origin": rel,
        "tier": tier,
        "audience": audience,
        "size_tokens": size_tokens,
        "hash": h,
        "last_loaded": now,
        "cross_concept_refs": cross_refs,
    }

    if emit_kg:
        meta["kg_emitted"] = emit_kg_edges(ws)

    return meta


def main() -> int:
    parser = argparse.ArgumentParser(description="Capability metadata for a context fragment (SE-221).")
    parser.add_argument("--file", required=True)
    parser.add_argument("--workspace", default=None)
    parser.add_argument("--emit-kg", action="store_true", default=False)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    ws = (
        args.workspace
        or os.environ.get("SAVIA_WORKSPACE_DIR")
        or find_workspace(os.getcwd())
    )

    meta = build_metadata(args.file, ws, emit_kg=args.emit_kg)
    print(json.dumps(meta, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
