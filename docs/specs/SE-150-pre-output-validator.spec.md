# SE-150 — Pre-output validator (TTSR-inspired)

**Status:** APPROVED
**Fecha:** 2026-05-27
**Área:** Security hardening / Output safety
**Spike commit:** `9414266c` — `spike/SE-150-ttsr-pre-output`

---

## Objetivo

Añadir una capa de validación estática sobre el output de agentes antes de
que se materialice en ficheros o comandos, detectando patrones de riesgo
alto definidos por 7 reglas POR-001 a POR-007.

---

## Reglas POR (Pre-Output Rules)

| ID | Patrón detectado | Acción |
|---|---|---|
| POR-001 | PAT hardcodeado (token Azure DevOps en literal) | BLOCK |
| POR-002 | `CLAUDE_PROJECT_DIR` en scripts de agente | WARN |
| POR-003 | `git commit` apuntando a rama `main` directamente | BLOCK |
| POR-004 | `terraform apply` sin flag `-target` o aprobación explícita | BLOCK |
| POR-005 | `rm -rf` sobre ruta no acotada (sin variable o path fijo seguro) | BLOCK |
| POR-006 | `password` o `secret` inline en YAML/JSON/ENV | BLOCK |
| POR-007 | `git push --force` fuera de ramas `agent/*` | BLOCK |

Severidad: BLOCK detiene la ejecución y devuelve exit 1. WARN registra y
devuelve exit 0.

---

## Script

### `scripts/pre-output-validator.sh`

```
pre-output-validator.sh check  FILE          → valida fichero
pre-output-validator.sh check  --stdin       → lee de stdin
pre-output-validator.sh list-rules           → imprime tabla POR-001..007
pre-output-validator.sh explain RULE-ID      → descripción + ejemplo
```

Salida: `BLOCK [POR-003] git commit a main — línea 42`. Con `--json`: objeto
`{rule, severity, line, excerpt, file}`.

**Evaluación vs hooks existentes** (spike, 69 hooks): 0 duplicados exactos;
6/7 casos complementarios — los hooks actúan en PreToolUse/PostToolUse sobre
herramientas concretas, el validator actúa sobre texto de output. POR-002
(`CLAUDE_PROJECT_DIR`) tiene overlap parcial con `provider-agnostic-env` →
tratado como WARN para evitar falsos positivos en docs legítimos.

---

## Acceptance Criteria

- AC-1 (POR-001): Bloquea output con token Azure DevOps en literal
  (patrón `[a-z0-9]{52}`).
- AC-2 (POR-002): Emite WARN cuando detecta `CLAUDE_PROJECT_DIR` en scripts.
- AC-3 (POR-003): Bloquea `git commit` / `git push` targeting `main` sin
  rama intermedia.
- AC-4 (POR-004): Bloquea `terraform apply` sin `-target` o comentario
  `# approved:`.
- AC-5 (POR-005): Bloquea `rm -rf` cuando la ruta es `/`, `$HOME`, o variable
  sin acotación de prefijo conocido.
- AC-6 (POR-006): Bloquea `password:`, `secret:`, `PASSWORD=`, `SECRET=`
  con valor no vacío en ficheros de configuración.
- AC-7 (POR-007): Bloquea `git push --force` en contexto de rama que no
  coincide con `agent/*`.
- AC-8: Suite BATS ≥ 34 tests passing (estado spike: 34/34).
- AC-9: `--stdin` permite integración en pipelines sin fichero temporal.

---

## Integración con `.claude/settings.json`

Para activar el validator como hook PostToolUse sobre Write/Bash:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash scripts/pre-output-validator.sh check --stdin"
          }
        ]
      }
    ]
  }
}
```

El hook recibe el contenido del tool result por stdin. Si devuelve exit 1,
Claude Code aborta la acción y muestra el mensaje de violación.

---

## OpenCode Implementation Plan

```yaml
spec: SE-150
type: security-hardening
risk: LOW-MEDIUM
  # LOW: el validator es aditivo; no modifica lógica existente.
  # MEDIUM: si se activa en PostToolUse puede interrumpir flujos legítimos
  #         hasta que las reglas estén calibradas en producción.

slices:
  - id: S1
    name: validator-script-and-tests
    files:
      - scripts/pre-output-validator.sh
      - tests/bats/SE-150-pre-output-validator.bats
    ac: [AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9]
    effort: done (spike)
    action: Merge spike/SE-150-ttsr-pre-output → main via PR.

  - id: S2
    name: settings-hook-integration
    files:
      - .claude/settings.json  (añadir entrada PostToolUse)
    ac: []
    depends: [S1]
    effort: 1h
    note: >
      Activar primero en modo WARN-only (modificar script para --warn-mode)
      durante un sprint. Promover a BLOCK tras validar tasa de falsos positivos.

  - id: S3
    name: opencode-hook-parity
    files:
      - .opencode/plugins/ o equivalente
    status: FUTURE
    depends: [S2]
    effort: estimado 2h
    note: Replicar la integración para OpenCode cuando soporte PostToolUse.
```

---

## Referencias

- `docs/rules/domain/autonomous-safety.md`, `critical-rules-extended.md` (Rules 1, 10, 13)
- `scripts/savia-env.sh` → POR-002 usa `SAVIA_WORKSPACE_DIR` como alternativa
