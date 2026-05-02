# Spec: Provider-Agnostic Vendor References — Eliminar referencias exclusivas a Claude Code

**Task ID:**        SPEC-OPC-VENDOR-REFS
**PBI padre:**      Era 189 — OpenCode Sovereignty (SE-077)
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (auditoria OpenCode sovereignty)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~45 min
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      20

---

## 1. Contexto y Objetivo

En la transicion a OpenCode como frontend primario (Era 189), documentacion y
scripts contienen referencias exclusivas a "Claude Code" que asumen un unico
entorno. Ejemplos:

- `CLAUDE.md` menciona `pm-workspace — Claude Code Global`
- Paths usan `$CLAUDE_PROJECT_DIR` sin fallback `$OPENCODE_PROJECT_DIR`
- Docs referencian "Claude Code" como unico frontend
- Skills mencionan "Claude agent" sin contemplar OpenCode

`docs/rules/domain/provider-agnostic-tech-debt.md` ya registra 51/92 skills
con referencias a vendor. Este spec cierra esa deuda documentada.

**Objetivo:** Auditar y corregir todas las referencias exclusivas a "Claude
Code" en documentacion y scripts para que contemplen tambien OpenCode. No
se elimina "Claude Code" — se anade "OpenCode" como opcion valida donde
corresponda. Paths usan fallback `VAR1:-VAR2`.

---

## 2. Requisitos Funcionales

- **REQ-01** Auditar `docs/` completo con `rg -i 'claude.code'` y `rg 'CLAUDE_'`.
  Clasificar cada ocurrencia como:
  - `PATH`: referencia a `$CLAUDE_*` sin fallback → anadir fallback
  - `VENDOR`: menciona "Claude Code" como unica opcion → anadir "u OpenCode"
  - `LEGIT`: referencia correcta (ej: nombre de producto real, historia)
  - `SKIP`: nombres propios (CLAUDE.md, .claude/) que son parte de la estructura
- **REQ-02** Para toda ocurrencia `PATH`: `${CLAUDE_PROJECT_DIR}` →
  `${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-$PWD}}`
- **REQ-03** Para toda ocurrencia `VENDOR` en docs: "Claude Code" →
  "Claude Code / OpenCode" o equivalente contextual.
- **REQ-04** No modificar nombres estructurales: `.claude/` (directorio),
  `CLAUDE.md` (fichero), `claude` en comandos (`/claude`).
- **REQ-05** Actualizar `provider-agnostic-tech-debt.md` al final: registrar
  skills corregidos y conteo residual.
- **REQ-06** Ejecutar `ci-extended-checks.sh` post-cambios. Todos los
  checks deben seguir en PASS.

---

## 3. Alcance por tipo

| Tipo | Accion | Ejemplo |
|------|--------|---------|
| PATH sin fallback | Anadir `:-${OPENCODE_*}` | `$CLAUDE_PROJECT_DIR` → con fallback |
| VENDOR en docs | "Claude Code / OpenCode" | "compatible con Claude Code" → "compatible con Claude Code / OpenCode" |
| VENDOR en scripts | Comentario agnostico | `# Claude Code hook` → `# Claude Code / OpenCode hook` |
| LEGIT | No tocar | "Claude Code Pro" (producto real) |
| SKIP estructural | No tocar | `.claude/`, `CLAUDE.md`, `/claude:` |

---

## 4. Criterios de Aceptacion

- **AC-01** `rg '\$CLAUDE_PROJECT_DIR(?!.*\{|.*:-)' scripts/` no encuentra ocurrencias sin fallback.
- **AC-02** `rg 'solo.*Claude Code|exclusivamente.*Claude Code|únicamente.*Claude Code' docs/` no encuentra exclusividad.
- **AC-03** `ci-extended-checks.sh` pasa 10/10.
- **AC-04** `provider-agnostic-tech-debt.md` actualizado con skills corregidos y conteo final.
- **AC-05** Paths estructurales (`.claude/`, `CLAUDE.md`) intactos.
- **AC-06** Ningun script roto por el cambio (verificar con `bash -n` sobre scripts modificados).

---

## 5. Ficheros a Modificar

| Fichero | Accion |
|---------|--------|
| `docs/**/*.md` | MODIFICAR: referencias VENDOR |
| `scripts/**/*.sh` | MODIFICAR: PATH sin fallback + VENDOR en comentarios |
| `docs/rules/domain/provider-agnostic-tech-debt.md` | MODIFICAR: actualizar conteo |

---

## 6. Test Scenarios

1. **Sin paths sin fallback**: grep no encuentra `$CLAUDE_PROJECT_DIR` sin `:-` en scripts.
2. **Sin exclusividad**: grep no encuentra frases de exclusividad en docs.
3. **CI verde**: 10/10 checks pasan.
4. **Scripts validos**: `bash -n` pasa en todos los scripts modificados.
5. **Tech debt**: conteo en provider-agnostic-tech-debt.md es menor que el inicial (51).
