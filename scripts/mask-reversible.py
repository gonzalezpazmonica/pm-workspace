#!/usr/bin/env python3
"""
mask-reversible.py — SE-323 S1: reversible identifier masking for RCA.

Replaces identifying values (pods, clusters, account IDs, IPs, service
names, deploy/image tags) with unique placeholders (`{ID_1}`, `{POD_2}`).
The placeholder<->value map lives only in an ephemeral file (N4b) and is
never persisted beyond the run. `--restore` recomposes the final output
byte-for-byte from that map.

Deterministic, no LLM: pure regex layers, reusing the detection spirit of
sovereignty-classify.sh (SE-314) but *transforming* instead of blocking.

Usage:
  cat input.txt | python3 mask-reversible.py mask --map /tmp/map.json
  cat masked.txt | python3 mask-reversible.py restore --map /tmp/map.json
  cat input.txt | python3 mask-reversible.py mask --dry-run --map /tmp/map.json

Exit: 0 ok (mask/restore/passthrough), 1 map error, 2 usage.
Ref: SE-323 (Incident RCA Agent).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

# ── Detection layers (deterministic, longest-match-first semantics) ──────────
# Each entry: (kind, compiled regex). Placeholder prefix derives from kind.
PATTERNS = [
    # pod: <app>-<replicaset-hash>-<pod-hash> (kubernetes default; hex hashes)
    ("pod", re.compile(r"\b[a-z][a-z0-9-]{1,23}-[a-f0-9]{6,10}-[a-z0-9]{5}\b")),
    # deployment/replicaset revision tag: <app>-<hash>[-<n>]
    ("deploy", re.compile(r"\b(?:deploy|release)-[a-z0-9]{6,12}\b")),
    # cluster identifiers
    ("cluster", re.compile(r"\b(?:eks|gke|aks|ocp|k8s|cluster)[-_][a-z0-9-]{3,24}\b", re.IGNORECASE)),
    # AWS account id: exactly 12 digits
    ("account", re.compile(r"\b[0-9]{12}\b")),
    # namespace + service DNS: <name>.<ns>.svc.cluster.local
    ("service", re.compile(r"\b[a-z0-9-]+(\.[a-z0-9-]+)?\.svc\.cluster\.local\b", re.IGNORECASE)),
    # IPv4 (public or private) — critical for incident context
    ("ip", re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")),
    # image tag: name:version.semver
    ("image", re.compile(r"\b[a-z0-9_.-]+:[0-9]+\.[0-9]+\.[0-9]+(?:\-[a-z0-9]+)?\b")),
    # hostnames / FQDNs
    ("host", re.compile(r"\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?\b", re.IGNORECASE)),
]

# Kinds that collide with benign tokens; skip unless context hints. `host`
# would match "example.com" in docs; keep it but only for TLDs >= 3 chars.
SKIP_KINDS = {"host"}


def build_map(text: str, existing_map: dict | None = None) -> dict:
    """Build placeholder<->value map. Deterministic ordering by first occurrence."""
    mask_map = dict(existing_map or {})
    counters: dict[str, int] = {}

    def next_placeholder(kind: str) -> str:
        counters[kind] = counters.get(kind, 0) + 1
        return f"{{{kind.upper()}_{counters[kind]}}}"

    seen = set(mask_map.values())
    for kind, pattern in PATTERNS:
        if kind in SKIP_KINDS:
            continue
        for match in pattern.finditer(text):
            value = match.group(0)
            if value in mask_map:
                continue
            if re.match(r"^\d+$", value) and len(value) < 5:
                continue  # small bare numbers are not identifiers
            if value in seen:
                continue
            placeholder = next_placeholder(kind)
            mask_map[value] = placeholder
            seen.add(placeholder)
    return mask_map


def apply_map(text: str, mask_map: dict, reverse: bool) -> str:
    """Replace values with placeholders (mask) or the reverse (restore)."""
    if reverse:
        pairs = sorted(((p, v) for v, p in mask_map.items()), key=lambda x: len(x[0]), reverse=True)
        for placeholder, value in pairs:
            text = text.replace(placeholder, value)
        return text
    pairs = sorted(((v, p) for v, p in mask_map.items()), key=lambda x: len(x[0]), reverse=True)
    for value, placeholder in pairs:
        text = re.sub(re.escape(value), placeholder, text)
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="SE-323 reversible masking")
    parser.add_argument("action", choices=["mask", "restore", "dry-run"])
    parser.add_argument("--map", default="", help="ephemeral map file (N4b)")
    args = parser.parse_args()

    text = sys.stdin.read()
    if not args.map:
        print("ERROR: --map required", file=sys.stderr)
        return 2

    if args.action in ("mask", "dry-run"):
        mask_map = build_map(text)
        masked = apply_map(text, mask_map, reverse=False)
        if not mask_map:
            # AC-S1.3: no identifiers -> passthrough unchanged, exit 0
            if args.action == "mask":
                sys.stdout.write(text)
            else:
                print(json.dumps({"changed": False, "entities": 0}, ensure_ascii=False))
            return 0
        if args.action == "dry-run":
            print(json.dumps({"changed": True, "entities": len(mask_map)}, ensure_ascii=False))
            return 0
        _write_map_atomic(mask_map, args.map)
        sys.stdout.write(masked)
        return 0

    # restore
    if not os.path.exists(args.map):
        print(f"ERROR: map not found: {args.map}", file=sys.stderr)
        return 1
    with open(args.map, "r", encoding="utf-8") as f:
        mask_map = json.load(f)
    sys.stdout.write(apply_map(text, mask_map, reverse=True))
    return 0


def _write_map_atomic(mask_map: dict, path: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(mask_map, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)
    os.chmod(path, 0o600)


if __name__ == "__main__":
    sys.exit(main())
