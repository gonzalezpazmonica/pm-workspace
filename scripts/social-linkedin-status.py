#!/usr/bin/env python3
"""social-linkedin-status.py — SE-385 §22/§43: permission discovery + almacén local.
Sin red: reporta capabilities declaradas y estado del almacén local.
"""
from __future__ import annotations

import json
import os
import sys

STORE = os.path.expanduser("~/.savia/social/linkedin")
PIN = "li-dma-data-portability-2026-08 (verificado 2026-09-05)"


def main() -> int:
    caps = {
        "read_profile": "UNKNOWN",
        "import_portability": "REQUIRES_APPROVAL",
        "import_manual": "SUPPORTED",
        "read_posts": "SUPPORTED",
        "draft_local": "SUPPORTED",
        "publish_post": "NOT_GRANTED",
        "edit_post": "NOT_GRANTED",
        "delete_post": "NOT_GRANTED",
        "analytics": "NOT_AVAILABLE",
    }
    n_artifacts = 0
    last_sync = "nunca"
    manifest_path = os.path.join(STORE, "manifest.json")
    if os.path.exists(manifest_path):
        try:
            m = json.load(open(manifest_path, encoding="utf-8"))
            last_sync = m.get("last_sync", "nunca")
        except json.JSONDecodeError:
            pass
    norm = os.path.join(STORE, "normalized", "artifacts.jsonl")
    if os.path.exists(norm):
        with open(norm, encoding="utf-8") as f:
            n_artifacts = sum(1 for l in f if l.strip())

    print("LinkedIn (provider: linkedin)")
    print("Authenticated: no (OAuth MVP2; producto DMA requiere OAuth Token Generator, EEA/CH)")
    print("Documentation pin:", PIN)
    print("Capabilities:")
    for k, v in caps.items():
        print(f"  {k}: {v}")
    print(f"Last sync: {last_sync}")
    print(f"Local artifacts: {n_artifacts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
