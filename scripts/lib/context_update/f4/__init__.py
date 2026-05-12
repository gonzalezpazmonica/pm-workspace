"""f4/__init__.py — F4 apply: human-confirmed block-by-block execution.

Presents each block from the F3 plan to the user, asks for confirmation,
and delegates auto-applicable items to the appropriate Savia commands.

Protocol (SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F4):
  - Iterate blocks in order: CRÍTICO → IMPORTANTE → MANTENIMIENTO → CALIDAD
  - For each block: display items, ask [y/N/s(kip)/q(uit)]
  - On 'y': apply auto-applicable items; log manual items as pending
  - On 's': skip block, mark as SKIPPED in apply log
  - On 'q': stop immediately, persist partial log

Output artefact: F4_apply_log.json (canonical name per spec)

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F4.
Rule #26: Python owns logic.
"""
from __future__ import annotations

import datetime
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

_BLOCK_ORDER = [
    "block_1_critical",
    "block_2_important",
    "block_3_maintenance",
    "block_4_quality",
]

# Commands that can be invoked automatically for auto_applicable items
_DELEGATABLE_COMMANDS = {
    "vault-curator --fix-broken-links",
    "vault-curator --fix-frontmatter",
    "vault-curator --normalise-tags",
}


# ---------------------------------------------------------------------------
# Apply log
# ---------------------------------------------------------------------------

class ApplyLog:
    def __init__(self, run_id: str) -> None:
        self.run_id = run_id
        self.started = datetime.datetime.now(tz=datetime.timezone.utc).isoformat()
        self.entries: list[dict] = []

    def record(self, block: str, item: dict, status: str, detail: str = "") -> None:
        self.entries.append({
            "block":   block,
            "item_id": item.get("id", "?"),
            "file":    item.get("file", ""),
            "action":  item.get("action", ""),
            "status":  status,   # APPLIED | PENDING_MANUAL | SKIPPED | ERROR
            "detail":  detail,
            "ts":      datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
        })

    def to_dict(self) -> dict:
        applied  = [e for e in self.entries if e["status"] == "APPLIED"]
        pending  = [e for e in self.entries if e["status"] == "PENDING_MANUAL"]
        skipped  = [e for e in self.entries if e["status"] == "SKIPPED"]
        errors   = [e for e in self.entries if e["status"] == "ERROR"]
        return {
            "run_id":  self.run_id,
            "started": self.started,
            "summary": {
                "applied":         len(applied),
                "pending_manual":  len(pending),
                "skipped":         len(skipped),
                "errors":          len(errors),
            },
            "entries": self.entries,
        }

    def write(self, store_dir: Path) -> Path:
        store_dir.mkdir(parents=True, exist_ok=True)
        path = store_dir / "F4_apply_log.json"
        path.write_text(
            json.dumps(self.to_dict(), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return path


# ---------------------------------------------------------------------------
# Command delegation
# ---------------------------------------------------------------------------

def _delegate(command_hint: str, workspace: str) -> tuple[bool, str]:
    """Run a delegatable command. Returns (success, output_or_error)."""
    if command_hint not in _DELEGATABLE_COMMANDS:
        return False, f"command not in delegation list: {command_hint}"
    try:
        result = subprocess.run(
            command_hint.split(),
            capture_output=True,
            text=True,
            timeout=120,
            cwd=workspace,
        )
        if result.returncode == 0:
            return True, result.stdout[:500]
        return False, f"exit {result.returncode}: {result.stderr[:300]}"
    except subprocess.TimeoutExpired:
        return False, "timeout after 120s"
    except FileNotFoundError:
        return False, f"command not found: {command_hint.split()[0]}"
    except Exception as exc:  # noqa: BLE001
        return False, str(exc)


# ---------------------------------------------------------------------------
# Block processor
# ---------------------------------------------------------------------------

def _process_block(
    block_key: str,
    block_data: dict,
    apply_log: ApplyLog,
    workspace: str,
    non_interactive: bool = False,
) -> str:
    """Process one block. Returns 'applied'|'skipped'|'quit'."""
    label = block_data.get("label", block_key)
    items = block_data.get("items", [])

    if not items:
        return "applied"

    print(f"\n{'─' * 60}")
    print(f"  Block: {label}")
    print(f"  Items: {len(items)}")
    print()

    auto_items   = [i for i in items if i.get("auto_applicable")]
    manual_items = [i for i in items if not i.get("auto_applicable")]

    for item in items:
        auto_tag = " [auto]" if item.get("auto_applicable") else " [manual]"
        hint = item.get("command_hint", "")
        hint_str = f"\n      → {hint}" if hint and hint != "manual" else ""
        print(f"  [{item['id']}]{auto_tag} {item['action']}{hint_str}")

    print()
    print(f"  Auto-applicable: {len(auto_items)}  |  Manual review: {len(manual_items)}")
    print()

    if non_interactive:
        # In non-interactive mode: apply auto, log manual as pending
        answer = "y"
    else:
        try:
            answer = input("  Apply this block? [y/N/s=skip/q=quit] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            answer = "q"

    if answer == "q":
        for item in items:
            apply_log.record(block_key, item, "SKIPPED", "user quit")
        return "quit"

    if answer not in ("y", "yes"):
        for item in items:
            apply_log.record(block_key, item, "SKIPPED", "user skipped block")
        print(f"  Skipped.")
        return "skipped"

    # Apply
    # First: run delegatable commands (deduplicated by command_hint)
    seen_commands: set[str] = set()
    for item in auto_items:
        hint = item.get("command_hint", "manual")
        if hint == "manual" or hint not in _DELEGATABLE_COMMANDS:
            apply_log.record(block_key, item, "PENDING_MANUAL",
                             "auto_applicable but no delegatable command")
            continue
        if hint in seen_commands:
            apply_log.record(block_key, item, "APPLIED", f"command already run: {hint}")
            continue
        seen_commands.add(hint)
        print(f"    Running: {hint} …", end=" ", flush=True)
        ok, detail = _delegate(hint, workspace)
        if ok:
            print("OK")
            apply_log.record(block_key, item, "APPLIED", detail[:200])
        else:
            print(f"ERROR: {detail[:100]}")
            apply_log.record(block_key, item, "ERROR", detail[:200])

    # Log manual items as PENDING
    for item in manual_items:
        apply_log.record(block_key, item, "PENDING_MANUAL", "requires human action")

    return "applied"


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def apply(
    f3_result: dict,
    run_id: str,
    workspace: str,
    store_dir: Path | None = None,
    non_interactive: bool = False,
) -> dict[str, Any]:
    """Run F4: block-by-block confirmation and delegation.

    Args:
        f3_result:       result dict from f3.consolidate()
        run_id:          run identifier
        workspace:       workspace root path
        store_dir:       path to write F4_apply_log.json
        non_interactive: if True, auto-accept all blocks (for CI/scripted use)

    Returns:
        Apply log dict.
    """
    plan     = f3_result.get("plan", {})
    apply_log = ApplyLog(run_id)

    print("\nF4 · Apply Plan")
    print("=" * 60)
    print(f"  run_id: {run_id}")
    print(f"  workspace: {workspace}")
    if non_interactive:
        print("  mode: non-interactive (auto-accept)")
    print()

    for block_key in _BLOCK_ORDER:
        block_data = plan.get(block_key)
        if not block_data:
            continue
        outcome = _process_block(
            block_key, block_data, apply_log, workspace, non_interactive
        )
        if outcome == "quit":
            print("\n  Stopped by user.")
            break

    # Also log backlog items as PENDING
    for item in f3_result.get("backlog", []):
        apply_log.record("backlog", item, "PENDING_MANUAL", "in backlog, not shown in F4")

    # Summary
    log_dict = apply_log.to_dict()
    s = log_dict["summary"]
    print(f"\nF4 complete: applied={s['applied']}  pending={s['pending_manual']}  "
          f"skipped={s['skipped']}  errors={s['errors']}")

    if store_dir:
        log_path = apply_log.write(Path(store_dir))
        print(f"  Apply log: {log_path}")

    return log_dict
