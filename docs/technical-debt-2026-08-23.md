# Deuda Técnica — Catálogo y Plan (2026-08-23)

> Fuente: auditoria de integridad y operatividad ejecutada el 2026-08-23.
> Linea de SaviaLabs asociada: **L14 circuit-closing** (preregistrada).
> Todos los datos son mediciones locales (CRIT-001), sin fuga a cloud.

---

## Resumen ejecutivo

| Métrica | Valor | Umbral | Veredicto |
|---|---|---|---|
| Workspace health global | **69 / 100 (D)** | >= 80 | 🔴 |
| Test coverage (hooks) | **23%** | >= 80 | 🔴 |
| Skills Incomplete | **119 / 126 (94%)** | — | 🔴 |
| Skills Stub | **5** | 0 | 🟠 |
| Agentes oversized | **27 / 75 (36%)** | < 10% | 🟠 |
| rule-manifest integrity | **FAIL** | PASS | 🔴 |
| Orphan rules | 0 / 288 | 0 | 🟢 |
| claude-md drift | PASS | PASS | 🟢 |
| hooks integrity | PASS (111/226) | PASS | 🟢 |

**Interpretación honesta**: Savia es funcional y los invariantes de seguridad
están verdes (orphan, drift, hooks, PII). Pero la **deuda estructural es real y
acumulada**: cobertura de tests 23%, 94% de skills sin calibrar, un manifest de
reglas stale desde abril, y 27 agentes por encima del umbral de líneas. Esa
deuda no es cosmética: cada sesión paga parte de su presupuesto re-verificando
lo que debería estar cerrado.

---

## 1. Deuda de integridad estructural

### 1.1 rule-manifest — SE-057 (PRIORIDAD ALTA)

| Hallazgo | Detalle |
|---|---|
| INDEX.md supera límite | `docs/rules/domain/INDEX.md` = 165 líneas > límite 150 (Rule #22) |
| Manifest stale | `rule-manifest.json` generado **2026-04-16**, 151 reglas; hoy hay 296 sin listar |
| Manifest refs rotas | 25 entradas del manifest apuntan a ficheros que no existen (paths `.opencode/...` y skills que movieron) |
| Sin generador canónico | No existe script que regenera `rule-manifest.json`; solo lectores |

**Causa raíz**: el manifest se generó a mano/una vez (abril) y no se sincronizó
con la evolución del workspace (cambio `.claude/` → `.opencode/`, nuevas reglas).

**Plan**: (a) crear `scripts/rule-manifest-generate.sh` determinista con el mismo
schema `{tier, consumers}` que regenera desde `docs/rules/domain/*.md`
(clasificando tier por frontmatter `context_tier`); (b) regenerar; (c) añadir el
`--check` al `readiness-check.sh`; (d) reducir INDEX.md (splitting por categoría).

### 1.2 Skill maturity — SE-167 (PRIORIDAD MEDIA)

| Hallazgo | Detalle |
|---|---|
| 119/126 skills Incomplete | Solo 2 calibrated, 5 stub |
| Criterio | Cada skill sin test BATS/validación cuenta como Incomplete |

**Causa raíz**: el kanban de madurez se creó (SE-167) pero el plan de
calibración no se ejecutó; la mayoría de skills son funcionales pero no tienen
prueba formal.

**Plan**: (a) batcher de calibración por familia (mayor uso primero); (b) el
`skill-maturity-audit.sh` ya emite TSV + kanban — alimentar un dashboard;
(c) objetivo: Incomplete < 50% en 4 semanas.

### 1.3 Agent size — SE-052 (PRIORIDAD MEDIA)

| Hallazgo | Detalle |
|---|---|
| 27/75 agentes oversized | > umbral de líneas del prompt |

**Plan**: usar `agent-size-remediation-plan.sh` existente; priorizar los 5
mayores; splitting por categorías.

---

## 2. Deuda de test

### 2.1 Test coverage 23% (PRIORIDAD ALTA)

| Hallazgo | Detalle |
|---|---|
| 113 hooks totales, ~26 con BATS | El resto sin test directo |
| TS plugins | Tests en `bun:test` requieren bun (no en PATH); `node --test` falla MODULE_NOT_FOUND |

**Causa raíz**: la cobertura de hooks se construyó por lotes (Eras 182-186)
pero no se cerró el ratchet; los plugins TS dependen de bun runtime del
frontend, no disponible en CLI.

**Plan**: (a) añadir BATS para los hooks críticos (seguridad, PII, commits) —
no para todos; (b) documentar cómo correr los tests TS (bun install en
`.opencode/plugins/`); (c) ratchet mínimo en CI.

### 2.2 Error TS latente (PRIORIDAD BAJA)

`auto-grill-me.ts:32` y `auto-zoom-out.ts:27` llaman `extractToolName(input,
output)` con 2 args; firma acepta 1. Preexistente desde PR #803 (2026-06-04). No
rompe runtime (JS ignora args extra). **Plan**: fix de 2 líneas en el siguiente
toque (CRIT-009: la deuda se paga al tocar).

---

## 3. Deuda de procesos / operacional

| Hallazgo | Detalle |
|---|---|
| BATS no en PATH por defecto | `which bats` falla; reside en `~/bin/bin/bats` (npm global) |
| Node no en PATH | vive en `~/.savia/node/`; scripts que asumen `node` fallan si no exportan PATH |
| CHANGELOG manual | G5 exige bump; usa fragment (ya automatizado en pr-plan) |

**Plan**: documentar runtime paths en `pm-config.md`; añadir guard en
`readiness-check.sh`.

---

## 4. Plan de remediación priorizado (ROI)

| # | Item | Esfuerzo | ROI | Cierra |
|---|---|---|---|---|
| 1 | Generador + regenerar rule-manifest (1.1) | 2-3h | Altísimo — desbloquea integridad | SE-057 |
| 2 | Ratchet de test-coverage hooks críticos (2.1) | 4-6h | Alto — reduce regresiones | SE-046 |
| 3 | Skill maturity: calibrar familia L1 (1.2) | 4h | Alto — 2% → 20% | SE-167 |
| 4 | Agent-size: split top-5 (1.3) | 3h | Medio | SE-052 |
| 5 | Fix TS 2 líneas (2.2) | 0.2h | Bajo — higiene | — |
| 6 | Documentar runtime paths (3) | 1h | Bajo — DX | pm-config |

**Métrica de éxito** (L14): health 69 → >= 85; rule-manifest PASS; test-coverage
>= 40%; Incomplete < 50%; agent oversized < 10%.

---

## Referencias

- Auditores: `scripts/workspace-health.sh`, `scripts/rule-manifest-integrity.sh`,
  `scripts/skill-maturity-audit.sh`, `scripts/agent-size-audit.sh`
- Labs: hypothesis `l14-circuit-closing` (vault SaviaLabs)
- Reglas: SE-057 (manifest), SE-046 (baseline), SE-167 (skill maturity), SE-052 (agent size)