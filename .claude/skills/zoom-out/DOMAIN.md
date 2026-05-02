# zoom-out — Domain knowledge

## Origin

Pattern from `mattpocock/skills` (26.4k stars GitHub). The zoom-out
skill enforces architectural thinking by forcing a level-of-abstraction
shift before decisions are made.

## How it differs from architect agent

- `architect` agent DESIGNS solutions — it produces architecture
- `zoom-out` skill MAPS consequences — it observes and warns, doesn't design

The architect creates. Zoom-out illuminates. Both are needed.

## Integration with Savia

- Works as `/zoom-out` command
- Complements the `architect` agent (run zoom-out before architect)
- Feeds into `dev-orchestrator` for dependency-aware slicing
- Useful in `/pr-plan` to validate that the PR doesn't have cascading breaks

## Key dependency on Savia infra

- Requires knowledge of the repo structure (SCM, agent catalog, skill map)
- More effective after SE-088-UA-ADOPT (knowledge graph of the codebase)
