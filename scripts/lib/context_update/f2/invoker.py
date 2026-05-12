"""f2/invoker.py — LLM agent invoker for F2 semantic judges.

Calls the 4 spec agents via the Savia agent runner (scripts/run-agent.sh or
direct claude CLI). Each agent receives batches of ≤50 files. Agents run in
parallel (ThreadPoolExecutor, 4 workers). Hard time-box: 8 min total.

Agents (SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.7):
  - context-quality-judge      → quality findings
  - context-coherence-judge    → coherence/contradiction findings (pairs)
  - context-obsolescence-judge → obsolescence findings (stale files)
  - context-redundancy-judge   → duplicate confirmation findings (pairs)

Fallback: if the agent runner is unavailable (no claude CLI, no run-agent.sh),
falls back to the heuristic modules so the pipeline never hard-fails.

SPEC-KNOWLEDGE-CONTEXT-INTEGRATION-PHASE2 §7.3 F2.
"""
from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

log = logging.getLogger(__name__)

AGENT_BATCH_SIZE = 50        # hard cap: notes per agent call
F2_MAX_TOTAL_SECONDS = 480   # 8 min total hard cap
AGENT_CALL_TIMEOUT = 180     # 3 min per individual agent call
MAX_CONTENT_CHARS = 4000     # truncate note content to avoid token overflow

# ---------------------------------------------------------------------------
# Agent definitions
# ---------------------------------------------------------------------------

_QUALITY_AGENT = "context-quality-judge"
_COHERENCE_AGENT = "context-coherence-judge"
_OBSOLESCENCE_AGENT = "context-obsolescence-judge"
_REDUNDANCY_AGENT = "context-redundancy-judge"


def _truncate(text: str, max_chars: int = MAX_CONTENT_CHARS) -> str:
    if len(text) <= max_chars:
        return text
    return text[:max_chars] + "\n[...truncated]"


# ---------------------------------------------------------------------------
# Runner detection
# ---------------------------------------------------------------------------

def _find_claude_cli() -> str | None:
    """Return path to claude CLI if available, else None."""
    return shutil.which("claude")


def _find_run_agent_sh(workspace: str) -> str | None:
    candidate = Path(workspace) / "scripts" / "run-agent.sh"
    if candidate.exists():
        return str(candidate)
    return None


# ---------------------------------------------------------------------------
# Agent call
# ---------------------------------------------------------------------------

def _call_agent(agent_name: str, payload: dict, workspace: str) -> dict:
    """Invoke an agent with a JSON payload and return parsed JSON findings.

    Strategy:
    1. Write payload to a temp file.
    2. Call: claude --agent <agent_name> --input <tempfile> --output-json
       OR: bash scripts/run-agent.sh <agent_name> < <tempfile>
    3. Parse stdout as JSON.
    4. On any failure, return empty findings with error note.
    """
    claude = _find_claude_cli()
    run_agent = _find_run_agent_sh(workspace)

    if not claude and not run_agent:
        return {
            "job": agent_name,
            "findings": [],
            "error": "no_runner: claude CLI and run-agent.sh both unavailable",
            "summary": {"findings_count": 0},
        }

    payload_str = json.dumps(payload, ensure_ascii=False)

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(payload_str)
        tmp_path = tmp.name

    try:
        if claude:
            cmd = [
                claude,
                "--print",
                "--agent", agent_name,
                "--input-file", tmp_path,
            ]
        else:
            cmd = ["bash", run_agent, agent_name]

        env = {**os.environ, "SAVIA_AGENT_INPUT_FILE": tmp_path}

        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=AGENT_CALL_TIMEOUT,
            env=env,
            cwd=workspace,
        )

        raw = proc.stdout.strip()
        if not raw:
            return {
                "job": agent_name,
                "findings": [],
                "error": f"empty_output: stderr={proc.stderr[:200]}",
                "summary": {"findings_count": 0},
            }

        # Extract JSON — agents may emit prose before/after the JSON block
        start = raw.find("{")
        end = raw.rfind("}") + 1
        if start == -1 or end == 0:
            return {
                "job": agent_name,
                "findings": [],
                "error": f"no_json_in_output: {raw[:200]}",
                "summary": {"findings_count": 0},
            }

        result = json.loads(raw[start:end])
        findings = result.get("findings", [])
        # Normalise: ensure each finding carries the job id
        for f in findings:
            f.setdefault("job", agent_name)
        return {
            "job": agent_name,
            "findings": findings,
            "summary": {"findings_count": len(findings)},
        }

    except subprocess.TimeoutExpired:
        return {
            "job": agent_name,
            "findings": [],
            "error": f"timeout after {AGENT_CALL_TIMEOUT}s",
            "summary": {"findings_count": 0},
        }
    except json.JSONDecodeError as exc:
        return {
            "job": agent_name,
            "findings": [],
            "error": f"json_parse_error: {exc}",
            "summary": {"findings_count": 0},
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "job": agent_name,
            "findings": [],
            "error": str(exc),
            "summary": {"findings_count": 0},
        }
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Batch builders
# ---------------------------------------------------------------------------

def _build_quality_batches(files: list[dict]) -> list[dict]:
    """Batches for context-quality-judge: plain file list, ≤50 per batch."""
    batches = []
    for i in range(0, len(files), AGENT_BATCH_SIZE):
        chunk = files[i : i + AGENT_BATCH_SIZE]
        batches.append({
            "job": "context_quality_judge",
            "files": [
                {"path": f["path"], "content": _truncate(f.get("content", ""))}
                for f in chunk
            ],
        })
    return batches


def _build_obsolescence_batches(files: list[dict]) -> list[dict]:
    """Batches for context-obsolescence-judge: only stale files (age ≥ 180 days)."""
    stale = [f for f in files if f.get("age_days", 0) >= 180]
    batches = []
    for i in range(0, len(stale), AGENT_BATCH_SIZE):
        chunk = stale[i : i + AGENT_BATCH_SIZE]
        batches.append({
            "job": "context_obsolescence_judge",
            "files": [
                {
                    "path": f["path"],
                    "content": _truncate(f.get("content", "")),
                    "age_days": f.get("age_days", 0),
                    "doc_type": f.get("doc_type", "raw"),
                }
                for f in chunk
            ],
        })
    return batches


def _build_coherence_batches(files: list[dict], f1_findings: list[dict]) -> list[dict]:
    """Batches for context-coherence-judge: pairs of files with mutual backlinks."""
    # Build backlink map from wikilink_check findings
    backlink_pairs: set[tuple[str, str]] = set()
    for finding in f1_findings:
        if finding.get("job") != "wikilink_check":
            continue
        src = finding.get("file", "")
        target = finding.get("target", "")
        if src and target:
            key = tuple(sorted([src, target]))
            backlink_pairs.add(key)  # type: ignore[arg-type]

    # Also pair files that share a spec reference (crude: same parent dir)
    file_map = {f["path"]: f for f in files}
    pairs = []
    seen: set[tuple[str, str]] = set()
    for a, b in backlink_pairs:
        if a in file_map and b in file_map:
            key = (a, b)
            if key not in seen:
                seen.add(key)
                pairs.append({
                    "file_a": {
                        "path": a,
                        "content": _truncate(file_map[a].get("content", "")),
                    },
                    "file_b": {
                        "path": b,
                        "content": _truncate(file_map[b].get("content", "")),
                    },
                    "relationship": "backlink",
                })

    batches = []
    for i in range(0, len(pairs), AGENT_BATCH_SIZE):
        batches.append({
            "job": "context_coherence_judge",
            "pairs": pairs[i : i + AGENT_BATCH_SIZE],
        })
    return batches


def _build_redundancy_batches(files: list[dict], f1_findings: list[dict]) -> list[dict]:
    """Batches for context-redundancy-judge: pairs from F1 duplicate_detection."""
    dup_pairs = []
    file_map = {f["path"]: f for f in files}
    seen: set[tuple[str, str]] = set()

    for finding in f1_findings:
        if finding.get("job") != "duplicate_detection":
            continue
        a = finding.get("file", "")
        b = finding.get("duplicate_of", "")
        jaccard = finding.get("jaccard", 0.0)
        if not a or not b:
            continue
        key = tuple(sorted([a, b]))
        if key in seen:
            continue
        seen.add(key)  # type: ignore[arg-type]
        if a in file_map and b in file_map:
            dup_pairs.append({
                "file_a": {
                    "path": a,
                    "content": _truncate(file_map[a].get("content", "")),
                },
                "file_b": {
                    "path": b,
                    "content": _truncate(file_map[b].get("content", "")),
                },
                "f1_jaccard_estimate": jaccard,
            })

    batches = []
    for i in range(0, len(dup_pairs), AGENT_BATCH_SIZE):
        batches.append({
            "job": "context_redundancy_judge",
            "pairs": dup_pairs[i : i + AGENT_BATCH_SIZE],
        })
    return batches


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def run_all(
    files: list[dict],
    f1_findings: list[dict],
    workspace: str,
    store_dir: Path | None = None,
) -> dict[str, Any]:
    """Run all 4 F2 LLM agents in parallel with batching.

    Args:
        files:       list of file dicts from discovery (must include 'content').
        f1_findings: flat list of all F1 findings (used to build coherence/redundancy pairs).
        workspace:   workspace root path (needed to locate claude CLI / run-agent.sh).
        store_dir:   optional path to write per-agent JSON results.

    Returns:
        {
          "agents":   {agent_id: merged_result},
          "findings": [all findings],
          "summary":  {total_files, total_findings, by_severity, by_job, elapsed_s},
        }
    """
    if store_dir:
        store_dir = Path(store_dir)
        store_dir.mkdir(parents=True, exist_ok=True)

    t0 = time.monotonic()

    # Build all batch lists per agent
    agent_batches: list[tuple[str, dict]] = []  # (agent_name, payload)

    for batch in _build_quality_batches(files):
        agent_batches.append((_QUALITY_AGENT, batch))

    for batch in _build_obsolescence_batches(files):
        agent_batches.append((_OBSOLESCENCE_AGENT, batch))

    for batch in _build_coherence_batches(files, f1_findings):
        agent_batches.append((_COHERENCE_AGENT, batch))

    for batch in _build_redundancy_batches(files, f1_findings):
        agent_batches.append((_REDUNDANCY_AGENT, batch))

    if not agent_batches:
        log.info("F2 invoker: no batches to process (files list empty or no pairs)")
        return {
            "agents": {},
            "findings": [],
            "summary": {
                "total_files": len(files),
                "total_findings": 0,
                "by_severity": {},
                "by_job": {},
                "elapsed_s": 0.0,
            },
        }

    # Run all batches in parallel (4 workers, one per agent type is enough)
    agents_results: dict[str, list[dict]] = {}
    all_findings: list[dict] = []

    def _call(args: tuple[str, dict]) -> tuple[str, dict]:
        agent_name, payload = args
        elapsed_so_far = time.monotonic() - t0
        if elapsed_so_far >= F2_MAX_TOTAL_SECONDS:
            return agent_name, {
                "job": agent_name,
                "findings": [],
                "error": "global_timeout",
                "summary": {"findings_count": 0},
            }
        return agent_name, _call_agent(agent_name, payload, workspace)

    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = {executor.submit(_call, ab): ab for ab in agent_batches}
        for future in as_completed(futures, timeout=F2_MAX_TOTAL_SECONDS):
            try:
                agent_name, result = future.result()
            except Exception as exc:  # noqa: BLE001
                agent_name = futures[future][0]
                result = {
                    "job": agent_name,
                    "findings": [],
                    "error": str(exc),
                    "summary": {"findings_count": 0},
                }
            agents_results.setdefault(agent_name, []).append(result)
            all_findings.extend(result.get("findings", []))

    # Merge per-agent batches into single result per agent
    merged_agents: dict[str, Any] = {}
    for agent_name, results in agents_results.items():
        merged_findings = []
        errors = []
        for r in results:
            merged_findings.extend(r.get("findings", []))
            if "error" in r:
                errors.append(r["error"])
        merged_agents[agent_name] = {
            "job": agent_name,
            "findings": merged_findings,
            "summary": {"findings_count": len(merged_findings)},
        }
        if errors:
            merged_agents[agent_name]["errors"] = errors

    elapsed = round(time.monotonic() - t0, 3)

    by_severity: dict[str, int] = {}
    by_job: dict[str, int] = {}
    for f in all_findings:
        sev = f.get("severity", "INFO")
        by_severity[sev] = by_severity.get(sev, 0) + 1
        jid = f.get("job", "unknown")
        by_job[jid] = by_job.get(jid, 0) + 1

    aggregated = {
        "agents": merged_agents,
        "findings": all_findings,
        "summary": {
            "total_files": len(files),
            "total_findings": len(all_findings),
            "by_severity": by_severity,
            "by_job": by_job,
            "elapsed_s": elapsed,
        },
    }

    if store_dir:
        for agent_name, result in merged_agents.items():
            safe = agent_name.replace("-", "_")
            (store_dir / f"{safe}.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        import json as _json
        (store_dir / "_aggregate.json").write_text(
            _json.dumps(aggregated["summary"], ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    return aggregated
