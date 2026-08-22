# SE-336 — Turn-SDLC: ciclo de vida de una ejecución LLM con gates de entrada, salida y telemetría

**Status:** APPROVED (operadora, 2026-08-22) → IMPLEMENTED (2026-08-22)
**Fecha:** 2026-08-22
**Area:** Orquestación / Hooks / Calidad / Telemetría
**Origen:** Análisis conjunto operadora+Savia 2026-08-22 ("cada ejecución de LLM como un SDLC"), sobre el inventario real de 104 hooks registrados. Génesis empírica: LP-20260822-b20596e1 (respuesta con promesa vacía entregada sin que ningún gate la detectara).
**Developer Type:** agent-single
**Context risk:** medium
**Estimación:** agente 22h (4 slices) / revisión humana 1.5h

> Nota de implementación: el AC-02 de esta spec decía "exit 1" para el bloqueo del
> Stop, pero el contrato real de Stop hooks en Claude Code es `{"decision":"block"}`
> con exit 0 (mismo patrón que `postponement-judge.sh`). La implementación sigue el
> contrato real; el AC se ajusta a lo verificado por test.

---

## 1. Tesis

Cada turno de LLM es un mini-SDLC: recibe requisitos (el prompt + contexto), diseña (plan/spec), ejecuta (tools), verifica (validadores sobre artefactos) y entrega (respuesta final). pm-workspace ya implementa ese SDLC de facto, disperso en 104 hooks — pero la auditoría de cobertura por fase muestra **dos huecos estructurales**:

1. **La respuesta final de texto no pasa ningún DoD.** Los validadores actúan sobre tool outputs (ficheros, comandos); el texto que la operadora lee llega sin gate. Evidencia 2026-08-22: una respuesta con promesa de mejora sin acción de respaldo fue entregada limpiamente. El mecanismo de bloqueo pre-entrega YA existe (`postponement-judge.sh` lee el último mensaje del assistant y bloquea el Stop para forzar una iteración más) pero solo cubre postponements.
2. **El proceso no es medible por turno.** Cada hook escribe a su propio log; no existe consolidación por fase (CRIT-019). La regla SE-335 (orden de descubrimiento) se carga pero nada registra si se sigue — regla sin métrica es aprendizaje declarado, no medido (SCL-001 S3).

Esta spec formaliza el modelo Turn-SDLC, cierra el hueco de salida con un DoD gate determinista, hace medible el orden de descubrimiento y consolida la telemetría.

## 2. Modelo Turn-SDLC (mapa formal)

| Fase | Evento | Hooks existentes (representativos) | Estado |
|---|---|---|---|
| F1 Requisitos | UserPromptSubmit (6) | user-prompt-intercept, memory-prime, learning-recall, stress-awareness-nudge, re-anchor-redlines | Enriquece/protege; NO valida suficiencia — diferido (ver §7) |
| F2 Diseño | PreToolUse | plan-gate, context-preflight-check, spec156-token-budget-projection, agent-dispatch-validate | Cubierto |
| F3 Ejecución | PreToolUse (48) | block-credential-leak, block-force-push, data-sovereignty-gate, tdd-gate, validate-bash-global, agent-git-discipline, block-project-whitelist, … | Cubierto |
| F4 Verificación | PostToolUse (35) | post-edit-lint, ast-quality-gate-hook, post-write-validate, data-sovereignty-audit, dual-estimation-gate | Cubierto (artefactos) |
| F5 Entrega | Stop (8) | stop-quality-gate (working tree+secrets), scope-guard, pre-commit-review, postponement-judge | **PARCIAL — valida el diff, no la respuesta final** |
| F6 Retrospectiva | Stop/SessionEnd | stop-memory-extract, learning-capture-hook, session-end-memory | Cubierto |

El mapa completo (los 104) lo genera el auditor de S1 — no se duplica a mano aquí (CRIT-003: texto generado y versionado, no copiado).

## 3. Contratos

### 3.1 S1 — Auditor Turn-SDLC (`scripts/turn-sdlc-audit.sh`)

```text
turn-sdlc-audit.sh [--json]
  Lee .claude/settings.json y clasifica cada hook registrado en F1-F6
  (tabla de clasificación embebida en el script, versionada).
  Output: output/turn-sdlc-matrix.md — matriz fase→evento→hooks→modo (block|warn|shadow|capture).
  Exit 0 siempre (reporte), salvo settings.json inválido (exit 2).
```

### 3.2 S2 — DoD gate de la respuesta final (`scripts/stop-dod-gate.sh` + registro Stop)

Reglas deterministas sobre el último mensaje del assistant (mismo parser de contenido que `postponement-judge.sh`):

| ID | Patrón | Severidad inicial | Acción |
|---|---|---|---|
| DOD-001 | Promesa de mejora sin acción: ("la próxima vez", "a partir de ahora", "de ahora en adelante", "en el futuro haré") sin diff activo ni artefacto creado ese turno | BLOCK | Bloquea Stop, fuerza 1 iteración para convertir promesa en acción o reformularla sin promesa |
| DOD-002 | Afirmación material sin referencia: cifras/estados afirmados como hechos sin `file:line`, ruta o comando verificable en el propio turno | WARN | Inyecta recordatorio de evidencia (no bloquea) |
| DOD-003 | Idioma de la respuesta ≠ idioma del perfil activo | WARN | Inyecta recordatorio |

- **Antiloop**: reintento máximo 1 — segunda pasada siempre pasa con warning registrado (mismo patrón de `postponement-judge.sh` y `stop-quality-gate.sh`).
- **Modo de despliegue**: WARN-only (`SAVIA_DOD_GATE_MODE=warn`) el primer sprint; promoción a BLOCK tras medir falsos positivos (patrón SE-150 S2).
- **Presupuesto**: <= 2s; regex deterministas, sin red, sin LLM.
- **Master switch**: `SAVIA_DOD_GATE=off` lo desactiva (fail-open operativo).

### 3.3 S3 — Telemetría del orden de descubrimiento (`scripts/discovery-order-telemetry.sh`)

- PostToolUse `.*` (async, shadow): registra en `output/learning-loop/discovery-order.jsonl` por turno: `{ts, query_hash, first_tools: [primeras N herramientas del turno], order_ok: bool}` donde `order_ok` = ningún `grep|glob|read` antes del primer `vault_search|vault_read|memory-store recall|search_graph` cuando el turno resolvió una pregunta de conocimiento.
- Heurística conservadora: turnos con solo herramientas de escritura/ejecución se marcan `n/a` (no penalizan).
- Nunca bloquea. Alimenta la métrica `L` (divergencia grafo-modelo → aquí, divergencia regla-comportamiento).

### 3.4 S4 — Reporte Turn-SDLC (`scripts/turn-sdlc-report.sh`)

```text
turn-sdlc-report.sh --window W## [--json]
  Consolida discovery-order.jsonl + logs de stop-dod-gate + feedback existente
  (quality-gate-history.jsonl) en un reporte por ventana:
  "turnos=N · order_ok=61% · dod_blocked=3 · dod_warn=11 · top violaciones=…"
  Exit 0. Escribe output/turn-sdlc-report-W##.md
```

El reporte es la contraparte de ventana del learning-report: si `order_ok` no sube tras SE-335, la regla no funciona y hay que rediseñarla — dato, no opinión.

## 4. Reglas de negocio

| ID | Regla | Incumplimiento |
|---|---|---|
| RN-01 | stop-dod-gate nunca modifica el texto del assistant; solo bloquea el Stop o inyecta recordatorio | Test falla |
| RN-02 | Máximo 1 bloqueo de Stop por turno (antiloop) | Test de doble pasada |
| RN-03 | DOD-002/003 son WARN siempre; solo DOD-001 bloquea (y solo tras promoción a block) | Test de severidades |
| RN-04 | Telemetría S3 guarda `query_hash`, nunca el prompt completo | Test de privacidad (patrón SCL-008 RN-09) |
| RN-05 | Ningún componente de esta spec escribe CRITERIO.md ni CONSTITUCION.md | Test de invariante de hashes |
| RN-06 | Todos los componentes: sin red, sin deps nuevas, PURE_BASH | Guard en test |
| RN-07 | La clasificación fase→hook del auditor vive versionada en el script, auditable en el diff | Review |

## 5. Criterios de aceptación

- [x] AC-01: `turn-sdlc-audit.sh` clasifica el 100% de hooks registrados en F1-F6 (0 sin clasificar) y genera la matriz. — 113 hooks: F1=6 F2=6 F3=40 F4=37 F5=7 F6=4 F0=13
- [x] AC-02: fixture con promesa-sin-acción ("la próxima vez haré X") y working tree sin cambios → stop-dod-gate en modo block emite `{"decision":"block"}[DOD-001]` (bloquea Stop; ver nota de implementación).
- [x] AC-03: mismo fixture + segunda invocación → exit 0 sin block (antiloop RN-02).
- [x] AC-04: mensaje con afirmación sin referencia → WARN registrado, exit 0.
- [x] AC-05: `SAVIA_DOD_GATE=off` → exit 0 inmediato (master switch).
- [x] AC-06: telemetría S3 con fixture de turno grep-first → `order_ok=false` en JSONL; turno vault-first → `order_ok=true`; turno solo-escritura → `n/a`.
- [x] AC-07: JSONL de S3 no contiene el prompt en claro (solo hash).
- [x] AC-08: `turn-sdlc-report.sh --window test` produce reporte con contadores coherentes con los JSONL de fixture.
- [x] AC-09: latencia de stop-dod-gate < 2s sobre payload real de sesión (test con fixture de 50KB) — medido < 2s.
- [x] AC-10: hashes de CRITERIO.md y CONSTITUCION.md invariantes tras la suite completa.
- [x] AC-11: `hooks-integrity-check.sh` y `claude-md-drift-check.sh` PASS tras registrar los hooks nuevos.
- [x] AC-12: suite BATS nueva >= 20 tests, todos PASS — 27/27.

> Verificación 2026-08-22: `bats tests/test-se336-*.bats` 27/27, `hooks-integrity-check.sh`
> PASS (110 registrados, 224 on-disk), `claude-md-drift-check.sh` PASS (hooks 112/115reg),
> `git diff --check` limpio, hashes fundacionales invariantes. Estado del PR #980 (SE-335):
> CI verde, Draft restaurado, pendiente de revisión humana.

## 6. Slices y ficheros

### Slice 1 — Auditor y matriz (4h)
Crear: `scripts/turn-sdlc-audit.sh`, `tests/test-se336-turn-sdlc-audit.bats`.

### Slice 2 — DoD gate de salida (8h)
Crear: `scripts/stop-dod-gate.sh`, `tests/test-se336-stop-dod-gate.bats`.
Modificar: `.claude/settings.json` (registro Stop, modo warn), `docs/rules/domain/critical-rules-extended.md` (documentar DOD-001..003 — solo si la operadora aprueba la promoción a block).

### Slice 3 — Telemetría de orden de descubrimiento (6h)
Crear: `scripts/discovery-order-telemetry.sh`, `tests/test-se336-discovery-order.bats`.
Modificar: `.claude/settings.json` (registro PostToolUse `.*` async).

### Slice 4 — Reporte de ventana (4h)
Crear: `scripts/turn-sdlc-report.sh`, `tests/test-se336-turn-sdlc-report.bats`.
Modificar: `docs/rules/domain/scl-001-learning-loop.md` (referencia al reporte como input de `L`).

### No tocar
`CRITERIO.md`, `.claude/CONSTITUCION.md`, plugins TS de OpenCode (ver §8), hooks existentes.

## 7. Out of scope (con motivo)

- **Prompt-quality gate de entrada (F1)**: validar suficiencia del contexto del prompt tiene alto riesgo de fricción y falsos positivos; F1 ya enriquece (prime/recall/intercept). Diferido hasta que el reporte S4 muestre dolor medible (patrón SE-268: slice por dolor demostrado).
- **LLM judges sobre la respuesta final**: ya cubiertos por los tribunales SPEC-192/125; esta spec es la capa determinista debajo.
- **Portación de Stop hooks a OpenCode puro**: Stop no existe en el bridge TS (matriz SE-253). La degradación se documenta, no se resuelve aquí.

## 8. OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Auditor S1 + reporte S4 | PURE_BASH desde shell | Idéntico (PURE_BASH) |
| stop-dod-gate S2 | Stop hook nativo | **No disponible** — degradación documentada: DOD queda en CI (gates de diff) + revisión humana |
| Telemetría S3 | PostToolUse `.*` async | Vía bridge `chat.message` existente si el evento está mapeado; si no, shadow solo en Claude Code |

### Verification protocol

- [ ] S1/S4 corren desde shell independiente del frontend.
- [ ] S2 verificado en Claude Code nativo (o fixture equivalente con payload sintético).
- [ ] Degradación OpenCode reflejada en `docs/hooks-coverage-matrix.md` tras implementar.

### Portability classification

- [x] **DUAL_BINDING** — núcleo PURE_BASH; el gate de Stop es Claude Code nativo con degradación documentada (no hay evento equivalente en OpenCode puro).

## 9. Riesgos y rollback

- **R1 — Stop-block molesta en falsos positivos** (DOD-001 con promesa legítima): mitigación WARN-only primer sprint, promoción condicionada a tasa de falsos positivos medida por S4 (AC del reporte).
- **R2 — Loop de Stop**: antiloop RN-02 con test adversarial (AC-03); mismo patrón probado en postponement-judge.
- **R3 — Telemetría S3 penaliza turnos legítimos** (grep primero justificado): heurística `n/a` para turnos no-cognitivos; umbral ajustable.
- **R4 — Sobre-ingeniería** (CRIT-006): cada slice sobrevive solo; S1 tiene valor inmediato (auditoría), S2 ataca el hueco con evidencia de hoy, S3/S4 solo si S1-S2 se adoptan.
- **Rollback**: cada slice es un script + registro en settings.json; revert independiente, sin migración de datos.

## 10. Gate de aprobación y PR

Requiere aprobación humana explícita. Antes del PR: `/pr-plan`, `.pr-summary.md`, rama `agent/se336-turn-sdlc`. Sin approve/merge autónomos (ART-08).

## Referencias

- Inventario de partida: `.claude/settings.json` (17 eventos, 104+ hooks), `.opencode/HOOKS-STRATEGY.md`, `docs/hooks-coverage-matrix.md` (SE-253).
- Patrón Stop-block: `.claude/hooks/postponement-judge.sh`, `stop-quality-gate.sh`.
- Validadores de salida existentes (artefactos): SE-150 (pre-output-validator), SPEC-184 (post-write-validate).
- Origen empírico: LP-20260822-b20596e1 + PR #980 (SE-335).
- CRIT-019 (sin medición no hay prioridad), CRIT-005 (ACs falsificables), CRIT-006 (simplicidad), CRIT-031 (intocables).
