#!/usr/bin/env python3
"""Memory graph — entity-relation extraction over plain-text JSONL (SPEC-027 Phase 1).

Extracts entities and relationships from memory-store entries using regex+heuristics.
Graph is derived (regenerable), gitignored. JSONL remains source of truth.

Usage:
    python3 memory-graph.py build [--store PATH]
    python3 memory-graph.py search "query" [--store PATH]
    python3 memory-graph.py status [--store PATH]
    python3 memory-graph.py entities [--type TYPE] [--store PATH]
"""
import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(os.environ.get("PROJECT_ROOT", Path(__file__).parent.parent))
DEFAULT_STORE = os.environ.get(
    "STORE_FILE",
    str(ROOT / "output" / ".memory-store.jsonl"),
)


def _graph_path(store: str) -> str:
    return store.replace(".jsonl", "-graph.json")


def _load_jsonl(store: str) -> list[dict]:
    entries = []
    if not os.path.exists(store):
        return entries
    with open(store) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def extract_entities(entry: dict) -> list[dict]:
    """Extract entities from a single memory entry."""
    entities = []
    title = entry.get("title", "")
    content = entry.get("content", "").replace("\\n", " ")
    topic = entry.get("topic_key", "")
    etype = entry.get("type", "")
    text = f"{title} {content}"

    # 1. Topic key family as category
    if "/" in topic:
        family = topic.split("/")[0]
        entities.append({"name": family, "type": "category", "source": "topic_key"})

    # 2. Capitalized multi-word names (technologies, tools, frameworks)
    caps = re.findall(r'\b([A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*)\b', text)
    tech_stops = {"What", "Why", "Where", "Learned", "Goal", "Session",
                  "Discoveries", "Accomplished", "Files", "The", "This",
                  "That", "When", "How", "But", "And", "Not"}
    for cap in caps:
        if cap not in tech_stops and len(cap) > 2:
            entities.append({"name": cap, "type": "named", "source": "capitalized"})

    # 3. Technology patterns (common tech names even lowercase)
    tech_re = r'\b(postgresql|redis|graphql|kubernetes|docker|terraform|oauth2?|jwt|nginx|kafka|elasticsearch|mongodb|react|angular|vue|fastapi|django|flask|spring|express|nestjs|prisma|sqlalchemy)\b'
    techs = re.findall(tech_re, text, re.IGNORECASE)
    for t in techs:
        entities.append({"name": t.capitalize(), "type": "technology", "source": "pattern"})

    # 4. Concepts from the concepts field
    concepts = entry.get("concepts", [])
    if isinstance(concepts, list):
        for c in concepts:
            if c and c != "null":
                entities.append({"name": c, "type": "concept", "source": "field"})

    # 5. Project
    project = entry.get("project", "")
    if project and project != "null":
        entities.append({"name": project, "type": "project", "source": "field"})

    return entities


def extract_relations(entry: dict, entities: list[dict]) -> list[dict]:
    """Extract relations between entities based on entry context."""
    relations = []
    etype = entry.get("type", "")
    topic = entry.get("topic_key", "")
    title = entry.get("title", "")

    entity_names = [e["name"] for e in entities]

    # SE-076 Slice 1: episodes emit MENTIONED_IN (entity → episode_title).
    if etype == "episode":
        for ref in (entry.get("entities") or []):
            if isinstance(ref, str) and ref:
                relations.append({"from": ref, "to": title or topic or "(episode)",
                                  "type": "MENTIONED_IN", "source_title": title, "source_topic": topic})

    if len(entity_names) < 2:
        return relations

    # Relation type from memory type
    rel_type_map = {
        "decision": "decided",
        "bug": "affected_by",
        "pattern": "uses_pattern",
        "discovery": "discovered_in",
        "convention": "follows",
        "architecture": "architected_with",
        "config": "configured_with",
        "episode": "co_occurred_in",  # SE-076 Slice 1
    }
    rel_type = rel_type_map.get(etype, "related_to")

    # Create relations between co-occurring entities
    # First entity is usually the subject, rest are objects
    subject = entity_names[0]
    for obj in entity_names[1:]:
        if subject != obj:
            relations.append({
                "from": subject,
                "to": obj,
                "type": rel_type,
                "source_title": title,
                "source_topic": topic,
            })

    return relations


def cmd_build(store: str) -> None:
    """Build entity-relation graph from JSONL."""
    entries = _load_jsonl(store)
    if not entries:
        print("No entries. Nothing to build.")
        return

    all_entities = defaultdict(lambda: {"type": "", "mentions": 0, "sources": set()})
    all_relations = []

    for entry in entries:
        ents = extract_entities(entry)
        for e in ents:
            key = e["name"].lower()
            all_entities[key]["name"] = e["name"]
            all_entities[key]["type"] = e["type"]
            all_entities[key]["mentions"] += 1
            all_entities[key]["sources"].add(e["source"])

        rels = extract_relations(entry, ents)
        all_relations.extend(rels)

    # Deduplicate relations
    seen_rels = set()
    unique_rels = []
    for r in all_relations:
        key = (r["from"].lower(), r["to"].lower(), r["type"])
        if key not in seen_rels:
            seen_rels.add(key)
            unique_rels.append(r)

    # Serialize (convert sets to lists)
    entity_list = []
    for key, data in sorted(all_entities.items(), key=lambda x: -x[1]["mentions"]):
        entity_list.append({
            "name": data["name"],
            "type": data["type"],
            "mentions": data["mentions"],
            "sources": list(data["sources"]),
        })

    graph = {
        "entities": entity_list,
        "relations": unique_rels,
        "stats": {
            "total_entries": len(entries),
            "total_entities": len(entity_list),
            "total_relations": len(unique_rels),
        },
    }

    # Write atomically
    graph_path = _graph_path(store)
    tmp = graph_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(graph, f, indent=2, ensure_ascii=False)
    os.replace(tmp, graph_path)

    print(f"Graph: {len(entity_list)} entities, {len(unique_rels)} relations -> {graph_path}")
    # Top entities
    for e in entity_list[:10]:
        print(f"  {e['name']} ({e['type']}, {e['mentions']}x)")


def cmd_search(store: str, query: str) -> None:
    """Search graph for entities matching query, return related entities."""
    graph_path = _graph_path(store)
    if not os.path.exists(graph_path):
        print(json.dumps({"error": "No graph. Run: python3 scripts/memory-graph.py build"}))
        return

    with open(graph_path) as f:
        graph = json.load(f)

    query_lower = query.lower()

    # Find matching entities
    matches = [e for e in graph["entities"] if query_lower in e["name"].lower()]

    # Find related entities via relations
    related = set()
    match_names = {m["name"].lower() for m in matches}
    for r in graph["relations"]:
        if r["from"].lower() in match_names:
            related.add(r["to"])
        if r["to"].lower() in match_names:
            related.add(r["from"])

    results = {
        "query": query,
        "entities": matches[:10],
        "related": list(related)[:15],
        "relations": [r for r in graph["relations"]
                      if r["from"].lower() in match_names or r["to"].lower() in match_names][:10],
    }
    print(json.dumps(results, indent=2, ensure_ascii=False))


def cmd_entities(store: str, etype: str = "") -> None:
    """List all entities, optionally filtered by type."""
    graph_path = _graph_path(store)
    if not os.path.exists(graph_path):
        print("No graph. Run: python3 scripts/memory-graph.py build")
        return

    with open(graph_path) as f:
        graph = json.load(f)

    for e in graph["entities"]:
        if etype and e["type"] != etype:
            continue
        print(f"  {e['name']} ({e['type']}, {e['mentions']}x)")


def cmd_status(store: str) -> None:
    """Show graph status."""
    graph_path = _graph_path(store)
    store_exists = os.path.exists(store)
    graph_exists = os.path.exists(graph_path)

    store_lines = 0
    if store_exists:
        with open(store) as f:
            store_lines = sum(1 for l in f if l.strip())

    if graph_exists:
        with open(graph_path) as f:
            graph = json.load(f)
        stats = graph.get("stats", {})
        print(f"Store: {store_lines} entries")
        print(f"Graph: {stats.get('total_entities', 0)} entities, {stats.get('total_relations', 0)} relations")
        stale = store_lines > stats.get("total_entries", 0)
        print("STALE — rebuild needed" if stale else "UP TO DATE")
    else:
        print(f"Store: {store_lines} entries")
        print("Graph: NOT BUILT — run: python3 scripts/memory-graph.py build")


def main():
    parser = argparse.ArgumentParser(description="Memory graph (SPEC-027)")
    parser.add_argument("command", choices=["build", "search", "entities", "status"])
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("--store", default=DEFAULT_STORE)
    parser.add_argument("--type", default="")
    args = parser.parse_args()

    if args.command == "build":
        cmd_build(args.store)
    elif args.command == "search":
        if not args.query:
            print("Error: query required", file=sys.stderr)
            sys.exit(1)
        cmd_search(args.store, args.query)
    elif args.command == "entities":
        cmd_entities(args.store, args.type)
    elif args.command == "status":
        cmd_status(args.store)


if __name__ == "__main__":
    main()
