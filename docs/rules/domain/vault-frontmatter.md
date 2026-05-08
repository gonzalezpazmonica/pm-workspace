# Regla: Frontmatter obligatorio en Vault de proyecto (F1)

> **REGLA INMUTABLE** — Todo `*.md` bajo `projects/*/vault/` DEBE incluir frontmatter YAML válido.
> Aplica desde SPEC-PROJECT-UPDATE Fase 1. Complementa `data-sovereignty.md` y `zero-project-leakage.md`.

---

## Principio

El vault embebido por proyecto (`projects/{slug}_main/{slug}-{username}/vault/`) es nivel de
confidencialidad **N4** (proyecto) o **N4b** (PM-only). Cada nota DEBE declarar metadatos
mínimos verificables por máquina antes de escribirse en disco. Sin frontmatter válido, la
escritura se bloquea.

## Qué exige el gate

`*.md` bajo `projects/*/vault/` se valida con `scripts/vault-validate.py` antes de cada Edit/Write/MultiEdit.

### Campos comunes obligatorios

```yaml
---
confidentiality: N4              # uno de N1|N2|N3|N4|N4b
project: my-project              # slug del proyecto (kebab-case)
entity_type: pbi                 # uno de los 10 tipos soportados
title: "Título humano"
created: 2026-05-07
updated: 2026-05-07
---
```

### Campos requeridos por `entity_type`

| entity_type | Campos adicionales |
|---|---|
| `pbi` | `pbi_id`, `state` |
| `decision` | `decision_id`, `decided_at` |
| `meeting` | `meeting_id`, `meeting_date`, `attendees`, `transcript_source`, `digest_status` |
| `person` | `role` |
| `risk` | `risk_id`, `severity`, `status`, `owner` |
| `spec` | `spec_id`, `status` |
| `session` | `session_date`, `frontend` |
| `digest` | `source`, `source_id`, `digested_at`, `digest_agent` |
| `moc`, `inbox` | (sólo comunes) |

### Enums aceptados

- `digest_status`: `pending` | `done`
- `risk.severity`: `low` | `medium` | `high` | `critical`
- `risk.status`: `open` | `mitigated` | `accepted` | `closed`
- `spec.status`: `pending` | `approved` | `implemented`
- `session.frontend`: `claude-code` | `opencode`
- `digest.source`: `meeting` | `email` | `chat` | `file` | `devops`

`None`, `""`, `[]` cuentan como ausentes.

## Coherencia path ↔ frontmatter

El gate exige que `project` del frontmatter coincida con el slug inferido del path:
`projects/{slug}_main/...` → frontmatter DEBE tener `project: {slug}`. Mismatch = bloqueo.

## Coherencia confidentiality ↔ path

Toda ruta bajo `projects/` o `tenants/` se infiere como **N4**. Declarar
`confidentiality: N1` en un fichero de vault es bloqueo automático — un fichero N1 no puede
vivir bajo `projects/*/vault/`.

## Cómo desbloquearse

1. Copiar la plantilla del tipo correspondiente desde `projects/{slug}_main/{slug}-{username}/vault/templates/{entity_type}.md`.
2. Sustituir los `"TBD"` por valores reales.
3. Reescribir el fichero. El gate lo aceptará.

Plantillas generadas por `scripts/vault-init.py` ya incluyen frontmatter válido (`"TBD"` en
required no-enum). Validan en CI pero NO deben commitearse como notas reales.

## Opt-out controlado

```bash
SAVIA_VAULT_GATE_ENABLED=false   # desactiva el hook para una sesión
```

Uso: migración de notas legacy o triaging masivo. **Nunca por defecto.** El hook está activo
salvo opt-out explícito.

## Prohibido

```
NUNCA → Commitear *.md bajo projects/*/vault/ sin frontmatter
NUNCA → Declarar confidentiality: N1 en un fichero de vault
NUNCA → Desactivar el gate de forma permanente en .claude/settings.json
NUNCA → Bypass con sed/echo > para evitar el hook
```

## Verificación local

```bash
# Validar un fichero concreto
python3 scripts/vault-validate.py --check projects/my-project_main/my-project-monica/vault/pbi/AB-1234.md

# Validar texto vía stdin (usado por el hook)
cat fichero.md | python3 scripts/vault-validate.py --check-text - --path projects/.../vault/pbi/X.md --quiet

# Suite completa
pytest tests/scripts/test_vault_validate.py tests/scripts/test_vault_init.py -q
bats tests/test-vault-frontmatter-gate.bats
```

## Referencias

- `scripts/vault-validate.py` — parser YAML-subset + validador (469 LOC)
- `scripts/vault-init.py` — scaffolder idempotente (485 LOC)
- `.claude/hooks/vault-frontmatter-gate.sh` — hook PreToolUse F1
- `tests/test-vault-frontmatter-gate.bats` — 15 bats verdes
- `docs/specs/SPEC-PROJECT-UPDATE.spec.md` §F1 — spec origen
- `docs/rules/domain/data-sovereignty.md` — Savia Shield (capas 0-4)
- `docs/rules/domain/zero-project-leakage.md` — aislamiento N4 → N1
- `docs/rules/domain/context-placement-confirmation.md` — niveles N1-N4b
