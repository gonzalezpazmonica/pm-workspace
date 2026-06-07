---
name: UA Domain
description: Extract business domain concepts and processes from any codebase
---

# /ua-domain — Domain Concept Extraction

Extracts business domain entities, processes, and flows from a codebase using
Understand-Anything's domain graph pipeline.

Results feed into the knowledge graph as `DOMAIN_ENTITY` nodes and integrate
with the Savia memory system via `memory-agent`.

## Usage

```
/ua-domain .                # analyze current workspace
/ua-domain ~/projects/foo   # analyze a specific project
```

## Output

- `DOMAIN_ENTITY` nodes in `knowledge-graph.json`
- Business process flows and domain concepts
- Integration-ready output for `memory-agent`

## Memory Integration

Extracted concepts are fed to `memory-agent` as `DOMAIN_TERM` edges:
```
knowledge-graph.json → memory-agent → DOMAIN_ENTITY entries
```

## Notes

If UA is not installed, reports gracefully and exits cleanly.
Bridge: `bash scripts/ua-bridge.sh domain [path]`

Ref: SPEC-SE-088-UA-ADOPT
