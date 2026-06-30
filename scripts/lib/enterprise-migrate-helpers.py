#!/usr/bin/env python3
"""
enterprise-migrate-helpers.py — Python backend for enterprise-migrate.sh
SPEC: SPEC-SE-010 Migration Path & Backward Compat
"""

import json
import os
import shutil
import sys
from datetime import datetime, timezone


def cmd_check(project_dir: str, manifest_path: str) -> None:
    checks: dict = {}

    checks["manifest_exists"] = os.path.isfile(manifest_path)
    checks["claude_dir"] = os.path.isdir(os.path.join(project_dir, ".claude"))
    checks["enterprise_hooks"] = os.path.isdir(
        os.path.join(project_dir, ".claude", "enterprise", "hooks")
    )
    checks["scripts_enterprise"] = os.path.isdir(
        os.path.join(project_dir, "scripts", "enterprise")
    )
    checks["tenant_resolver"] = os.path.isfile(
        os.path.join(project_dir, ".claude", "enterprise", "hooks", "tenant-resolver.sh")
    )
    checks["isolation_gate"] = os.path.isfile(
        os.path.join(
            project_dir, ".claude", "enterprise", "hooks", "tenant-isolation-gate.sh"
        )
    )
    checks["egress_guard"] = os.path.isfile(
        os.path.join(
            project_dir, ".claude", "enterprise", "hooks", "network-egress-guard.sh"
        )
    )

    manifest_valid = False
    modules_count = 0
    if checks["manifest_exists"]:
        try:
            with open(manifest_path) as f:
                d = json.load(f)
            manifest_valid = True
            modules_count = len(d.get("modules", {}))
        except Exception:
            pass
    checks["manifest_valid"] = manifest_valid
    checks["modules_count"] = modules_count
    checks["python3_available"] = shutil.which("python3") is not None

    required = [
        "manifest_exists",
        "claude_dir",
        "enterprise_hooks",
        "tenant_resolver",
        "isolation_gate",
        "manifest_valid",
    ]
    compatible = all(checks.get(k, False) for k in required)

    warnings = []
    if not checks.get("python3_available"):
        warnings.append("python3 not found -- some features will be limited")
    if not checks.get("egress_guard"):
        warnings.append(
            "network-egress-guard.sh missing -- sovereign mode unavailable"
        )

    result = {
        "compatible": compatible,
        "checks": checks,
        "required_checks": required,
        "warnings": warnings,
    }
    print(json.dumps(result, indent=2))


def cmd_status(manifest_path: str) -> None:
    with open(manifest_path) as f:
        d = json.load(f)
    modules = d.get("modules", {})
    result: dict = {
        "modules": {},
        "enabled_count": 0,
        "total_count": len(modules),
    }
    for name, info in modules.items():
        enabled = info.get("enabled", False)
        result["modules"][name] = {
            "enabled": enabled,
            "spec": info.get("spec", ""),
            "description": info.get("description", ""),
        }
        if enabled:
            result["enabled_count"] += 1
    print(json.dumps(result, indent=2))


def cmd_enable(manifest_path: str, module: str) -> None:
    with open(manifest_path) as f:
        d = json.load(f)
    modules = d.get("modules", {})
    if module not in modules:
        print(
            json.dumps(
                {
                    "error": f"Module '{module}' not found in manifest.json",
                    "available": list(modules.keys()),
                }
            )
        )
        sys.exit(1)
    was_enabled = modules[module].get("enabled", False)
    modules[module]["enabled"] = True
    d["modules"] = modules
    with open(manifest_path, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    print(
        json.dumps(
            {
                "module": module,
                "enabled": True,
                "was_already_enabled": was_enabled,
                "spec": modules[module].get("spec", ""),
                "manifest": manifest_path,
            },
            indent=2,
        )
    )


def cmd_help() -> None:
    result = {
        "usage": "enterprise-migrate.sh <subcommand> [args]",
        "subcommands": {
            "check": "Validate Core installation compatibility",
            "enable MODULE": "Activate an Enterprise module",
            "disable MODULE": "Deactivate a module with rollback",
            "status": "List state of all modules",
        },
    }
    print(json.dumps(result, indent=2))


def main() -> None:
    if len(sys.argv) < 2:
        cmd_help()
        return

    subcmd = sys.argv[1]

    if subcmd == "check":
        project_dir = sys.argv[2]
        manifest_path = sys.argv[3]
        cmd_check(project_dir, manifest_path)
    elif subcmd == "status":
        manifest_path = sys.argv[2]
        cmd_status(manifest_path)
    elif subcmd == "enable":
        manifest_path = sys.argv[2]
        module = sys.argv[3]
        cmd_enable(manifest_path, module)
    elif subcmd == "help":
        cmd_help()
    else:
        print(json.dumps({"error": f"Unknown subcommand: {subcmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
