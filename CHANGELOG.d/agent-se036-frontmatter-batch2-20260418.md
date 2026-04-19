---
version_bump: minor
section: Changed
---

### Changed

- **50 specs migrados a frontmatter YAML** (batch 2) vía \`scripts/spec-frontmatter-migrate.sh --apply --limit 50\`. Conjunto: SPEC-018..SPEC-118 + savia-enterprise/SPEC-SE-028/029/030. Mapping mecánico body-prose → YAML canónico.
- **Resultado**: \`spec-status-normalize.sh --audit\` reporta missing 96 → 46 (reducción 50 specs). Acumulado batch 1+2 = 65 specs con frontmatter canónico, 75% del gap original cerrado.

