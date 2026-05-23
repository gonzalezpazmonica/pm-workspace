# external/ — Vendored upstream code

Third-party code vendored verbatim from upstream repositories. Files here
preserve upstream structure, licenses, and naming. They are **not** subject
to the workspace's internal rules (Rule #11 150-line cap, CLAUDE.md drift
checks, agent registry, etc.) because doing so would diverge from upstream
and break the ability to track and re-sync changes.

## Vendoring policy

- Each subdirectory MUST carry the upstream LICENSE file verbatim.
- License MUST be permissive (Apache-2.0, MIT, BSD-2/3, ISC). GPL/AGPL is
  rejected — pm-workspace ships under its own license.
- A NOTICE-like provenance trail MUST exist (commit SHA, date, URL) either
  in this README or in `external/<pkg>/PROVENANCE.md`.
- Upstream files are **read-only** for the workspace. Local patches go in
  `external/<pkg>/patches/` as diffs, never inlined.

## Why outside `.claude/`

Workspace skills under `.claude/skills/` follow Savia's progressive
disclosure conventions (SKILL.md ≤150 lines, references in `references/`).
Anthropic's upstream `skill-creator/SKILL.md` is 485 lines by design. Forcing
it under `.claude/` would either:

1. violate Rule #11, or
2. require structural surgery that defeats the point of vendoring.

`external/` is the escape hatch: pristine upstream, ignored by workspace
auditors, available for reference and bootstrapping.

## Current inventory

| Path | Upstream | License | Date | Use |
|---|---|---|---|---|
| `anthropic-skills/skill-creator` | github.com/anthropics/skills | Apache-2.0 | 2026-05-23 | Reference template for authoring new SKILL.md |
| `anthropic-skills/mcp-builder` | github.com/anthropics/skills | Apache-2.0 | 2026-05-23 | Reference for SPEC-141 MCP catalog work |

## Updating

```bash
bash scripts/anthropic-skills-sync.sh   # (SPEC-145 follow-up, not yet shipped)
# or manually:
git clone --depth 1 https://github.com/anthropics/skills /tmp/aksk
cp -r /tmp/aksk/skill-creator external/anthropic-skills/
cp -r /tmp/aksk/mcp-builder   external/anthropic-skills/
# Commit with the upstream commit SHA in the message.
```
