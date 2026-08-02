---
context_tier: L2
token_budget: 380
---

# Execution Containment Policy

SE-292 S1+S7 — Policy governing execution levels and autonomy.

## Execution Levels

| Level | Scope | Environment | Credentials | Filesystem | Network |
|---|---|---|---|---|---|
| N-anfitrion | Own reviewed code | Host | Present | Full | Open |
| N-contenido | Code written this turn | Container | None | Read-only mounts | Denied |
| N-hostil | Client/untrusted code | Container | None | Ephemeral | Denied |

## Classification Rules

- By origin, not content: classified by provenance, not by inspection
- Script without level: detected by self-audit, must be classified
- Exceptions: must justify + expire (SE-274 pattern)

## Containment State

- AVAILABLE: Docker + image present → full containment
- UNAVAILABLE: No Docker → N-contenido/N-hostil disabled
- Fail-closed: without containment, contained tasks do NOT execute on host

## Autonomy Gates

- Autonomy expansion requires reliability evidence (S6)
- Absence of incidents is NOT evidence
- Review frontier in self-audit (SE-258 S3)

## Adversarial Suite (CI)

1. Credential leak — host secrets unreachable
2. Write outside work dir — blocked
3. Cross-client isolation — murallas efectivas
4. Privilege escalation — sudo disabled
5. Silent fallback — no repliegue al anfitrion
6. Autonomy without evidence — blocked
