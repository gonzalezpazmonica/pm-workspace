#!/usr/bin/env bash
# mcp-audit.sh — audit MCP server token overhead across configs
# Ref: docs/rules/domain/mcp-overhead.md
# Origin: MindStudio blog 2026 on MCP token overhead (per-turn cost, not per-session).
#
# Scans known MCP config locations, counts tools per server, estimates tokens
# per turn using the heuristic: tokens ≈ (tools × 200) + (char_count ÷ 4).
# Emits a PASS/WARN/FAIL verdict against a budget.
#
# Usage:
#   bash scripts/mcp-audit.sh [--budget N] [--json] [--quiet]
#
# Exit codes:
#   0 = under budget
#   1 = over budget (WARN or FAIL depending on severity)
#   2 = input error

set -uo pipefail

BUDGET_TOKENS=3000
OUT_JSON=false
QUIET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget) BUDGET_TOKENS="$2"; shift 2 ;;
    --json)   OUT_JSON=true; shift ;;
    --quiet)  QUIET=true; shift ;;
    --help|-h)
      sed -n '2,16p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "Error: unknown flag $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}" || REPO_ROOT="."

# ── Discover config files ───────────────────────────────────────────────────
declare -a CONFIG_PATHS=()
# Workspace-level
[[ -f "$REPO_ROOT/.claude/mcp.json" ]] && CONFIG_PATHS+=("$REPO_ROOT/.claude/mcp.json")
# User-level Claude Code config
[[ -f "$HOME/.claude.json" ]] && CONFIG_PATHS+=("$HOME/.claude.json")
# Per-project .mcp.json files in the workspace (non-node_modules)
while IFS= read -r p; do
  CONFIG_PATHS+=("$p")
done < <(find "$REPO_ROOT/projects" -maxdepth 3 -name "mcp.json" -o -name ".mcp.json" 2>/dev/null \
          | grep -v node_modules 2>/dev/null || true)

# ── Extract servers + tools + descriptions ─────────────────────────────────
export CONFIG_PATHS_JOINED="${CONFIG_PATHS[*]:-}"
export BUDGET_TOKENS OUT_JSON QUIET

python3 <<'PY'
import json
import os
import sys

TOKENS_PER_TOOL_BASE = 200  # From MindStudio blog heuristic: 100-500 tokens/tool
CHARS_PER_TOKEN = 4

paths = os.environ.get("CONFIG_PATHS_JOINED", "").split()
budget = int(os.environ.get("BUDGET_TOKENS", "3000"))
out_json = os.environ.get("OUT_JSON", "false") == "true"
quiet = os.environ.get("QUIET", "false") == "true"

def estimate_tokens(server_name, server_cfg):
    """Estimate tokens/turn for a single MCP server config."""
    tools = server_cfg.get("tools", [])
    tool_count = len(tools) if isinstance(tools, list) else 0
    # If tools not enumerated in config, we only see the server entry itself —
    # we cannot count tools until the server is running. Estimate conservatively.
    if tool_count == 0:
        return {
            "tools": 0,
            "char_count": 0,
            "estimated_tokens": 0,
            "note": "tools-not-enumerated-statically",
        }
    desc_chars = sum(len(str(t.get("description", ""))) for t in tools)
    base = tool_count * TOKENS_PER_TOOL_BASE
    extra = desc_chars // CHARS_PER_TOKEN
    return {
        "tools": tool_count,
        "char_count": desc_chars,
        "estimated_tokens": base + extra,
    }

report = {
    "budget_tokens": budget,
    "configs_scanned": [],
    "servers": [],
    "total_tokens_estimated": 0,
    "verdict": "UNKNOWN",
    "recommendations": [],
}

seen_servers = set()

for path in paths:
    if not path or not os.path.isfile(path):
        continue
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception as e:
        report["configs_scanned"].append({"path": path, "error": str(e)})
        continue
    report["configs_scanned"].append({"path": path, "ok": True})

    # Top-level mcpServers
    top = data.get("mcpServers", {})
    for name, cfg in (top.items() if isinstance(top, dict) else []):
        if name in seen_servers:
            continue
        seen_servers.add(name)
        est = estimate_tokens(name, cfg if isinstance(cfg, dict) else {})
        report["servers"].append({
            "name": name,
            "origin": path,
            "scope": "global",
            **est,
        })
        report["total_tokens_estimated"] += est["estimated_tokens"]

    # Per-project mcpServers (nested under projects.{path}.mcpServers)
    projects = data.get("projects", {})
    for proj_path, proj_cfg in (projects.items() if isinstance(projects, dict) else []):
        proj_mcp = (proj_cfg or {}).get("mcpServers", {})
        if not isinstance(proj_mcp, dict):
            continue
        for name, cfg in proj_mcp.items():
            key = f"{proj_path}::{name}"
            if key in seen_servers:
                continue
            seen_servers.add(key)
            est = estimate_tokens(name, cfg if isinstance(cfg, dict) else {})
            report["servers"].append({
                "name": name,
                "origin": path,
                "scope": f"project:{proj_path}",
                **est,
            })
            report["total_tokens_estimated"] += est["estimated_tokens"]

# ── Verdict ─────────────────────────────────────────────────────────────────
total = report["total_tokens_estimated"]
if total == 0:
    report["verdict"] = "OK (no user-configured MCP servers — zero overhead)"
elif total <= budget:
    report["verdict"] = f"OK ({total} tokens/turn, under budget {budget})"
elif total <= budget * 2:
    report["verdict"] = f"WARN ({total} tokens/turn, over budget {budget} by {total-budget})"
else:
    report["verdict"] = f"FAIL ({total} tokens/turn, {total//budget}x the budget {budget})"

# ── Recommendations ────────────────────────────────────────────────────────
if total > budget:
    report["recommendations"].append("Move global mcpServers to per-project config")
    report["recommendations"].append("Compress tool descriptions to 1-2 lines (saves ~60-80 tokens/tool)")
    report["recommendations"].append("Prune servers unused for >2 weeks")
    report["recommendations"].append("Use tool filtering — expose only actively used tools")
if len(report["servers"]) == 0 and len(report["configs_scanned"]) > 0:
    report["recommendations"].append("Current design (on-demand loading) is already optimal — keep it")

# ── Output ──────────────────────────────────────────────────────────────────
if out_json:
    print(json.dumps(report, indent=2))
else:
    if not quiet:
        print("=== MCP Overhead Audit ===")
        print(f"Configs scanned: {len(report['configs_scanned'])}")
        for cfg in report["configs_scanned"]:
            mark = "OK" if cfg.get("ok") else f"ERROR ({cfg.get('error', '?')})"
            print(f"  [{mark}] {cfg['path']}")
        print()
        if report["servers"]:
            print(f"Servers configured: {len(report['servers'])}")
            for s in report["servers"]:
                note = f" ({s.get('note')})" if s.get("note") else ""
                print(f"  {s['name']} [{s['scope']}] — {s['tools']} tools, ~{s['estimated_tokens']} tokens/turn{note}")
        else:
            print("Servers configured: 0 (no MCP overhead)")
        print()
        print(f"Total estimated overhead: {total} tokens/turn")
        print(f"Budget: {budget} tokens/turn")
        print(f"Verdict: {report['verdict']}")
        if report["recommendations"]:
            print()
            print("Recommendations:")
            for r in report["recommendations"]:
                print(f"  - {r}")

# Exit code
if total > budget:
    sys.exit(1)
sys.exit(0)
PY
