---
version_bump: minor
section: Added
---

### Added

- `docs/propuestas/SPEC-127-savia-opencode-copilot-enterprise-compat.md` — PROPOSED. Audit Savia ↔ OpenCode + GitHub Copilot Enterprise compatibility. 5 slices (Foundation 8h · Hook adapter+TS plugin 16-20h · Slash command MCP shim 12-16h · Subagent fallback 8-12h · Premium quota guard 6h ≈ 50-62h total). Documents 5 critical frictions (compaction #11157, hooks port bash→TS plugin, GHE on-prem auth #3936, premium request inflation #8030, context cap 128K #5993) + 3 categorical breaks vs OpenCode-Claude (zero hook surface, no subagent fan-out, no workspace slash commands). Restricciones inviolables PV-01 a PV-05. Compatibility matrix Claude Code | OpenCode-Claude | OpenCode-Copilot | Risk. Top 10 priority changes + 5 decisiones pendientes para revisor humano. Sin parity completa — re-route strategies (MCP for commands, git pre-commit for hooks, single-shot for orchestrators).
