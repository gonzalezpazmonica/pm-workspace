# Pre-Output Rules — TTSR-inspired validator (SE-150)

> **SE-150** — Catálogo de reglas del `pre-output-validator.sh`.
> Inspirado en TTSR (Time-Traveling Stream Rules) de oh-my-pi: detecta violaciones
> en el contenido de tool calls ANTES de que se persistan al disco.

## Concepto

Los hooks PreToolUse existentes en Savia validan el *comando* de herramientas Bash
(campo `.tool_input.command` del JSON de entrada). El pre-output validator cubre
el gap complementario: valida el *contenido* de operaciones Write/Edit/Bash —
lo que realmente se escribe en disco — contra un conjunto de patrones regex.

Diferencia clave respecto a los hooks existentes:

| Hook existente | Qué valida | Gap que cubre POR |
|---|---|---|
| `block-credential-leak.sh` | Comandos Bash (solo tool Bash) | Credenciales en contenido Write/Edit |
| `block-force-push.sh` | Comandos git push (solo Bash) | Force-push embebido en scripts .sh |
| `block-infra-destructive.sh` | Comandos terraform (solo Bash) | terraform apply en ficheros IaC |
| `validate-bash-global.sh` | Comandos Bash directos | rm -rf en scripts, git commit en ficheros |

## Catálogo de reglas

| id | scope | severity | pattern | message | example |
|---|---|---|---|---|---|
| POR-001 | `write,edit,bash` | `block` | `ghp_[A-Za-z0-9]{36}\|ado_[A-Za-z0-9]{52}\|AKIA[0-9A-Z]{16}` | PAT/token hardcodeado detectado. Usa `$(cat $PAT_FILE)` o vault. Ref: Rule #1 | `TOKEN=ghp_ABC123DEF456GHI789JKL012MNO345PQR6` |
| POR-002 | `write,edit` | `remind` | `\$CLAUDE_PROJECT_DIR\b` | Usa `$SAVIA_WORKSPACE_DIR` (via `scripts/savia-env.sh`). `CLAUDE_PROJECT_DIR` rompe bajo OpenCode. Ref: SPEC-127 | `mkdir -p "$CLAUDE_PROJECT_DIR/output"` |
| POR-003 | `bash` | `block` | `git\s+commit.*#\s*(on\s+)?branch\s+(main\|master)\|git\s+commit.*&&.*main\|checkout\s+(main\|master).*&&.*git\s+commit` | git commit directo en main/master. Usa feature branch. Ref: Rule #13 | `git checkout main && git commit -m "fix"` |
| POR-004 | `bash,write,edit` | `block` | `terraform\s+apply(?!\s+(--help\|-help\|-h\b\|.*-auto-approve.*-target.*test))` | terraform apply requiere aprobación humana en PRE/PRO. Ref: Rule #10 | `terraform apply -var-file=prod.tfvars` |
| POR-005 | `bash` | `block` | `rm\s+-[rf]{1,2}\s+/(?!\s*tmp\b)[^\s]*` | rm -rf con ruta peligrosa detectado. Verifica el path antes de ejecutar. | `rm -rf /home/monica/data` |
| POR-006 | `write,edit,bash` | `block` | `(?i)(password\|passwd\|secret\|api_key)\s*=\s*["'][^"']{6,}["']` | Credencial inline detectada. Usa variables de entorno o vault. Ref: Rule #9 | `password = "my$ecretP@ss"` |
| POR-007 | `bash` | `block` | `git\s+push\s+(.*\s)?--force(?!-with-lease)(?!\s*&&.*agent/)` | git push --force fuera de ramas agent/*. Usa --force-with-lease o rama agent/. Ref: Rule #13 | `git push origin feature/x --force` |

## Descripción detallada

### POR-001 — PAT/Token hardcodeado
Detecta tokens GitHub Personal Access (ghp_), Azure DevOps (ado_) y AWS IAM (AKIA)
escritos literalmente en cualquier fichero o comando. Severity `block`: el token
quedaría persistido en disco y potencialmente en el historial git.

### POR-002 — CLAUDE_PROJECT_DIR en scripts
Detecta uso de `$CLAUDE_PROJECT_DIR` en ficheros escribibles. Esta variable es
vacía bajo OpenCode, lo que causa bugs silenciosos (el directorio de trabajo apunta
a `/`). Severity `remind`: inyecta el reminder para que el agente corrija antes
del siguiente write. No bloquea porque puede ser legítimo en comentarios.

### POR-003 — git commit en main
Detecta patrones que combinen checkout a main/master con git commit. La regla
protege casos donde el hook `validate-bash-global.sh` no llega: scripts .sh
multi-línea que se escriben al disco sin ejecutarse aún.

### POR-004 — terraform apply sin confirmación
Detecta `terraform apply` sin flags de test/target/help. El hook existente
`block-infra-destructive.sh` solo intercepta Bash directa; esta regla bloquea
también ficheros Makefile/scripts que contienen `terraform apply`.

### POR-005 — rm -rf ruta peligrosa
Detecta `rm -rf /path` donde path no es `/tmp`. Más restrictivo que
`validate-bash-global.sh` (que solo bloquea `rm -rf /` root literal).

### POR-006 — Credencial inline
Detecta assignments de contraseñas/secrets con valor literal entre comillas.
Complementa `block-credential-leak.sh` que opera sobre comandos Bash, no sobre
contenido de ficheros de configuración que se escriben con Write/Edit.

### POR-007 — git push --force fuera de agent/*
Detecta `git push --force` sin `--force-with-lease` y fuera de contexto de
ramas `agent/*`. La rama actual no es verificable desde el contenido del fichero,
así que el bloqueo es conservador: cualquier `--force` sin `-with-lease` es sospechoso.

## Integración en `.claude/settings.json`

**Para activar el hook**, añadir la siguiente entrada al array `PreToolUse` en
`.claude/settings.json`:

```json
{
  "matcher": "Bash|Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "$CLAUDE_PROJECT_DIR/scripts/pre-output-validator.sh"
    }
  ]
}
```

**Notas**:
- El matcher `Bash|Write|Edit` cubre las tres herramientas con mayor riesgo.
- El script lee el input JSON completo de stdin y extrae el campo relevante
  según el tipo de tool (`.tool_input.command` para Bash, `.tool_input.content`
  para Write/Edit).
- Variables de control:
  - `PRE_OUTPUT_RULES_ENABLED=false` desactiva el validador globalmente.
  - `PRE_OUTPUT_SEVERITY_OVERRIDE=remind` degrada todos los `block` a `remind`
    (útil en modo debug o migración).
  - `PRE_OUTPUT_SKIP_RULES=POR-002,POR-004` excluye reglas específicas.

## Referencias

- `scripts/pre-output-validator.sh` — implementación del validador
- `tests/pre-output-validator.bats` — suite de tests
- `docs/rules/domain/autonomous-safety.md` — reglas de seguridad autónoma
- `docs/rules/domain/provider-agnostic-env.md` — SPEC-127 (SAVIA_WORKSPACE_DIR)
- SE-150 spike — branch `spike/SE-150-ttsr-pre-output`
