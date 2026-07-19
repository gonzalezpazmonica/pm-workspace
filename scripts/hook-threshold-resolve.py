#!/usr/bin/env python3
"""hook-threshold-resolve.py — SE-268 Slice 3.
Resolve effective threshold for a hook given domain context.
Usage:
  python3 scripts/hook-threshold-resolve.py --domain salud --hook code-complexity
  python3 scripts/hook-threshold-resolve.py --domain experimental --hook test-coverage
Output: JSON with effective threshold, severity, and audit info.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml  # type: ignore

ROOT = Path(os.environ.get("SAVIA_ROOT", os.getcwd()))
CONFIG_PATH = ROOT / "config" / "hook-thresholds.yaml"
AUDIT_PATH = ROOT / "bridge" / "control-plane" / "hook-decisions.jsonl"


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_config(path: Path) -> dict:
    if not path.exists():
        print(json.dumps({"error": f"config not found: {path}", "effective": "estandar"}))
        sys.exit(1)
    with open(path) as f:
        return yaml.safe_load(f)


def resolve(config: dict, domain: str, hook_name: str,
            requested_exigency: str | None = None) -> dict:
    """Resolve effective threshold for (domain, hook)."""

    # Gate: non-modulable hooks can never be relaxed (AC-3.3)
    if hook_name in config.get("non_modulable", []):
        if requested_exigency and requested_exigency != "conservador":
            audit_log(domain, hook_name, "conservador",
                      f"non_modulable: override {requested_exigency}→conservador rejected",
                      blocked=True)
            return {
                "hook": hook_name,
                "domain": domain,
                "effective": "conservador",
                "severity_block": "critical",
                "blocked_override": True,
                "reason": "linea_roja: non-modulable hook (hiperdirecta, S1)",
            }
        # Non-modulable hooks always at conservador
        return {
            "hook": hook_name,
            "domain": domain,
            "effective": "conservador",
            "severity_block": "critical",
            "blocked_override": False,
            "reason": "linea_roja: non-modulable hook (hiperdirecta)",
        }

    # Determine default exigency for domain
    domains = config.get("domains", {})
    domain_config = domains.get(domain, {})
    default_exigency = domain_config.get("default", "estandar")
    effective = requested_exigency or default_exigency

    # Validate effective is one of the three levels
    if effective not in ("conservador", "estandar", "experimental"):
        effective = "estandar"

    # Get parametric hook thresholds
    parametric = config.get("parametric_hooks", {})
    hook_config = parametric.get(hook_name)
    if not hook_config:
        # Unknown hook: use estandar
        audit_log(domain, hook_name, "estandar",
                  "hook not in parametric_hooks, defaulting to estandar")
        return {
            "hook": hook_name,
            "domain": domain,
            "effective": "estandar",
            "severity_block": "high",
            "reason": "hook not configured, default estandar",
            "params": {},
        }

    thresholds = hook_config.get(effective, hook_config.get("estandar", {}))
    block_severity = thresholds.get("block_severity", "high")

    params = {k: v for k, v in thresholds.items() if k != "block_severity"}

    # Audit
    override_note = ""
    if requested_exigency and requested_exigency != default_exigency:
        override_note = f"override: requested={requested_exigency}, default={default_exigency}"

    audit_log(domain, hook_name, effective, override_note or f"default={default_exigency}")

    return {
        "hook": hook_name,
        "domain": domain,
        "effective": effective,
        "severity_block": block_severity,
        "default_exigency": default_exigency,
        "requested_exigency": requested_exigency,
        "params": params,
        "blocked_override": False,
    }


def audit_log(domain: str, hook: str, exigency: str,
              reason: str = "", blocked: bool = False):
    """Append decision to audit log."""
    config = load_config(CONFIG_PATH) if CONFIG_PATH.exists() else {}
    audit_cfg = config.get("audit", {})
    if not audit_cfg.get("enabled", True):
        return

    log_path = Path(audit_cfg.get("log_path", str(AUDIT_PATH)))
    if not log_path.is_absolute():
        log_path = ROOT / log_path

    log_path.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "ts": _now_iso(),
        "domain": domain,
        "hook": hook,
        "exigency": exigency,
        "reason": reason,
        "blocked": blocked,
    }
    with open(log_path, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def main():
    p = argparse.ArgumentParser(description="SE-268 Hook Threshold Resolver")
    p.add_argument("--domain", required=True, help="Domain context (salud, legal, desarrollo, etc.)")
    p.add_argument("--hook", required=True, help="Hook name (code-complexity, test-coverage, etc.)")
    p.add_argument("--exigency", default=None,
                   help="Requested exigency override (conservador|estandar|experimental)")
    p.add_argument("--config", default=str(CONFIG_PATH), help="Path to hook-thresholds.yaml")
    args = p.parse_args()

    config = load_config(Path(args.config))
    result = resolve(config, args.domain, args.hook, args.exigency)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    if result.get("blocked_override"):
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
