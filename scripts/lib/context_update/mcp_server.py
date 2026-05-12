"""mcp_server.py — MCP server for /context-update pipeline tools.

Exposes the pipeline phases as MCP tools callable from OpenCode or Claude Code.

Tools:
  - context_update_discover   (F0)
  - context_update_f1_run     (F1)
  - context_update_f2_run     (F2)
  - context_update_f3_consolidate (F3)
  - context_update_apply      (F4)
  - context_update_status     (read run store / trend)

Usage:
  python3 -m scripts.lib.context_update.mcp_server
  OR: python3 scripts/lib/context_update/mcp_server.py

Compatible with OpenCode MCP stdio protocol.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 MCP.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

# Ensure scripts/ is on sys.path when run directly
_HERE = Path(__file__).resolve().parent   # scripts/lib/context_update/
_SCRIPTS = _HERE.parent.parent            # scripts/
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from lib.context_update import discovery, store
from lib.context_update import f1 as f1_runner
from lib.context_update import f2 as f2_runner
from lib.context_update import f3 as f3_consolidator
from lib.context_update import f4 as f4_apply


# ---------------------------------------------------------------------------
# MCP wire protocol helpers (stdio, JSON-RPC 2.0 subset)
# ---------------------------------------------------------------------------

def _send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def _error(id_: Any, code: int, message: str, data: Any = None) -> dict:
    err: dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    return {"jsonrpc": "2.0", "id": id_, "error": err}


def _ok(id_: Any, result: Any) -> dict:
    return {"jsonrpc": "2.0", "id": id_, "result": result}


# ---------------------------------------------------------------------------
# Tool registry
# ---------------------------------------------------------------------------

def _tool_discover(params: dict) -> dict:
    """F0: Discover files matching scope/slug."""
    scope = params.get("scope", "all")
    slug  = params.get("slug")
    manifest = discovery.discover(scope=scope, slug=slug)
    return {
        "files_count":     len(manifest.get("files", [])),
        "workspace_root":  str(manifest.get("workspace_root", "")),
        "scope":           scope,
        "slug":            slug,
        "manifest":        manifest,
    }


def _tool_f1_run(params: dict) -> dict:
    """F1: Run all 8 structural jobs."""
    scope    = params.get("scope", "all")
    slug     = params.get("slug")
    run_id   = params.get("run_id") or store.new_run_id()
    dry_run  = params.get("dry_run", True)

    manifest = discovery.discover(scope=scope, slug=slug)
    files    = manifest.get("files", [])
    f1_dir   = store.run_dir(run_id) / "F1" if not dry_run else None
    result   = f1_runner.run_all(files, store_dir=f1_dir)

    if not dry_run:
        store.write_json(run_id, "F0", "discovery", manifest)

    return {
        "run_id":  run_id,
        "summary": result["summary"],
        "findings_sample": result["findings"][:20],
    }


def _tool_f2_run(params: dict) -> dict:
    """F2: Run semantic agents (LLM or heuristic fallback)."""
    run_id      = params.get("run_id") or store.new_run_id()
    scope       = params.get("scope", "all")
    slug        = params.get("slug")
    dry_run     = params.get("dry_run", True)
    workspace   = params.get("workspace", str(discovery.workspace_root()))

    manifest    = discovery.discover(scope=scope, slug=slug)
    files       = manifest.get("files", [])

    # Need F1 findings for coherence/redundancy pairs
    f1_store = store.run_dir(run_id) / "F1" / "_aggregate.json"
    f1_findings: list[dict] = []
    if f1_store.exists():
        try:
            agg = json.loads(f1_store.read_text(encoding="utf-8"))
            # aggregate only has summary — load per-job findings
            f1_dir = store.run_dir(run_id) / "F1"
            for jf in f1_dir.glob("*.json"):
                if jf.name.startswith("_"):
                    continue
                job_result = json.loads(jf.read_text(encoding="utf-8"))
                f1_findings.extend(job_result.get("findings", []))
        except Exception:  # noqa: BLE001
            pass

    f2_dir = store.run_dir(run_id) / "F2" if not dry_run else None
    result = f2_runner.run_all(
        files=files,
        f1_findings=f1_findings,
        workspace=workspace,
        store_dir=f2_dir,
    )
    return {
        "run_id":  run_id,
        "mode":    result.get("mode", "unknown"),
        "summary": result["summary"],
        "findings_sample": result["findings"][:20],
    }


def _tool_f3_consolidate(params: dict) -> dict:
    """F3: Consolidate F1+F2 into 4-block plan."""
    run_id  = params.get("run_id") or store.new_run_id()
    dry_run = params.get("dry_run", True)

    run_dir = store.run_dir(run_id)

    def _load_findings(phase_dir: Path) -> tuple[dict, list]:
        """Load all findings from a phase directory."""
        findings = []
        summary: dict = {}
        if not phase_dir.exists():
            return {"findings": [], "summary": summary, "jobs": {}}, findings
        for jf in phase_dir.glob("*.json"):
            if jf.name.startswith("_"):
                if jf.name == "_aggregate.json":
                    try:
                        summary = json.loads(jf.read_text(encoding="utf-8"))
                    except Exception:  # noqa: BLE001
                        pass
                continue
            try:
                jr = json.loads(jf.read_text(encoding="utf-8"))
                findings.extend(jr.get("findings", []))
            except Exception:  # noqa: BLE001
                pass
        return {"findings": findings, "summary": summary, "jobs": {}}, findings

    f1_result, _ = _load_findings(run_dir / "F1")
    f2_result, _ = _load_findings(run_dir / "F2")

    # Read previous quality for trend
    prev_trend = store.read_trend(n=2)
    prev_quality = prev_trend[-1].get("composite_quality") if prev_trend else None

    f3_dir = run_dir / "F3" if not dry_run else None
    result = f3_consolidator.consolidate(
        f1_result=f1_result,
        f2_result=f2_result,
        run_id=run_id,
        store_dir=f3_dir,
        previous_composite_quality=prev_quality,
    )

    return {
        "run_id":  run_id,
        "metrics": result["metrics"],
        "summary": result["summary"],
        "plan_blocks": {
            k: {"label": v["label"], "item_count": v["item_count"]}
            for k, v in result["plan"].items()
        },
    }


def _tool_apply(params: dict) -> dict:
    """F4: Apply plan (non-interactive)."""
    run_id    = params.get("run_id") or store.new_run_id()
    workspace = params.get("workspace", str(discovery.workspace_root()))
    dry_run   = params.get("dry_run", True)

    run_dir = store.run_dir(run_id)
    f3_plan_path = run_dir / "F3" / "F3_plan.json"
    if not f3_plan_path.exists():
        return {"error": f"F3_plan.json not found for run_id={run_id}. Run f3_consolidate first."}

    try:
        plan_data = json.loads(f3_plan_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return {"error": f"Failed to load F3_plan.json: {exc}"}

    # Reconstruct minimal f3_result structure
    f3_result = {
        "plan":    plan_data.get("plan", {}),
        "backlog": [],
    }

    f4_dir = run_dir / "F4" if not dry_run else None
    log_dict = f4_apply.apply(
        f3_result=f3_result,
        run_id=run_id,
        workspace=workspace,
        store_dir=f4_dir,
        non_interactive=True,
    )
    return log_dict


def _tool_status(params: dict) -> dict:
    """Read run store status and trend."""
    scope = params.get("scope", "all")
    n     = params.get("n", 5)
    trend = store.read_trend(n=n, scope=scope)
    return {
        "scope": scope,
        "trend": trend,
        "latest": trend[-1] if trend else None,
    }


_TOOLS: dict[str, Any] = {
    "context_update_discover":       _tool_discover,
    "context_update_f1_run":         _tool_f1_run,
    "context_update_f2_run":         _tool_f2_run,
    "context_update_f3_consolidate": _tool_f3_consolidate,
    "context_update_apply":          _tool_apply,
    "context_update_status":         _tool_status,
}

_TOOL_SCHEMAS = {
    "context_update_discover": {
        "description": "F0: Discover markdown files in the workspace by scope",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scope": {"type": "string", "enum": ["all","opencode","content","vault","raw"], "default": "all"},
                "slug":  {"type": "string", "description": "Filter to one project slug"},
            },
        },
    },
    "context_update_f1_run": {
        "description": "F1: Run all 8 structural checks (frontmatter, wikilinks, secrets, etc.)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scope":   {"type": "string", "default": "all"},
                "slug":    {"type": "string"},
                "run_id":  {"type": "string"},
                "dry_run": {"type": "boolean", "default": True},
            },
        },
    },
    "context_update_f2_run": {
        "description": "F2: Run semantic agents (LLM or heuristic fallback)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "run_id":    {"type": "string"},
                "scope":     {"type": "string", "default": "all"},
                "workspace": {"type": "string"},
                "dry_run":   {"type": "boolean", "default": True},
            },
        },
    },
    "context_update_f3_consolidate": {
        "description": "F3: Consolidate F1+F2 into 4-block action plan with composite_quality score",
        "inputSchema": {
            "type": "object",
            "properties": {
                "run_id":  {"type": "string"},
                "dry_run": {"type": "boolean", "default": True},
            },
        },
    },
    "context_update_apply": {
        "description": "F4: Apply auto-applicable fixes from the F3 plan (non-interactive)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "run_id":    {"type": "string"},
                "workspace": {"type": "string"},
                "dry_run":   {"type": "boolean", "default": True},
            },
        },
    },
    "context_update_status": {
        "description": "Read the run trend for a given scope",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scope": {"type": "string", "default": "all"},
                "n":     {"type": "integer", "default": 5},
            },
        },
    },
}


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main() -> None:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            _send(_error(None, -32700, "Parse error"))
            continue

        req_id  = req.get("id")
        method  = req.get("method", "")
        params  = req.get("params", {})

        # MCP initialize
        if method == "initialize":
            _send(_ok(req_id, {
                "protocolVersion": "2024-11-05",
                "capabilities":    {"tools": {}},
                "serverInfo":      {"name": "context-update", "version": "1.0"},
            }))
            continue

        # MCP tools/list
        if method == "tools/list":
            tools = []
            for name, schema in _TOOL_SCHEMAS.items():
                tools.append({
                    "name":        name,
                    "description": schema["description"],
                    "inputSchema": schema.get("inputSchema", {"type": "object"}),
                })
            _send(_ok(req_id, {"tools": tools}))
            continue

        # MCP tools/call
        if method == "tools/call":
            tool_name = params.get("name", "")
            tool_args = params.get("arguments", {})
            fn = _TOOLS.get(tool_name)
            if not fn:
                _send(_error(req_id, -32601, f"Unknown tool: {tool_name}"))
                continue
            try:
                result = fn(tool_args)
                _send(_ok(req_id, {
                    "content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False, indent=2)}],
                }))
            except Exception as exc:  # noqa: BLE001
                _send(_error(req_id, -32000, str(exc)))
            continue

        _send(_error(req_id, -32601, f"Method not found: {method}"))


if __name__ == "__main__":
    main()
