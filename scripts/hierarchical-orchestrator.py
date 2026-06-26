#!/usr/bin/env python3
"""hierarchical-orchestrator.py — SPEC-152: feature-lead delegation for task plans.

Accepts a task plan as a JSON tree, assigns feature-lead roles to subtask
groups with >3 children, and generates a delegation assignment report.

Usage:
  python3 scripts/hierarchical-orchestrator.py --plan plan.json
  python3 scripts/hierarchical-orchestrator.py --plan plan.json --output report.json
  python3 scripts/hierarchical-orchestrator.py --plan plan.json --min-children 2
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# ── Domain routing ─────────────────────────────────────────────────────────────

DOMAIN_LEADS: dict[str, dict] = {
    "backend": {
        "lead": "backend-feature-lead",
        "keywords": [
            "dotnet", ".net", "c#", "python", "fastapi", "django", "go", "golang",
            "java", "spring", "api", "microservice", "database", "sql", "backend",
            "service", "controller", "repository", "entity", "migration",
        ],
        "owns": ["dotnet-developer", "python-developer", "go-developer", "java-developer"],
    },
    "frontend": {
        "lead": "frontend-feature-lead",
        "keywords": [
            "angular", "react", "vue", "frontend", "ui", "ux", "component",
            "html", "css", "sass", "tailwind", "nextjs", "mobile", "swift",
            "kotlin", "flutter", "page", "view", "form", "layout",
        ],
        "owns": ["frontend-developer", "mobile-developer"],
    },
    "infra": {
        "lead": "infra-feature-lead",
        "keywords": [
            "terraform", "docker", "kubernetes", "k8s", "azure", "aws", "gcp",
            "ci", "cd", "pipeline", "deploy", "infra", "infrastructure",
            "helm", "bicep", "iac", "devops", "container", "cloud",
        ],
        "owns": ["terraform-developer", "infrastructure-agent"],
    },
    "qa": {
        "lead": "qa-feature-lead",
        "keywords": [
            "test", "spec", "bats", "pytest", "jest", "coverage", "quality",
            "qa", "assertion", "mock", "fixture", "mutation", "performance",
            "e2e", "integration", "unit", "regression",
        ],
        "owns": ["test-runner", "test-architect", "test-engineer"],
    },
}

DEFAULT_LEAD = "backend-feature-lead"


# ── Domain detection ──────────────────────────────────────────────────────────

def _detect_domain(task: dict) -> str:
    """Detect the feature-lead domain from task title/description/tags."""
    text = " ".join([
        str(task.get("title", "")),
        str(task.get("description", "")),
        str(task.get("type", "")),
        " ".join(task.get("tags", [])),
    ]).lower()

    scores: dict[str, int] = {domain: 0 for domain in DOMAIN_LEADS}
    for domain, info in DOMAIN_LEADS.items():
        for kw in info["keywords"]:
            if kw in text:
                scores[domain] += 1

    best = max(scores, key=lambda d: scores[d])
    return best if scores[best] > 0 else "backend"


# ── Core logic ────────────────────────────────────────────────────────────────

def assign_leads(plan: dict | list, min_children: int = 3) -> dict:
    """
    Walk the task tree. For each node with > min_children children,
    assign a feature-lead. Return an assignment report.

    Plan format (flexible):
      - list of tasks → top-level group
      - dict with 'tasks' key → unwrapped
      - each task: {title, children?: [...], domain?: str, ...}
    """
    # Normalise input
    if isinstance(plan, list):
        root = {"title": "root", "children": plan}
    elif isinstance(plan, dict) and "tasks" in plan:
        root = {"title": plan.get("title", "root"), "children": plan["tasks"]}
    else:
        root = plan

    assignments: list[dict] = []
    unassigned: list[dict] = []

    def _walk(node: dict, depth: int = 0) -> None:
        children = node.get("children", node.get("subtasks", []))
        title = node.get("title", node.get("name", "unnamed"))

        if len(children) > min_children:
            domain = node.get("domain") or _detect_domain(node)
            lead_info = DOMAIN_LEADS.get(domain, DOMAIN_LEADS["backend"])
            assignments.append({
                "task": title,
                "feature_lead": lead_info["lead"],
                "domain": domain,
                "child_count": len(children),
                "depth": depth,
                "rationale": (
                    f"Group '{title}' has {len(children)} children "
                    f"(threshold: >{min_children}). Detected domain: '{domain}' "
                    f"→ delegated to '{lead_info['lead']}' which owns: "
                    f"{', '.join(lead_info['owns'][:3])}."
                ),
            })
        else:
            if children or depth == 0:
                unassigned.append({
                    "task": title,
                    "child_count": len(children),
                    "depth": depth,
                    "note": (
                        f"{len(children)} children ≤ threshold ({min_children}) "
                        "— orchestrator handles directly."
                    ),
                })

        for child in children:
            _walk(child, depth + 1)

    _walk(root)

    # Summary statistics
    lead_counts: dict[str, int] = {}
    for a in assignments:
        lead_counts[a["feature_lead"]] = lead_counts.get(a["feature_lead"], 0) + 1

    return {
        "assignments": assignments,
        "unassigned": unassigned,
        "summary": {
            "total_groups_delegated": len(assignments),
            "total_groups_direct": len(unassigned),
            "lead_distribution": lead_counts,
            "min_children_threshold": min_children,
        },
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="SPEC-152 hierarchical-orchestrator")
    p.add_argument("--plan", required=True, help="Path to JSON task plan")
    p.add_argument("--output", help="Write JSON report to this path (default: stdout)")
    p.add_argument(
        "--min-children", type=int, default=3,
        help="Min number of children to trigger feature-lead assignment (default: 3)"
    )
    p.add_argument("--quiet", action="store_true", help="Suppress summary line on stderr")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    plan_path = Path(args.plan)
    if not plan_path.exists():
        print(f"ERROR: plan file not found: {plan_path}", file=sys.stderr)
        return 1

    try:
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON in plan: {exc}", file=sys.stderr)
        return 1

    report = assign_leads(plan, min_children=args.min_children)
    output_json = json.dumps(report, indent=2)

    if args.output:
        Path(args.output).write_text(output_json, encoding="utf-8")
    else:
        print(output_json)

    if not args.quiet:
        s = report["summary"]
        print(
            f'delegated={s["total_groups_delegated"]} direct={s["total_groups_direct"]} '
            f'leads={list(s["lead_distribution"].keys())}',
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
