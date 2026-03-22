#!/usr/bin/env python3
"""Generate training data for Savia context brain (SPEC-023 Phase 1).

Extracts instruction/response pairs from pm-workspace sources:
- memory-store JSONL → context recall pairs
- decision-log → decision explanation pairs
- commands → command routing pairs
- rules → knowledge pairs

Output: JSONL with {"instruction": "...", "response": "...", "source": "..."}
Usage: python3 scripts/generate-training-data.py [--store PATH] [--output PATH]
"""
import argparse
import glob
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))


def extract_from_memory_store(store_path: str) -> list[dict]:
    """Generate recall pairs from memory JSONL."""
    pairs = []
    if not os.path.exists(store_path):
        return pairs
    entries = []
    with open(store_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    for e in entries:
        title = e.get("title", "")
        content = e.get("content", "").replace("\\n", " ")
        etype = e.get("type", "")
        topic = e.get("topic_key", "")

        if not title or not content:
            continue

        # Pair 1: "What do you know about X?" → content
        pairs.append({
            "instruction": f"What do you remember about {title}?",
            "response": f"{content} (type: {etype}, topic: {topic})",
            "source": "memory-store",
        })

        # Pair 2: topic-based retrieval
        if topic and topic != "null":
            family = topic.split("/")[0] if "/" in topic else topic
            pairs.append({
                "instruction": f"Find memories about {family} topics",
                "response": f"{title}: {content[:150]}",
                "source": "memory-store",
            })

    return pairs


def extract_from_commands() -> list[dict]:
    """Generate routing pairs from command files."""
    pairs = []
    cmd_dir = ROOT / ".claude" / "commands"
    if not cmd_dir.exists():
        return pairs

    for md_file in sorted(cmd_dir.glob("*.md")):
        name = md_file.stem
        try:
            text = md_file.read_text(errors="replace")[:500]
        except Exception:
            continue

        # Extract first line as description
        lines = [l.strip() for l in text.split("\n") if l.strip() and not l.startswith("#")]
        desc = lines[0] if lines else name

        # Natural language → command routing
        variations = [
            f"How do I {name.replace('-', ' ')}?",
            f"I need to {name.replace('-', ' ')}",
            f"Run {name}",
        ]
        for v in variations:
            pairs.append({
                "instruction": v,
                "response": f"Use the /{name} command. {desc[:200]}",
                "source": f"command:{name}",
            })

    return pairs


def extract_from_rules() -> list[dict]:
    """Generate knowledge pairs from domain rules."""
    pairs = []
    rules_dir = ROOT / ".claude" / "rules" / "domain"
    if not rules_dir.exists():
        return pairs

    for md_file in sorted(rules_dir.glob("*.md"))[:30]:
        name = md_file.stem
        try:
            text = md_file.read_text(errors="replace")
        except Exception:
            continue

        # Extract first meaningful paragraph
        lines = text.split("\n")
        para = ""
        for line in lines:
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith(">") and not line.startswith("---"):
                para = line
                break

        if not para or len(para) < 20:
            continue

        topic = name.replace("-", " ")
        pairs.append({
            "instruction": f"What is the rule about {topic}?",
            "response": para[:300],
            "source": f"rule:{name}",
        })

    return pairs


def extract_from_skills() -> list[dict]:
    """Generate skill knowledge pairs."""
    pairs = []
    skills_dir = ROOT / ".claude" / "skills"
    if not skills_dir.exists():
        return pairs

    for skill_md in sorted(skills_dir.glob("*/SKILL.md"))[:30]:
        skill_name = skill_md.parent.name
        try:
            text = skill_md.read_text(errors="replace")
        except Exception:
            continue

        # Extract description from frontmatter
        desc_match = re.search(r'description:\s*["\'](.+?)["\']', text)
        desc = desc_match.group(1) if desc_match else ""

        if not desc:
            lines = [l.strip() for l in text.split("\n") if l.strip() and not l.startswith("#") and not l.startswith("---")]
            desc = lines[0] if lines else skill_name

        pairs.append({
            "instruction": f"What does the {skill_name.replace('-', ' ')} skill do?",
            "response": desc[:300],
            "source": f"skill:{skill_name}",
        })

    return pairs


def main():
    parser = argparse.ArgumentParser(description="Generate Savia training data (SPEC-023)")
    parser.add_argument("--store", default=str(ROOT / "output" / ".memory-store.jsonl"))
    parser.add_argument("--output", default=str(ROOT / "output" / "training" / "savia-context-v1.jsonl"))
    args = parser.parse_args()

    all_pairs = []

    print("Extracting from memory store...")
    all_pairs.extend(extract_from_memory_store(args.store))
    print(f"  {len(all_pairs)} pairs from memory")

    prev = len(all_pairs)
    print("Extracting from commands...")
    all_pairs.extend(extract_from_commands())
    print(f"  {len(all_pairs) - prev} pairs from commands")

    prev = len(all_pairs)
    print("Extracting from rules...")
    all_pairs.extend(extract_from_rules())
    print(f"  {len(all_pairs) - prev} pairs from rules")

    prev = len(all_pairs)
    print("Extracting from skills...")
    all_pairs.extend(extract_from_skills())
    print(f"  {len(all_pairs) - prev} pairs from skills")

    # Deduplicate by instruction
    seen = set()
    unique = []
    for p in all_pairs:
        key = p["instruction"]
        if key not in seen:
            seen.add(key)
            unique.append(p)

    # Write output
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w") as f:
        for p in unique:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")

    print(f"\nTotal: {len(unique)} unique training pairs -> {args.output}")
    by_source = {}
    for p in unique:
        src = p["source"].split(":")[0]
        by_source[src] = by_source.get(src, 0) + 1
    for src, count in sorted(by_source.items(), key=lambda x: -x[1]):
        print(f"  {src}: {count}")


if __name__ == "__main__":
    main()
