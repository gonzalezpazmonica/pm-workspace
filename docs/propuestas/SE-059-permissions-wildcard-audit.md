---
id: SE-059
title: SE-059 — Permissions Wildcard Audit
status: PROPOSED
origin: output/research/agentshield-20260420.md (inspired by 10 permission rules)
author: Savia
priority: Alta
effort: S 4h
gap_link: Wildcard permissions sin deny list en .claude/settings.json
approved_at: null
applied_at: null
expires: "2026-05-20"
---

# SE-059 — Permissions Wildcard Audit

## Purpose

`.claude/settings.json` permite patrones tipo `Bash(*)`, `Write(*)`, `WebFetch(*)` que otorgan acceso sin restricción. Cuando `deny` list está vacía, el agent puede ejecutar cualquier comando shell o escribir en cualquier fichero.

Gap identificado en research agentshield: permisos por defecto en muchos workspaces exponen superficie de ataque innecesaria. En pm-workspace esto aplica a:

- `.claude/settings.json` (repo-level)
- `~/.claude/settings.json` (user-level)
- `.claude/settings.local.json` (gitignored, pero auditable localmente)

Cost of inaction: un prompt injection que llegue a ejecución tiene permisos totales sin barreras.

## Scope (Slice 1)

`scripts/permissions-wildcard-audit.sh`:
- Audita settings.json en niveles (repo, user, local)
- Detecta `allow` con wildcards sin `deny` complementario
- Detecta `defaultMode: "auto"` sin `skipAutoPermissionPrompt: false` para ops peligrosas
- Reporta findings JSON + human
- Sugiere deny patterns conservadores

## Reglas (8 checks Slice 1)

| ID | Rule | Severity |
|---|---|---|
| PERM-01 | `Bash(*)` allow sin `deny` list | HIGH |
| PERM-02 | `Write(*)` allow sin paths específicos | HIGH |
| PERM-03 | `WebFetch(*)` sin allowlist domain | MEDIUM |
| PERM-04 | `defaultMode: "auto"` + `skipAutoPermissionPrompt: true` | HIGH |
| PERM-05 | `deny` list ausente o vacía con wildcards | HIGH |
| PERM-06 | `Bash` pattern incluye `rm`, `dd`, `mkfs` sin restricción | CRITICAL |
| PERM-07 | `Bash` pattern incluye `curl -X POST` sin allowlist | MEDIUM |
| PERM-08 | Settings.json malformed JSON | MEDIUM |

## Acceptance criteria

- Script ejecutable con `--help`, `--json`, `--level [repo|user|local|all]`, exit 0/1/2
- 8 patrones detectados con tests BATS sintéticos
- Sugerencias `--suggest` para deny lists recomendadas
- Zero egress
- BATS ≥ 18 tests, score ≥ 80

## Referencias

- `output/research/agentshield-20260420.md` (inspiración, 10 permission rules)
- `.claude/settings.json` (target)
- Rule #8 autonomous-safety
