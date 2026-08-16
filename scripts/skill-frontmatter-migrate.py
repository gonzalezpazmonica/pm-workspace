#!/usr/bin/env python3
"""SE-333 S2 — migrate SKILL.md frontmatter proprietary fields to metadata.savia.*

Surgical migration: parses only the YAML frontmatter block, moves the
proprietary top-level fields into `metadata.savia.*` (string->string, lists
comma-joined), keeps `name`/`description`/`license`/`compatibility` top-level,
and leaves the body byte-for-byte untouched.

Usage:
  python3 scripts/skill-frontmatter-migrate.py --apply     # rewrite in place
  python3 scripts/skill-frontmatter-migrate.py             # dry-run (report only)

Ref: docs/specs/SE-333-agent-plugins-compliance.spec.md
"""
import sys
import re
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = Path(__import__("os").environ.get("SKILLS_DIR", ROOT / ".claude" / "skills"))
TEMPLATE_DIR = SKILLS_DIR / "_template"

# Fields that STAY top-level (standard)
KEEP_TOP = {"name", "description", "license", "compatibility", "allowed-tools"}

# Proprietary fields to migrate -> metadata.savia.<key>
# Lists are comma-joined into a single string.
LIST_FIELDS = {"tags", "consumes", "produces", "trigger"}
SCALAR_FIELDS = {
    "summary", "maturity", "context", "context_cost", "agent",
    "category", "priority", "loop_level",
}

# Fields that are NOT part of the standard contract but appear in a few skills.
# These are informational/metadata-like: also moved under metadata.savia.*.
EXTRA_MOVE = {
    "dependencies", "memory", "se", "references", "developer_type",
    "model", "authorization_required", "output_max_tokens",
    "max_context_tokens", "attribution", "version", "token_budget",
    "recommends", "output", "input", "globs", "bioquimica", "context_tier",
    "disable-model-invocation", "user-invocable", "argument-hint",
}


def parse_frontmatter(text: str):
    """Return (fm_block, body, delimiters) split on `---` lines."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, text, None
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return None, text, None
    fm = "\n".join(lines[1:end])
    body = "\n".join(lines[end + 1:])
    return fm, body, end


def split_top_level(fm: str):
    """Split frontmatter into (key, block) top-level entries preserving order.

    Handles: inline scalars, block scalars (| >), inline lists, block lists,
    nested objects (trigger), and comments.
    """
    entries = []
    lines = fm.split("\n")
    i = 0
    key_re = re.compile(r"^([A-Za-z0-9_-]+):")
    while i < len(lines):
        line = lines[i]
        m = key_re.match(line)
        if m:
            key = m.group(1)
            block = [line]
            j = i + 1
            # Collect continuation lines (indented) or block scalars
            while j < len(lines):
                nxt = lines[j]
                if nxt.startswith("---"):
                    break
                if nxt == "" or nxt.startswith(" ") or nxt.startswith("\t"):
                    block.append(nxt)
                    j += 1
                elif nxt.startswith("- ") and (key in LIST_FIELDS):
                    block.append(nxt)
                    j += 1
                else:
                    break
            entries.append((key, block))
            i = j
        else:
            # Comment or blank line at top level — attach to previous? Keep separate.
            entries.append((None, [line]))
            i += 1
    return entries


def yaml_scalar(value) -> str:
    """Serialize a python value into a YAML single-line quoted string."""
    if isinstance(value, bool):
        s = "true" if value else "false"
    elif isinstance(value, list):
        s = ", ".join(str(v) for v in value)
    elif isinstance(value, dict):
        s = json.dumps(value, ensure_ascii=False)
    else:
        s = str(value)
    # Collapse newlines inside block scalars -> single-line string
    s = re.sub(r"\s+", " ", s).strip()
    # Emit a single-line YAML scalar. Double-quote when the value contains
    # characters that YAML would parse specially (: # , { } [ ] leading -).
    if re.search(r"[:#,\[\]{}]|^\s*[-?]|:\s", s):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return s


def migrate_block(entries):
    """Return (new_fm_lines, migrated_report)."""
    out = []
    report = []
    # First pass: collect metadata.savia.* values
    meta = {}
    for key, block in entries:
        if key is None:
            continue
        if key in KEEP_TOP:
            continue
        if key == "metadata":
            continue
        fm_block = "\n".join(block)
        # Parse value with yaml if available, else manual
        try:
            import yaml
            # Build a minimal mapping to parse the block value
            doc = yaml.safe_load(fm_block + "\n")
            if isinstance(doc, dict):
                val = doc.get(key)
            else:
                val = None
        except Exception:
            val = None

        if key == "trigger" and isinstance(val, dict):
            kw = val.get("keywords", [])
            if isinstance(kw, list):
                meta["savia.trigger_keywords"] = yaml_scalar(", ".join(str(k) for k in kw))
                report.append(f"{key}.keywords -> savia.trigger_keywords")
            continue

        if key in LIST_FIELDS and isinstance(val, list):
            meta[f"savia.{key}"] = yaml_scalar(", ".join(str(v) for v in val))
            report.append(f"{key} -> savia.{key}")
        elif key in SCALAR_FIELDS or key in EXTRA_MOVE:
            meta[f"savia.{key}"] = yaml_scalar(val) if val is not None else ""
            report.append(f"{key} -> savia.{key}")
        else:
            # Unknown top-level field: warn but do not move (keep non-fatal)
            report.append(f"{key} -> UNTOUCHED (unknown)")

    # Second pass: rebuild
    for key, block in entries:
        if key is None:
            out.append(block[0])
            continue
        if key == "metadata":
            # Merge into existing metadata (append savia.* after existing keys)
            existing = [l for l in block]
            # Emit existing lines, then savia entries
            out.extend(existing)
            out.append("  # --- metadata.savia.* (SE-333) ---")
            for mk, mv in sorted(meta.items()):
                out.append(f"  {mk}: {mv}")
            meta.clear()  # consumed
            continue
        if key in KEEP_TOP:
            # Normalize: ensure `description` is a valid single-line YAML scalar
            # (some skills have unquoted descriptions containing ": " -> invalid
            # YAML already in the source). Quote it for conformance.
            if key == "description" and len(block) == 1:
                line = block[0]
                m2 = re.match(r"^description:\s*(.*)$", line)
                if m2:
                    val = m2.group(1).strip().strip('"').strip("'")
                    out.append(f"description: {yaml_scalar(val)}")
                    continue
            out.extend(block)
            continue
        # Migrated field: skip (already captured in metadata)
        if key in SCALAR_FIELDS or key in LIST_FIELDS or key in EXTRA_MOVE:
            continue

    # If no existing metadata block, append one
    if meta:
        if any(k == "metadata" for k, _ in entries):
            pass  # should not happen (meta cleared above)
        else:
            out.append("metadata:")
            out.append("  # --- metadata.savia.* (SE-333) ---")
            for mk, mv in sorted(meta.items()):
                out.append(f"  {mk}: {mv}")
            meta.clear()

    return out, report


def process(skill_md: Path, apply: bool):
    text = skill_md.read_text(encoding="utf-8")
    fm, body, end = parse_frontmatter(text)
    if fm is None:
        return skill_md, "NO_FRONTMATTER", []
    entries = split_top_level(fm)
    new_fm, report = migrate_block(entries)
    new_text = "---\n" + "\n".join(new_fm) + "\n---\n" + body
    if apply and new_text != text:
        skill_md.write_text(new_text, encoding="utf-8")
    changed = new_text != text
    return skill_md, "CHANGED" if changed else "UNCHANGED", report


def main():
    apply = "--apply" in sys.argv
    total = changed = 0
    problems = []
    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        if TEMPLATE_DIR in skill_md.parents:
            continue
        if skill_md.name != "SKILL.md":
            continue
        total += 1
        path, status, report = process(skill_md, apply)
        if status == "CHANGED":
            changed += 1
            print(f"{'[apply]' if apply else '[dry] '} {path.relative_to(ROOT) if str(path).startswith(str(ROOT)) else path}")
            for r in report:
                if not r.endswith("UNTOUCHED"):
                    print(f"          {r}")
        elif status == "NO_FRONTMATTER":
            problems.append(str(path))
    print(f"\nTotal={total} Changed={changed} Apply={apply}")
    if problems:
        print("NO_FRONTMATTER:", *problems, sep="\n  ")


if __name__ == "__main__":
    main()
