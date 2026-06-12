---
version_bump: minor
section: Security
---

### Security

- se-220: memory dedup by topic_key prevents AgentPoison-style memory poisoning (MEMORY.md 737→43 lines, 0 duplicates)
- se-220: project-isolation-gate.sh promoted from WARN to BLOCK with SAVIA_ALLOW_CROSS_PROJECT=1 override + audit log
- se-220: prompt-injection-guard.sh extended to scan untrusted .md/.txt/.html outside workspace (zero-trust spotlighting)
- se-220: agent catalogs unified to .opencode/agents/ source-of-truth (72 agents, drift eliminated, skill confusion mitigated)
- se-220: scripts/memory-canary-check.sh + canary token defense against memory poisoning (Chen et al. 2024)

