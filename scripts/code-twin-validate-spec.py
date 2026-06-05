#!/usr/bin/env python3
"""
code-twin-validate-spec.py — SPEC-190 Slice 6

Validates a new spec draft against an Application Code Twin (ACT).
Detects route conflicts, entity duplicates, and business rule contradictions.
Computes a feasibility_score and emits structured JSON.

Usage:
  python3 scripts/code-twin-validate-spec.py <spec_md> <code_twin_dir>

Arguments:
  spec_md        — path to the spec markdown file to validate
  code_twin_dir  — path to the root of the code twin directory

Exit codes:
  0 — feasibility_score >= 70 (spec is viable)
  1 — feasibility_score < 70 (too many conflicts — rework needed)
  2 — engine error (bad args, missing files)

Output:
  JSON to stdout:
  {
    "spec": "<basename>",
    "code_twin_dir": "<path>",
    "feasibility_score": <int 0-100>,
    "conflicts": [...],
    "missing_modules": [...],
    "warnings": [...],
    "impact_map": {...},
    "validated_at": "<ISO8601>"
  }

Algorithm (SPEC-190 §3.5):
  1. Parse spec: extract new_endpoints, new_entities, new_business_rules
  2. For each endpoint: check api/routes.md → route_duplicate conflict
  3. For each entity: check domain/entities.md → entity_duplicate conflict
  4. For each rule: heuristic contradiction check vs business-rules.md
  5. impact_map via CTI depends_on reverse-lookup
  6. feasibility_score = max(0, 100 - conflicts*20 - missing*10 - warnings*5)
  7. Exit 0 if score >= 70, else exit 1
"""

import sys
import os
import json
import re
import pathlib
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SCORE_EXIT_THRESHOLD = 70
SCORE_BASE = 100
SCORE_CONFLICT_PENALTY = 20
SCORE_MISSING_PENALTY = 10
SCORE_WARNING_PENALTY = 5

# Regex: match (METHOD /path) anywhere in text
ENDPOINT_RE = re.compile(
    r'\b(GET|POST|PUT|DELETE|PATCH)\s+(/[a-zA-Z0-9/_:.{}-]+)',
    re.IGNORECASE,
)

# Regex: match H2/H3 headings that look like entity/model/DTO names
ENTITY_HEADING_RE = re.compile(
    r'(?:^|\n)#{2,3}\s+([A-Z][a-zA-Z0-9]+)',
    re.MULTILINE,
)

# Regex: business rule sentences
RULE_RE = re.compile(
    r'(?:must|never|always|prohibit|require)[^\n.]{5,80}',
    re.IGNORECASE,
)

# Section headings to skip from entity extraction
_SKIP_HEADINGS = {
    "Acceptance", "Scope", "Background", "Context", "Logic",
    "Returns", "Calls", "Auth", "Body", "Query", "Fields",
    "Invariants", "Factory", "Identity", "Status", "Example",
    "Notes", "Summary", "Overview", "Design", "Implementation",
    "Algorithm", "Configuration", "API", "Changes", "New",
    "Data", "Transfer", "Object",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def err(msg: str, code: int = 2) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def read_file(path) -> str:
    try:
        return pathlib.Path(path).read_text(encoding="utf-8")
    except OSError:
        return ""


def normalize_path(path: str) -> str:
    """Normalize route path: collapse :param and {param} to :param form."""
    return re.sub(r'\{[^}]+\}', ':param', re.sub(r':\w+', ':param', path))


# ---------------------------------------------------------------------------
# Spec parsing
# ---------------------------------------------------------------------------

def parse_spec(spec_content: str) -> tuple:
    """
    Extract from spec markdown:
      - new_endpoints: list of {"method": str, "path": str}
      - new_entities: list of str (CamelCase headings)
      - new_rules: list of str (business rule fragments)
    """
    # Endpoints: deduplicate preserving first occurrence
    endpoints = []
    seen_eps = set()
    for m in ENDPOINT_RE.finditer(spec_content):
        method = m.group(1).upper()
        path = m.group(2).rstrip('.,)')
        key = f"{method} {path}"
        if key not in seen_eps:
            seen_eps.add(key)
            endpoints.append({"method": method, "path": path})

    # Entities: H2/H3 CamelCase headings (filter noise)
    entities = []
    seen_ents = set()
    for m in ENTITY_HEADING_RE.finditer(spec_content):
        name = m.group(1)
        if name not in _SKIP_HEADINGS and name not in seen_ents:
            seen_ents.add(name)
            entities.append(name)

    # Business rules
    rules = RULE_RE.findall(spec_content)

    return endpoints, entities, rules


# ---------------------------------------------------------------------------
# Conflict detection
# ---------------------------------------------------------------------------

def check_route_conflicts(endpoints: list, twin_dir: str) -> list:
    """
    For each new endpoint in the spec, check if METHOD /path already exists
    in <twin_dir>/api/routes.md. Returns list of route_duplicate conflicts.
    """
    routes_path = os.path.join(twin_dir, "api", "routes.md")
    routes_content = read_file(routes_path)
    if not routes_content:
        return []

    routes_lines = routes_content.splitlines()
    conflicts = []

    for ep in endpoints:
        method = ep["method"]
        spec_path_norm = normalize_path(ep["path"])

        # Build pattern: \bMETHOD\s+<normalized_path>(?:\s|$)
        escaped = re.escape(spec_path_norm)
        pattern = re.compile(
            rf'\b{re.escape(method)}\s+{escaped}(?:\s|$)',
            re.IGNORECASE,
        )

        for lineno, line in enumerate(routes_lines, 1):
            line_norm = normalize_path(line)
            if pattern.search(line_norm):
                conflicts.append({
                    "type": "route_duplicate",
                    "endpoint": f"{method} {ep['path']}",
                    "existing_in": f"api/routes.md:{lineno}",
                })
                break  # first occurrence is enough

    return conflicts


def check_entity_conflicts(entities: list, twin_dir: str) -> list:
    """
    For each new entity in the spec, check if it already exists as an H2
    heading in <twin_dir>/domain/entities.md.
    """
    entities_path = os.path.join(twin_dir, "domain", "entities.md")
    entities_content = read_file(entities_path)
    if not entities_content:
        return []

    conflicts = []
    for entity in entities:
        pattern = re.compile(
            rf'^##\s+{re.escape(entity)}\b',
            re.MULTILINE,
        )
        if pattern.search(entities_content):
            conflicts.append({
                "type": "entity_duplicate",
                "entity": entity,
                "existing_in": "domain/entities.md",
            })

    return conflicts


def check_rule_conflicts(rules: list, twin_dir: str) -> list:
    """
    Heuristic contradiction check: 'never X' vs existing 'must X' (or vice versa)
    on the same subject in business-rules.md.
    """
    rules_path = os.path.join(twin_dir, "domain", "business-rules.md")
    rules_content = read_file(rules_path)
    if not rules_content:
        return []

    conflicts = []
    for rule in rules[:5]:  # cap to avoid noise
        words = re.findall(r'\b[a-zA-Z]{4,}\b', rule.lower())
        if not words:
            continue
        subject = words[0]

        if re.search(r'\bnever\b', rule, re.I):
            if re.search(rf'\bmust\b[^.]*\b{re.escape(subject)}\b', rules_content, re.I):
                conflicts.append({
                    "type": "rule_contradiction",
                    "rule": rule.strip()[:120],
                    "existing_in": "domain/business-rules.md",
                })
        elif re.search(r'\bmust\b', rule, re.I):
            if re.search(rf'\bnever\b[^.]*\b{re.escape(subject)}\b', rules_content, re.I):
                conflicts.append({
                    "type": "rule_contradiction",
                    "rule": rule.strip()[:120],
                    "existing_in": "domain/business-rules.md",
                })

    return conflicts


# ---------------------------------------------------------------------------
# Impact map
# ---------------------------------------------------------------------------

def build_impact_map(conflicts: list, twin_dir: str) -> dict:
    """
    For each conflict, return the list of module_ids in the CTI that
    depend on (or provide) the affected resource.
    """
    index_content = read_file(os.path.join(twin_dir, "index.md"))
    impact_map = {}

    for conflict in conflicts:
        resource = conflict.get("endpoint") or conflict.get("entity") or "unknown"
        # Heuristic: find module_ids in CTI index that reference words from resource
        key_words = set(w.lower() for w in re.findall(r'\b[a-zA-Z]{3,}\b', resource))
        matched_modules = []
        for line in index_content.splitlines():
            if any(kw in line.lower() for kw in key_words):
                # Extract CamelCase or kebab-case identifiers that look like module_ids
                ids = re.findall(r'\b[A-Z][a-zA-Z0-9]+\b|\b[a-z][a-z0-9]+(?:-[a-z0-9]+)+\b', line)
                matched_modules.extend(ids[:3])

        # Deduplicate and filter noise
        seen = set()
        unique_modules = []
        for m in matched_modules:
            if m not in seen and m not in {"md", "path", "layer", "tokens"}:
                seen.add(m)
                unique_modules.append(m)

        impact_map[resource] = unique_modules[:5]

    return impact_map


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def compute_score(conflicts: list, missing: list, warnings: list) -> int:
    """feasibility_score = max(0, 100 - conflicts*20 - missing*10 - warnings*5)"""
    return max(
        0,
        SCORE_BASE
        - len(conflicts) * SCORE_CONFLICT_PENALTY
        - len(missing) * SCORE_MISSING_PENALTY
        - len(warnings) * SCORE_WARNING_PENALTY,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) != 3:
        err(f"Usage: {os.path.basename(sys.argv[0])} <spec_md> <code_twin_dir>")

    spec_path = sys.argv[1]
    twin_dir = sys.argv[2]

    if not os.path.isfile(spec_path):
        err(f"spec_md not found: {spec_path}")

    if not os.path.isdir(twin_dir):
        err(f"code_twin_dir not found: {twin_dir}")

    spec_content = read_file(spec_path)
    endpoints, entities, rules = parse_spec(spec_content)

    # Detect all conflicts
    route_conflicts = check_route_conflicts(endpoints, twin_dir)
    entity_conflicts = check_entity_conflicts(entities, twin_dir)
    rule_conflicts = check_rule_conflicts(rules, twin_dir)
    all_conflicts = route_conflicts + entity_conflicts + rule_conflicts

    missing: list = []   # future: required module detection
    warnings: list = []  # future: unknown guard detection

    score = compute_score(all_conflicts, missing, warnings)
    impact_map = build_impact_map(all_conflicts, twin_dir)

    result = {
        "spec": os.path.basename(spec_path),
        "code_twin_dir": twin_dir,
        "feasibility_score": score,
        "conflicts": all_conflicts,
        "missing_modules": missing,
        "warnings": warnings,
        "impact_map": impact_map,
        "validated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    print(json.dumps(result, indent=2))
    sys.exit(0 if score >= SCORE_EXIT_THRESHOLD else 1)


if __name__ == "__main__":
    main()
