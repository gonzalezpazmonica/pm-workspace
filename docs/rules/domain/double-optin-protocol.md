# Double opt-in protocol for autonomous skills — SPEC-186

> Era 199 Wave 1. Apéndice extraído de `docs/rules/domain/autonomous-safety.md` para mantener el host bajo el cap de 150 líneas (Rule 11). Cierra el vector de activación accidental de skills autónomas por env vars heredadas en shells persistentes o runners CI.

## Principio

Ninguna skill autónoma arranca con UN solo factor. Se requieren **dos confirmaciones independientes** en CADA invocación:

1. **Variable de entorno persistente** (intención previa configurada)
2. **Flag explícito `--confirm-autonomous`** (intención inmediata en este run)

## Helper canónico

```
bash scripts/savia-double-optin-check.sh \
  --skill <nombre> --confirm-autonomous
```

Exit codes: `0` ambos OK · `1` falta factor · `2` invocación inválida.

## Mapeo skill → variable de entorno

| Skill | Variable | Exigido por |
|---|---|---|
| `overnight-sprint` | `OVERNIGHT_SPRINT_ENABLED=true` | gate § Prerequisitos |
| `code-improvement-loop` | `CODE_IMPROVEMENT_LOOP_ENABLED=true` | gate § Prerequisitos |
| `adversarial-security` | `ADVERSARIAL_SECURITY_ENABLED=true` | gate §0 |
| `tech-research-agent` | `TECH_RESEARCH_AGENT_ENABLED=true` | gate § Prerequisitos |
| `savia-dual` (failover) | `SAVIA_DUAL_FAILOVER_ENABLED=true` | gate § Prerequisitos |

## Auditoría

Cada intento (aceptado o denegado) se registra en `output/agent-runs/optin-audit.log` con campos: `timestamp`, `user`, `skill`, `env=0|1`, `flag=0|1`, `verdict=ok|denied`. Override: `SAVIA_OPTIN_AUDIT_LOG`.

## Bypass de tests

Único bypass válido: `SAVIA_TESTING=1` AND `BATS_TEST_NAME` definido (entorno BATS real). Cualquier otro contexto debe pasar el gate doble.

## Implementación

- Helper: `scripts/savia-double-optin-check.sh`
- Tests: `tests/test-savia-double-optin-check.bats` (24 BATS)
- Skills cubiertas: ver tabla anterior — gate inline en cada SKILL.md
- Spec origen: `docs/propuestas/SPEC-186-double-optin-autonomous-gates.md`
