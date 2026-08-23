# SPEC-CONSOLIDACION — Sanitización y consolidación de Savia (ciclo post-1000 PRs)

**Status:** APPROVED → IMPLEMENTED (2026-08-23) · implementación autónoma autorizada
**Autor:** Savia
**Origen:** directiva de la operadora 2026-08-23 (8 puntos de sanitización)
**Context risk:** medium · **CRIT-001:** todo local, sin datos N3+ a cloud
**Developer Type:** agent-single (implementación autónoma de firma)

## 1. Problema y objetivo

Tras superar los 1000 PRs, Savia debe quedar **100% consolidada y sanitizada**:
producción operativa con pruebas irrefutables, capacidades activas al arranque,
cúpulas y documentación al día, instalador de primer arranque completo y logs
de instalación. La directiva de la operadora pide además que los ciclos y loops
avanzados (AGI/SAGI, Metacognición L13, SCL) **salten solos** sin depender del
operador.

Diagnóstico realizado 2026-08-23 (hechos, no suposiciones):

| Punto | Estado | Evidencia |
|---|---|---|
| P1 scripts en producción | ✅ OK | 10/10 scripts clave operativos |
| P2 pruebas irrefutables | ⚠️ parcial | tests en run-all FULL; falta calibración inicial |
| P3 capacidades al arranque | ⚠️ parcial | SessionStart carga memoria/caps/Ollama; sin recall proactivo |
| P4 cúpulas actualizadas | ⚠️ falta sync | LPs de anoche sin reflejar en índice público |
| P5 docs multiidioma | ⚠️ falta | guías existentes; sin SAGI/metacog/SCL en EN |
| P6 instalador completo | ⚠️ parcial | instaladores dispersos, sin orquestador único |
| P7 log de instalación | ❌ inexistente | no hay log unificado de bootstrap |
| P8 loops saltan solos | ❌ **BUG** | cron `daily 08:30` no computa `next_run`; orquestador con 0 runs |

## 2. Alcance

### Incluido

- **R1 (P8, crítico)**: corregir el parser de cron en `scripts/automations/store.py` para
  soportar notación humana (`daily 08:30`) → 5-campos estándar (`30 8 * * *`); recomputar
  `next_run`; añadir `run-due` y hook de SessionStart que ejecute tareas atrasadas.
- **R2 (P3+P8)**: SessionStart dispara tareas `due` de automations (orquestador diario,
  morning brief) tras el bootstrap de memoria, respetando `--decide llm` local (CRIT-001).
- **R3 (P7)**: `savia-bootstrap-log.sh` — log append-only de instalación/arranque
  (`output/install-logs/` + `.savia/install.log`) con timestamps, pasos y exit codes,
  auto-consumido en el siguiente arranque para auto-corrección.
- **R4 (P6)**: `savia-install.sh` — bootstrap central idempotente que orquesta:
  memory-deps → opencode-install --link-only → automations init-defaults (con cron fijo)
  → merge-drivers → log. Sin red salvo descargas opcionales (Ollama, modo emergencia).
- **R5 (P2)**: inicializar `output/meta/calibration.json` con curva default en primer uso;
  garantizar que `run-all.sh` permanezca como fallback FULL con los tests l13 incluidos.
- **R6 (P3)**: verificar e inyectar recall de lecciones (SaviaLearning) en arranque si
  hay lecciones `active`/`human_authored` relevantes.
- **R7 (P4)**: sync de cúpulas — reflejar las LPs públicas de la sesión 2026-08-23
  (#995-#1000) en el índice de SaviaLearning y navigation notes.
- **R8 (P5)**: añadir/heredar entradas de SAGI, Metacognición L13 y SCL en la guía
  multiidioma principal (ES base, EN heredado; sin traducir todo el repo — solo las guías
  públicas canónicas).

### Excluido

- Convertir entradas INFERRED del criterio en human_authored (CRIT-031 invariable).
- Traducir los 16 idiomas completos (fuera de alcance de una noche; se hereda EN sobre ES).
- Ejecutar el orquestador con LLM cloud (CRIT-001: solo Ollama local).
- Modificar la constitución ni el libro de la relación sin aprobación (V-04).

## 3. Contratos

### 3.1 R1 — cron humano en store.py

```text
savia-automations.sh list --due
  cada tarea con cron válido → next_run computado
  "daily HH:MM" → "MM HH * * *"
  "weekly DOW HH:MM" → "MM HH * * DOW"
  exit 0 si alguna due, 1 si ninguna, 2 input inválido
```

### 3.2 R3 — log de instalación

```text
savia-bootstrap-log.sh write STEP EXIT [MSG]
  output/install-logs/YYYYMMDD-install.tsv (append)
  .savia/install.log last 200 lines (rotativo)
exit 0 siempre (nunca rompe el arranque)
```

### 3.3 R4 — instalador central

```text
savia-install.sh [--skip-ollama] [--dry-run] [--log]
  pasos: memory-deps → automations init-defaults → opencode --link → merge-drivers
  idempotente; cada paso registra en el log de instalación
exit 0 ok · 2 usage · 3 fallo con log de qué falló
```

### 3.4 R2 — SessionStart due-run

```text
# en session-init.sh tras bootstrap de memoria y pre-warm Ollama:
savia-automations.sh run-due --max 3 --local-llm  (CRIT-001)
  ejecuta el orquestador diario si está atrasado (next_run <= now)
  nunca bloquea el arranque: timeout global 5s ya existente
```

## 4. Reglas

| ID | Regla |
|---|---|
| RN-01 | Los loops saltan solos SOLO en modo shadow/propuesta; nunca auto-activan sustrato (CRIT-031). |
| RN-02 | El log de instalación nunca rompe el arranque (exit 0 siempre, append-only). |
| RN-03 | `run-due` respeta LLM local (Ollama 127.0.0.1:11434); si ausente, falla abierto sin cloud. |
| RN-04 | El instalador es idempotente y no toca la constitución ni el criterio. |
| RN-05 | Las entradas INFERRED siguen sombra; la activación humana permanece humana. |

## 5. Tests (pruebas irrefutables)

- R1: BATS parsea `daily 08:30` → `30 8 * * *` y computa `next_run` al día siguiente.
- R1: BATS con cron inválido → `next_run=None` sin crash.
- R3: BATS log escribe y el arranque no falla si el log falla.
- R4: BATS instalador idempotente (2 runs → mismos ficheros, 0 errores).
- R2: BATS `run-due` con tarea simulada atrasada → la ejecuta con `--local-llm`.
- R8: markdownlint de docs tocadas.

## 6. Cierre

**Estado 2026-08-23 (implementación autónoma autorizada):**

| R | Punto | Estado | Evidencia |
|---|---|---|---|
| R1 | P8 cron humano + next_run | ✅ IMPLEMENTADO | `store._normalize_cron` soporta daily/weekly; orquestador con next_run=2026-08-23T08:30Z |
| R2 | P3+P8 SessionStart run-due | ✅ IMPLEMENTADO | session-init dispara `run-due --max 2` async (banner lo confirma) |
| R3 | P7 log de instalación | ✅ IMPLEMENTADO | `savia-bootstrap-log.sh` append-only + rotación 200 líneas |
| R4 | P6 instalador central | ✅ IMPLEMENTADO | `savia-install.sh` idempotente orquesta 5 pasos con log |
| R5 | P2 calibración self-heal | ✅ IMPLEMENTADO | meta-monitor falla abierto; recalibrate auto-crea curva |
| R6 | P3 recall info en arranque | ✅ IMPLEMENTADO | banner: "SCL: N lección(es) active para recall" |
| R7 | P4 sync cúpulas | ✅ IMPLEMENTADO | 3 LPs de la sesión persistidas en SaviaLearning |
| R8 | P5 docs multiidioma | ✅ IMPLEMENTADO | getting-started ES+EN sección 2b (instalador + capacidades) |

Tests irrefutables: `tests/test-consolidacion-20260823.bats` — **13/13 PASS**
(R1a-d, R2a, R3a-b, R4a-c, R5a-b, P8a). Regresión: test-l13-meta-recalibra 8/8.
Deuda pre-existente fuera de scope: `test-scl-002-cupula.bats` TS-09/AC-4/5/6
fallan en main (CLI savia-vaults federación) — no introducida por esta spec.

Criterio de cierre cumplido: dos ciclos de tests sin findings P0/P1/P2 en alcance.