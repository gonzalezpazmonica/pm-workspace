# SE-407 S4 — Auditor externo `audit-harness.sh` como sonda (report-only)

Fecha: 2026-10-01 · Objetivo auditado: `main` 95b37593 (clon superficial, solo lectura).
Es una métrica externa, no un gate: los nombres de LHE no se copian a ciegas.

## Fijación y ejecución

| Dato | Valor |
|---|---|
| Repo | `walkinglabs/learn-harness-engineering` (MIT) |
| Commit | `38ddcd2bf8d65271f668b94e7c875ca1d629d622` |
| `tools/audit-harness.sh` sha256 | `9c711d8d65dce4c0dcba245385c5bf62203b54797ce9bf207c024f6202307da5` (543 líneas) |
| Revisión previa | Solo comprobaciones de patrones y ficheros: sin red, sin escrituras y sin ejecutar nada del repo auditado |

```bash
git clone --depth 1 https://github.com/walkinglabs/learn-harness-engineering lhe
git -C lhe checkout 38ddcd2bf8d65271f668b94e7c875ca1d629d622
echo "9c711d8d65dce4c0dcba245385c5bf62203b54797ce9bf207c024f6202307da5  lhe/tools/audit-harness.sh" | sha256sum -c
git clone --depth 1 file://$PWD /tmp/objetivo && bash lhe/tools/audit-harness.sh /tmp/objetivo
```

Ojo: el auditor lee `AGENTS.md` si existe y solo usa `CLAUDE.md` si no lo hay. En
Savia, `AGENTS.md` es la entrada de Codex, Cursor y OpenCode, y es lo que se evalúa.

## Resultado

| Ejecución | PASS | FAIL (críticos) | WARN |
|---|---|---|---|
| 2026-09-29, savia@00e388ac (investigación previa) | 19 | 3 | 48 |
| 2026-10-01, `main` 95b37593 | 17 | 4 | 49 |
| 2026-10-01, con la cabecera nueva de `AGENTS.md` (este PR) | 22 | 3 | 45 |

La versión del auditor del 29/09 no se fijó; las dos primeras filas no son
directamente comparables.

## Clasificación (AC7)

### Críticos

| Comprobación | Clasificación | Disposición |
|---|---|---|
| La entrada dice qué es el sistema en sus 10 primeras líneas | **Hueco real** | Cerrado en este PR: línea «What this is» en `AGENTS.md` (generador), con clock-in y clock-out; en `CLAUDE.md` ya estaba desde S3 (#1210) |
| Lockfile de dependencias | **Hueco real** | `.gitignore` excluye todo `package-lock.json` (`**/package-lock.json`): la CI instala `scripts/` sin lock de transitivas y savia-vaults (open source) no versiona su lock. Requiere decisión de la operadora |
| `PROGRESS.md` existe | Equivalente Savia | `docs/propuestas/session-handoff.md` (≤ 30 líneas, se reescribe en cada cierre) |
| `PROGRESS.md` con bloque Current State (commit + tests) | Equivalente parcial | El traspaso lleva el commit de main; el estado de tests lo da `validate-ci-local.sh` (S1) y no se copia al traspaso |

### Recomendados (45 WARN tras este PR)

| Grupo | Clasificación | Equivalente o motivo |
|---|---|---|
| Objetivos de Makefile (`check`, `test`, `setup`, `dev`, `e2e`, `vcr`, `verify-feature`, `check-arch`, `clean-check`, `session-start/end`) | Equivalente Savia | Scripts: `validate-ci-local.sh` (predicado S1 y `--clean-state` S2), `test-workspace.sh`, `roadmap.sh`. Añadir un Makefile está fuera del alcance de la spec |
| `feature_list.json`, máquina de estados, campo de evidencia, reglas de paso a «passing» | Equivalente Savia | `planning-state.json` + `roadmap.sh validate` (estados, `delivery`/`completion`, revisión humana obligatoria para IMPLEMENTED) |
| Durabilidad entre sesiones, Next Steps | Equivalente Savia | Traspaso + `LOG.md` + `docs/decisions/` |
| `scripts/clean-state-check.sh`, checklist de cierre, limpieza dual | Equivalente Savia | `validate-ci-local.sh --clean-state` (S2); el script aparte se descartó por el ratchet de entropía (SE-380) |
| Reglas de arquitectura (`.harness/arch-rules.json`, `check-arch`) | Equivalente parcial | SAM (SE-397) y gates de coherencia; sin formato WHAT/WHY/FIX |
| Plantillas de sprint contract / evaluator rubric, session traces | Equivalente parcial | Specs SDD con AC, Code Review Court, trazas de `sam.py trace`; no hay rúbrica A–D por dimensión |
| Versión de runtime fijada | Hueco menor | `engines` en `package.json` (savia-vaults pide Node ≥ 22.13), pero sin `.nvmrc`/`.tool-versions` |
| Atomicidad de commits, guía de mensajes, aviso de «context anxiety», modelo de verificación en tres capas | Convención de LHE | Savia tiene reglas propias (trailers, PR por spec, Radical Honesty); no se evalúa su equivalencia exacta |

## Conclusión

Los huecos reales que señalaba la investigación (predicado único de estado
consistente, comprobación de estado limpio y entrada autoexplicativa) están
cerrados por S1–S3 y este PR. El que queda abierto y es real es el de los lockfiles.
El resto son diferencias de convención con equivalente en Savia o mejoras menores.
El auditor no es un gate: se repite solo fijado por el commit y el sha256 de arriba.
