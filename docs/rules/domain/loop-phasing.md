---
context_tier: L2
token_budget: 1200
ref: SE-228
---

# Loop Phasing — Niveles L0→L3 para skills autónomas

> Define los niveles de madurez operativa para cualquier skill que ejecute bucles
> autónomos. Toda skill autónoma declara su `loop_level` en el frontmatter de
> SKILL.md. El nivel declarado debe coincidir con el nivel real inferido por
> `scripts/loop-phasing-audit.sh`.

## Niveles

| Nivel | Nombre | Descripción | Requisitos mínimos |
|---|---|---|---|
| L0 | Draft | Skill documentada, sin ejecución autónoma | SKILL.md existe |
| L1 | Report-only | Genera STATE.md y run-log, no modifica código ni crea PRs | STATE.md, run-log, no auto-commit |
| L2 | Assisted | Crea PRs Draft + verifier antes de proponer | L1 + maker/checker split + loop-budget activo |
| L3 | Unattended | Ejecuta sin supervisión activa | L2 + >1 sprint de historial L2 sin incidentes + aprobación humana explícita |

## Descripción de niveles

### L0 — Draft

La skill está documentada pero no tiene infraestructura de ejecución autónoma.
No genera artefactos de estado. No ejecuta bucles. Solo sirve como referencia
de diseño o documentación de intención.

**Requisito**: SKILL.md existe en `.opencode/skills/<nombre>/`.

### L1 — Report-only

La skill puede ejecutarse de forma autónoma pero únicamente genera informes.
No modifica código, no crea PRs, no hace commits. Genera STATE.md con el
estado actual del bucle y añade entradas al run-log para trazabilidad.

**Requisitos**:
- STATE.md en `output/loop-state/<skill>/STATE.md`
- run-log en `output/loop-run-log/<skill>/`
- Sin auto-commit (solo lectura + reportes)

### L2 — Assisted

La skill crea PRs Draft que requieren revisión humana antes de merge. Implementa
el patrón maker/checker: quien implementa no verifica. Tiene loop-budget activo
que limita el consumo de tokens/día. El humano siempre revisa antes de que
cualquier cambio llegue a ramas principales.

**Requisitos**:
- Todo lo de L1
- Maker/checker split implementado (`docs/rules/domain/maker-checker-protocol.md`)
- loop-budget configurado en `output/loop-budget/<skill>/` con `daily_token_cap > 0`
- PRs en Draft con `AUTONOMOUS_REVIEWER` asignado

### L3 — Unattended

La skill ejecuta ciclos completos sin supervisión activa. Solo alcanzable tras
demostrar estabilidad en L2 durante al menos un sprint (2 semanas) sin
over-reach ni falsos positivos, y con aprobación humana explícita documentada.

**Requisitos**:
- Todo lo de L2
- >1 sprint (2 semanas) en L2 sin over-reach ni falsos positivos
- Aprobación humana explícita documentada en SKILL.md
- Denylist de paths definida en SKILL.md
- Notificación de escalación configurada

## Checklist de promoción L1→L2

Antes de declarar `loop_level: L2`, verificar todos los items:

- [ ] STATE.md generado en >=3 runs sin errores
- [ ] run-log con >=3 entradas DONE
- [ ] maker/checker split implementado (`maker-checker-protocol.md` referenciado en SKILL.md)
- [ ] loop-budget configurado con `daily_token_cap > 0`

## Checklist de promoción L2→L3

- [ ] >1 sprint (2 semanas) en L2 sin over-reach ni falsos positivos
- [ ] Aprobación humana explícita documentada en SKILL.md
- [ ] Denylist de paths definida en SKILL.md
- [ ] Notificación de escalación configurada

## Red flags — No promover nunca si

- El mismo PR tuvo >3 fix attempts sin progreso
- El verifier es el mismo que el implementer (misma sesión, sin separación)
- No hay state file (STATE.md ausente)
- Auto-merge sin path allowlist definida

## Relación con autonomous-safety.md

Los niveles L0-L3 son complementarios a las reglas de
`docs/rules/domain/autonomous-safety.md`. Autonomous-safety define los
**límites de acción** (nunca merge, siempre PR Draft, etc.). Loop-phasing
define la **madurez operativa** (si la skill ha demostrado estabilidad para
operar en ese nivel).

Una skill en L3 sigue cumpliendo autonomous-safety: las restricciones de
ramas `agent/*`, PR Draft obligatorio y AUTONOMOUS_REVIEWER aplican en todos
los niveles.

## Auditoría

```bash
# Auditar todos los skills autónomos
bash scripts/loop-phasing-audit.sh

# Auditar un skill específico
bash scripts/loop-phasing-audit.sh --skill overnight-sprint

# Output JSON
bash scripts/loop-phasing-audit.sh --json
```

El script reporta `declared` vs `inferred` con gap `OK | OVER | UNDER`.

## Paths canónicos

| Artefacto | Path |
|---|---|
| STATE.md | `output/loop-state/<skill>/STATE.md` |
| run-log | `output/loop-run-log/<skill>/` |
| loop-budget | `output/loop-budget/<skill>/` |
| audit script | `scripts/loop-phasing-audit.sh` |
| maker-checker protocol | `docs/rules/domain/maker-checker-protocol.md` |
