#!/usr/bin/env python3
"""
scripts/task-decomposer.py -- SPEC-052: Recursive Task Decomposition

Recursively decomposes a complex task into an atomic tree where each
leaf is <= SAVIA_TASK_SIZE_HOURS (default 4h).

CLI:
    python3 scripts/task-decomposer.py --task "Build auth system" --max-depth 3

Output JSON: {id, title, classification, estimated_hours, depth, can_parallelize, lineage, subtasks}
"""
from __future__ import annotations
import argparse, json, os, re, sys
from dataclasses import dataclass, field
from typing import Any

_EFFORT_PATTERNS: list[tuple[str, float]] = [
    (r"\bauth\b",            4.0),
    (r"\bjwt\b",             2.0),
    (r"\boauth\b",           5.0),
    (r"\brefresh.token\b",   2.0),
    (r"\bcrud\b",            2.0),
    (r"\bapi\b",             3.0),
    (r"\bnotif\w*\b",        3.0),
    (r"\bwebhook\b",         2.5),
    (r"\bemail\b",           2.0),
    (r"\bdatabase\b|\bdb\b", 2.0),
    (r"\bmigration\b",       2.0),
    (r"\btest\w*\b",         2.0),
    (r"\bdeploy\w*\b",       2.0),
    (r"\bdocker\b",          2.0),
    (r"\bfrontend\b|\bui\b", 4.0),
    (r"\bbackend\b",         3.0),
    (r"\bservice\b",         2.0),
    (r"\bintegration\b",     3.0),
    (r"\bcache\b",           2.0),
    (r"\bqueue\b",           2.5),
    (r"\bpayment\b",         5.0),
    (r"\bsearch\b",          3.0),
    (r"\bdashboard\b",       4.0),
    (r"\bsecurity\b",        4.0),
]

_COMPOUND_SIGNALS: list[str] = [
    r"\band\b", r"\bwith\b", r"\balso\b", r"\bplus\b",
    r"\bincluding\b", r"[,;]\s*\w",
]

_DECOMP_TEMPLATES: dict[str, list[str]] = {
    "auth":     ["Implement authentication flow", "Add authorization middleware", "Write auth tests"],
    "api":      ["Design API endpoints", "Implement API handlers", "Add API validation"],
    "crud":     ["Implement create endpoint", "Implement read and list endpoints", "Implement update and delete endpoints"],
    "frontend": ["Create UI components", "Implement state management", "Add UI tests"],
    "database": ["Design schema", "Write migration scripts", "Add database tests"],
    "notification": ["Create notification service", "Implement delivery channel", "Add notification tests"],
    "payment":  ["Integrate gateway", "Handle payment callbacks", "Add payment tests"],
    "search":   ["Implement indexing", "Build query logic", "Add search tests"],
}

_task_counter = 0

def _next_id(prefix: str = "") -> str:
    global _task_counter
    _task_counter += 1
    return f"{prefix}{_task_counter}" if prefix else str(_task_counter)

def _reset_counter() -> None:
    global _task_counter
    _task_counter = 0

@dataclass
class Task:
    id: str
    title: str
    classification: str
    estimated_hours: float
    depth: int
    can_parallelize: bool
    lineage: list[str] = field(default_factory=list)
    subtasks: list["Task"] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "classification": self.classification,
            "estimated_hours": round(self.estimated_hours, 1),
            "depth": self.depth,
            "can_parallelize": self.can_parallelize,
            "lineage": self.lineage,
            "subtasks": [s.to_dict() for s in self.subtasks],
        }


def estimate_hours(title: str) -> float:
    total = 0.0
    lowered = title.lower()
    matched: set[str] = set()
    for pattern, hours in _EFFORT_PATTERNS:
        if re.search(pattern, lowered, re.IGNORECASE):
            root = pattern.split("\\b")[1].split("(")[0].split("|")[0]
            if root not in matched:
                total += hours
                matched.add(root)
    return max(1.0, total)


def is_compound(title: str) -> bool:
    lowered = title.lower()
    compound_count = sum(
        1 for p in _COMPOUND_SIGNALS if re.search(p, lowered, re.IGNORECASE)
    )
    tech_matches = sum(
        1 for p, _ in _EFFORT_PATTERNS if re.search(p, lowered, re.IGNORECASE)
    )
    return compound_count >= 2 or tech_matches >= 3


def can_parallelize_subtasks(subtasks: list[str]) -> bool:
    if len(subtasks) <= 1:
        return False
    return all(len(s.split()) <= 8 for s in subtasks)


def _pick_template(title: str) -> list[str] | None:
    lowered = title.lower()
    for key, template in _DECOMP_TEMPLATES.items():
        if re.search(r"\b" + re.escape(key) + r"\b", lowered):
            return template
    return None


def _split_by_conjunction(title: str) -> list[str] | None:
    parts = re.split(r"\s+and\s+|\s+with\s+|[,;]\s+", title, flags=re.IGNORECASE)
    parts = [p.strip() for p in parts if p.strip()]
    if len(parts) >= 2:
        cleaned = []
        for p in parts:
            if not re.match(r"^(create|add|fix|update|implement|write|setup|configure|build|design|test)\b", p, re.IGNORECASE):
                p = "Implement " + p
            cleaned.append(p)
        return cleaned
    return None


def decompose(
    title: str,
    max_depth: int = 3,
    size_threshold: float = 4.0,
    depth: int = 0,
    lineage: list[str] | None = None,
    parent_id: str = "",
) -> Task:
    if lineage is None:
        lineage = []
    task_id = _next_id(f"{parent_id}." if parent_id else "")
    estimated = estimate_hours(title)
    compound = is_compound(title)

    if depth >= max_depth or estimated <= size_threshold or not compound:
        return Task(
            id=task_id, title=title, classification="atomic",
            estimated_hours=estimated, depth=depth, can_parallelize=False,
            lineage=list(lineage), subtasks=[],
        )

    subtask_titles: list[str] | None = _pick_template(title)
    if not subtask_titles:
        subtask_titles = _split_by_conjunction(title)
    if not subtask_titles:
        subtask_titles = [
            f"Design: {title}",
            f"Implement: {title}",
            f"Test: {title}",
        ]
    if len(subtask_titles) < 2:
        subtask_titles = subtask_titles + [f"Validate: {title}"]
    if len(subtask_titles) > 7:
        subtask_titles = subtask_titles[:7]

    child_lineage = lineage + [title]
    children = [
        decompose(
            sub_title, max_depth=max_depth, size_threshold=size_threshold,
            depth=depth + 1, lineage=child_lineage, parent_id=task_id,
        )
        for sub_title in subtask_titles
    ]
    total_hours = sum(c.estimated_hours for c in children)
    parallel = can_parallelize_subtasks(subtask_titles)

    return Task(
        id=task_id, title=title, classification="compound",
        estimated_hours=round(total_hours, 1), depth=depth, can_parallelize=parallel,
        lineage=list(lineage), subtasks=children,
    )


def render_tree(task: Task, prefix: str = "", is_last: bool = True) -> str:
    connector = "---- " if is_last else "|--- "
    tag = f"[{task.classification[0].upper()}]"
    line = f"{prefix}{connector}{tag} {task.title} (~{task.estimated_hours}h)\n"
    child_prefix = prefix + ("     " if is_last else "|    ")
    for i, child in enumerate(task.subtasks):
        line += render_tree(child, child_prefix, i == len(task.subtasks) - 1)
    return line


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="task-decomposer.py", description="SPEC-052: Recursive Task Decomposition")
    p.add_argument("--task", required=True, metavar="TEXT")
    p.add_argument("--max-depth", type=int, default=3, metavar="N")
    p.add_argument("--size-hours", type=float,
                   default=float(os.environ.get("SAVIA_TASK_SIZE_HOURS", "4")),
                   metavar="H")
    p.add_argument("--tree", action="store_true", help="Print ASCII tree to stderr")
    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    _reset_counter()
    result = decompose(title=args.task, max_depth=args.max_depth, size_threshold=args.size_hours)
    if args.tree:
        print(render_tree(result, is_last=True), file=sys.stderr)
    print(json.dumps(result.to_dict(), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
