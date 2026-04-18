#!/usr/bin/env python3
"""
generate-capability-map.py — Generate `.scm/` (Savia Capability Map) from
workspace resources (commands, skills, agents, scripts).

Drop-in replacement for the Bash version (`generate-capability-map.sh`) that
was O(resources × process_spawn) slow on Windows — often >1 hour for 1000
resources. This Python version runs the same logic in-process and completes
in seconds.

Outputs:
  .scm/INDEX.scm                      — flat index, one line per resource
  .scm/categories/<category>.scm      — grouped by coarse category
  .scm/categories/resources.json      — machine-readable mirror (NEW)

Categories: analysis, communication, development, governance, memory,
planning, quality.
"""
from __future__ import annotations

import json
import re
import sys
import time
from datetime import date
from pathlib import Path
from typing import Iterable

# ── Regexes (precompiled once) ────────────────────────────────────────────
# Matches YAML frontmatter at the top of a markdown file.
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
# Matches a simple `key: value` line inside frontmatter.
KV_RE = re.compile(r"^(?P<key>[A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(?P<value>.*)$")
# Tokens for intent extraction (Spanish+English alphabet + accents).
INTENT_TOKEN_RE = re.compile(r"[a-záéíóúñüàèìòùâêîôûäëïöüçãæøå]{4,}")

# Stop-words that are too generic to serve as "intents" when surfacing
# a resource to an agent routing a user request.
STOPWORDS = frozenset(
    "para este esta desde como cada tiene puede cuando antes after with from "
    "that this will been have more than your into also sobre entre menos todos "
    "todas donde hasta tras sino pues luego mucho poco mismo cualquier "
    "necesita genera usa usar uso".split()
)


def classify_resource(resource_name: str, resource_description: str) -> str:
    """
    Pick one coarse category (development/quality/...) from the resource
    name + description. Name-prefix rules win over substring fallbacks so
    that `test-runner` classifies as 'quality' even if its description
    mentions 'deploy'.
    """
    name = resource_name.lower()
    # 1) Name-prefix rules (fast path, deterministic).
    prefix_rules: list[tuple[tuple[str, ...], str]] = [
        (("test-", "pr-", "security-", "a11y-", "qa-", "visual-", "coverage-", "perf-"), "quality"),
        (("spec-", "dev-", "arch-", "code-", "pipeline-", "deploy-", "dag-", "worktree-"), "development"),
        (("sprint-", "pbi-", "capacity-", "project-", "backlog-", "epic-", "flow-"), "planning"),
        (("report-", "dora-", "debt-", "risk-", "kpi-", "metric-", "trace-", "agent-"), "analysis"),
        (("memory-", "context-", "nl-", "session-", "compact-", "cache-"), "memory"),
        (("msg-", "notify-", "meeting-", "inbox-", "chat-", "slack-", "nctalk-", "savia-"), "communication"),
        (("compliance-", "governance-", "aepd-", "bias-", "equality-", "audit-"), "governance"),
    ]
    for prefixes, category in prefix_rules:
        if any(name.startswith(p) for p in prefixes):
            return category

    # 2) Substring fallback in combined text.
    combined = (name + " " + resource_description).lower()
    substring_rules: list[tuple[re.Pattern[str], str]] = [
        (re.compile(r"test|review|audit|security|lint|coverage"), "quality"),
        (re.compile(r"implement|code|build|deploy|spec|design"), "development"),
        (re.compile(r"sprint|capacity|estimat|decompos|assign|backlog"), "planning"),
        (re.compile(r"trace|metric|performance|debt|risk|report"), "analysis"),
        (re.compile(r"recall|save|search|consolidat|context|memory"), "memory"),
        (re.compile(r"notify|message|digest|meeting|inbox|chat"), "communication"),
        (re.compile(r"compliance|policy|governance|equality|aepd"), "governance"),
    ]
    for pattern, category in substring_rules:
        if pattern.search(combined):
            return category

    # 3) Default bucket.
    return "planning"


def extract_intents(description: str, max_tokens: int = 5) -> list[str]:
    """
    Return up to `max_tokens` "intent" keywords extracted from a description,
    sorted alphabetically and deduplicated. Lowercased, stopwords removed,
    only tokens of length >= 4. Used for quick fuzzy matching between user
    intent and resources at routing time.
    """
    tokens = INTENT_TOKEN_RE.findall(description.lower())
    unique = sorted({token for token in tokens if token not in STOPWORDS})
    return unique[:max_tokens]


def parse_frontmatter(file_path: Path) -> dict[str, str]:
    """
    Read a markdown file and return frontmatter keys as a flat dict
    (only top-level simple scalar values; nested YAML is ignored here
    because we never need it for indexing purposes).
    """
    try:
        text = file_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    match = FRONTMATTER_RE.search(text)
    if not match:
        return {}
    body = match.group(1)
    fields: dict[str, str] = {}
    for line in body.splitlines():
        # Skip continuation / list item lines; we only care about root scalars.
        if not line or line[0] in (" ", "\t", "-"):
            continue
        kv = KV_RE.match(line)
        if not kv:
            continue
        key = kv.group("key").lower()
        value = kv.group("value").strip()
        # Strip surrounding quotes.
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        fields[key] = value[:240]
    return fields


def extract_script_description(file_path: Path) -> str:
    """
    Try to extract a short description from a shell script by reading the
    first few `#` comment lines (skipping the shebang line).
    """
    try:
        with file_path.open("r", encoding="utf-8", errors="replace") as handle:
            for i, line in enumerate(handle):
                if i >= 6:
                    break
                # Skip shebang; otherwise return the first comment payload.
                if line.startswith("#!"):
                    continue
                stripped = line.strip()
                if stripped.startswith("#"):
                    return stripped.lstrip("#").strip()[:240]
    except OSError:
        pass
    return ""


class ResourceEntry:
    """One discovered resource (command/skill/agent/script) with its metadata."""

    __slots__ = ("category", "name", "intents", "kind", "rel_path", "description")

    def __init__(self, category: str, name: str, intents: list[str], kind: str,
                 rel_path: str, description: str) -> None:
        self.category = category
        self.name = name
        self.intents = intents
        self.kind = kind
        self.rel_path = rel_path
        self.description = description

    def index_line(self) -> str:
        """Render the one-line representation used in INDEX.scm."""
        joined_intents = ",".join(self.intents)
        return f"[{self.category}] {self.name} — {joined_intents} — {self.kind}:{self.rel_path}"

    def category_line(self) -> str:
        """Render the longer representation used in category files."""
        return f"- **{self.name}** ({self.kind}): {self.description}"

    def to_dict(self) -> dict[str, object]:
        """Serializable mirror for resources.json."""
        return {
            "category": self.category,
            "name": self.name,
            "intents": self.intents,
            "kind": self.kind,
            "path": self.rel_path,
            "description": self.description,
        }


def scan_markdown_resources(pattern_glob: Path, kind: str, rel_root: Path,
                            name_fallback) -> Iterable[ResourceEntry]:
    """
    Yield ResourceEntry objects for each markdown file matched by the glob.
    `name_fallback(path)` is called when frontmatter has no `name` key.
    """
    for file_path in pattern_glob:
        if not file_path.is_file():
            continue
        fields = parse_frontmatter(file_path)
        description = fields.get("description", "").strip()
        if not description:
            continue
        name = fields.get("name", "").strip() or name_fallback(file_path)
        if not name:
            continue
        intents = extract_intents(description)
        category = classify_resource(name, description)
        rel_path = file_path.relative_to(rel_root).as_posix()
        yield ResourceEntry(category, name, intents, kind, rel_path, description)


def scan_scripts(scripts_dir: Path, rel_root: Path) -> Iterable[ResourceEntry]:
    """Yield ResourceEntry objects for shell scripts in scripts/."""
    for file_path in sorted(scripts_dir.glob("*.sh")):
        if not file_path.is_file():
            continue
        description = extract_script_description(file_path)
        if not description:
            continue
        name = file_path.stem
        intents = extract_intents(description)
        category = classify_resource(name, description)
        rel_path = file_path.relative_to(rel_root).as_posix()
        yield ResourceEntry(category, name, intents, "script", rel_path, description)


def write_index_file(index_path: Path, resources: list[ResourceEntry]) -> None:
    """Write the flat INDEX.scm file with a summary header."""
    by_kind: dict[str, int] = {}
    for resource in resources:
        by_kind[resource.kind] = by_kind.get(resource.kind, 0) + 1

    header_lines = [
        "# Savia Capability Map — INDEX",
        f"> generated: {date.today().isoformat()} | resources: {len(resources)}",
        "> " + " · ".join(
            f"{by_kind.get(k, 0)} {label}"
            for k, label in (("cmd", "commands"), ("skill", "skills"),
                             ("agent", "agents"), ("script", "scripts"))
        ),
        "",
    ]
    sorted_resources = sorted(resources, key=lambda r: (r.category, r.name))
    body_lines = [resource.index_line() for resource in sorted_resources]
    index_path.write_text("\n".join(header_lines + body_lines) + "\n", encoding="utf-8")


def write_category_files(category_dir: Path, resources: list[ResourceEntry]) -> None:
    """Write one .scm file per category with a human-readable listing."""
    all_categories = ("quality", "development", "planning", "analysis",
                      "memory", "communication", "governance")
    grouped: dict[str, list[ResourceEntry]] = {cat: [] for cat in all_categories}
    for resource in resources:
        grouped.setdefault(resource.category, []).append(resource)

    for category in all_categories:
        entries = sorted(grouped.get(category, []), key=lambda r: r.name)
        lines = [
            f"# {category} — Savia Capability Map (L1)",
            f"> {len(entries)} resources",
            "",
        ]
        lines.extend(entry.category_line() for entry in entries)
        (category_dir / f"{category}.scm").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_resources_json(json_path: Path, resources: list[ResourceEntry]) -> None:
    """Write a machine-readable JSON mirror (used by hooks / fast lookups)."""
    payload = {
        "generated_utc": date.today().isoformat(),
        "total": len(resources),
        "resources": [r.to_dict() for r in sorted(resources, key=lambda r: (r.category, r.name))],
    }
    json_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main(argv: list[str]) -> int:
    start_time = time.monotonic()
    repo_root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[1]
    scm_dir = repo_root / ".scm"
    categories_dir = scm_dir / "categories"
    categories_dir.mkdir(parents=True, exist_ok=True)

    # Collect all resources from the 4 sources.
    resources: list[ResourceEntry] = []

    # Commands: .claude/commands/*.md
    commands_glob = (repo_root / ".claude" / "commands").glob("*.md")
    resources.extend(scan_markdown_resources(
        commands_glob, "cmd", repo_root,
        name_fallback=lambda path: path.stem,
    ))

    # Skills: .claude/skills/<skill-name>/SKILL.md
    skills_glob = (repo_root / ".claude" / "skills").glob("*/SKILL.md")
    resources.extend(scan_markdown_resources(
        skills_glob, "skill", repo_root,
        name_fallback=lambda path: path.parent.name,
    ))

    # Agents: .claude/agents/*.md
    agents_glob = (repo_root / ".claude" / "agents").glob("*.md")
    resources.extend(scan_markdown_resources(
        agents_glob, "agent", repo_root,
        name_fallback=lambda path: path.stem,
    ))

    # Scripts: scripts/*.sh  (not .py yet; keep parity with old script)
    resources.extend(scan_scripts(repo_root / "scripts", repo_root))

    write_index_file(scm_dir / "INDEX.scm", resources)
    write_category_files(categories_dir, resources)
    write_resources_json(scm_dir / "resources.json", resources)

    elapsed_seconds = time.monotonic() - start_time
    kind_totals = {k: sum(1 for r in resources if r.kind == k)
                   for k in ("cmd", "skill", "agent", "script")}
    print(
        f"SCM generated: {len(resources)} resources in {scm_dir}/  "
        f"({elapsed_seconds:.2f}s)"
    )
    print(
        f"  {kind_totals['cmd']} commands · {kind_totals['skill']} skills · "
        f"{kind_totals['agent']} agents · {kind_totals['script']} scripts"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
