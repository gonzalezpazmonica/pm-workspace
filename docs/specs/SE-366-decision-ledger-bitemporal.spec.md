# SE-366 — Decision Ledger bitemporal: validez temporal doble + evidencia por decisión

**Status:** PROPOSED (2026-09-02, para aprobación de la operadora)
**Fecha:** 2026-09-02
**Área:** Memoria / Decisiones / Auditoría
**Fuente de inspiración:** world-model enterprise con grafo de conocimiento **bitemporal** + evidence rows (análisis open-source 2026-09-02) + Savia SE-268 (memoria two-speed) + SE-355 (audit ledger) + SE-352 (provenance)
**Criterio humano aplicable:** CRIT-001 (todo local, N3+ jamás a cloud)

---

## 1. Motivación

Savia registra decisiones (audit-receipts SE-355, decision-traces SPEC-188) pero
**sin dimensión temporal doble**: cuándo algo fue cierto en el mundo vs cuándo
Savia cambió de opinión. Sin bitemporalidad, un "hecho" corregido se sobreescribe
o se pierde la validez original, y no se puede responder "¿qué creía Savia el
día X, y qué evidencia lo sostenía?".

El modelo de referencia (grafo bitemporal + evidence rows) demuestra que la
**evidencia debe vivir como propiedad del dato**, no solo del veredicto: cada
decisión/hecho guarda su intervalo de validez y las filas de evidencia que lo
sustentan, y corregir **cierra la versión vieja y enlaza la nueva** en vez de
sobreescribir.

## 2. Alcance

**Dentro:**
- Formato bitemporal para decisiones/hechos persistentes de Savia
- Evidence rows: cada hecho referencia el documento/chunk/ref que lo sustenta
- Corrección no destructiva (cerrar versión + enlazar nueva), consulta "as-of"
- Integración con SE-355 (ledger), SE-352 (provenance), audit-receipts
- Skill/script de consulta temporal

**Fuera (specs derivadas):**
- Migración retroactiva de todo el histórico (solo nuevas decisiones primero)
- UI de navegación temporal (solo CLI/query en esta spec)

## 3. Principios de diseño

1. **Dos ejes temporales**: `valid_from/valid_to` (cuándo fue cierto en el mundo)
   y `asserted_at`/`superseded_at` (cuándo Savia lo registró/cambió de opinión).
2. **No overwrite**: corregir un hecho cierra la fila vieja (`superseded_at`) y
   crea la nueva enlazada (`supersedes`).
3. **Evidence rows**: cada hecho/versión referencia su fuente (`chunk_id`/`ref`/
   quote), no solo el veredicto que la cita.
4. **Consulta as-of**: se puede leer el estado del ledger en cualquier punto de
   su historia (derivado por fold, no almacenado duplicado).
5. **Escritura con puerta humana** para hechos que afectan criterio; las
   correcciones de datos automatizables pueden ser agente con audit.
6. **CRIT-001**: el ledger vive local (JSONL/SQLite), sin egress.

## 4. Formato (JSONL por línea = un hecho/versión)

```json
{
  "fact_id": "fact-20260902-x7",
  "predicate": "decision:dependencia_modelos",
  "subject": "savia:autonomia",
  "object": "ollama-local",
  "valid_from": "2026-09-01",
  "valid_to": null,
  "asserted_at": "2026-09-02T19:00:00Z",
  "superseded_at": null,
  "supersedes": null,
  "evidence": [
    {"ref": "docs/rules/domain/autonomous-safety.md", "quote": "...", "chunk_id": "as-014"},
    {"ref": "decision-traces/2026-09-02/autonomia.md", "chunk_id": "dt-03"}
  ],
  "origin": "agent:changelog-fix",
  "source": "agent" | "human"
}
```

### 4.1 Corrección no destructiva

Corregir el `object` (o el intervalo de validez) de `fact-x7` NO modifica la fila:
escribe `superseded_at` en `fact-x7` y crea `fact-x8` con `supersedes: fact-x7`.
`supersedes` puede encadenarse → el historial completo es derivable por fold.

## 5. Diseño técnico

### 5.1 `data/decision-ledger/ledger.jsonl` (append-only)

- Cada línea = un hecho/versión con el formato de §4.
- Append-only; corrección = nueva línea con `supersedes` (nunca editar la anterior).

### 5.2 `scripts/ledger-bitemporal.py` (consulta y gestión)

- `add`: inserta hecho (valida schema, genera fact_id).
- `correct <fact_id> --field --value --evidence`: cierra la fila (superseded_at),
  crea la nueva enlazada.
- `as-of <date>`: reconstruye el estado del ledger en esa fecha (fold).
- `history <fact_id>`: cadena completa de versiones con su evidencia.
- `evidence <fact_id> [--version]`: lista las filas de evidencia de esa versión.
- `--validate`: schema + referencias (evidence targets existen, fechas coherentes).

### 5.3 Integración

- `audit-receipts.sh` (SE-355): cada escritura al ledger emite receipt.
- `decision-trace-writer.py` (SPEC-188): las decisiones del director se pueden
  volcar al ledger con sus evidence rows.
- `ledger-bitemporal.py as-of` consumible por agentes para responder "qué
  creía Savia el día X".

## 6. Criterios de aceptación

- **AC-0** `add` valida schema y genera fact_id (test con fixture)
- **AC-1** `correct` cierra la fila vieja y crea la nueva con `supersedes`
  (no overwrite) — test
- **AC-2** `as-of <fecha>` devuelve el estado correcto en esa fecha (test con
  serie de 3 versiones)
- **AC-3** `history` expande la cadena completa de versiones (test)
- **AC-4** `evidence` lista las filas de evidencia de una versión (test)
- **AC-5** Evidencia con ref inexistente → WARN/error (grounding, refuerza L28 M2)
- **AC-6** Receipt SE-355 emitido en cada escritura (test)
- **AC-7** Sin regresión: SE-355/SE-352/SE-364 suites verdes

## 7. OpenCode Implementation Plan

### Bindings touched
- `data/decision-ledger/ledger.jsonl` (nuevo, gitignored si N3)
- `scripts/ledger-bitemporal.py` (nuevo)
- `audit-receipts.sh` (hook de escritura), `decision-trace-writer.py` (volcado)

### Verification protocol
```bash
bats tests/bats/test-ledger-bitemporal.bats
python3 scripts/ledger-bitemporal.py add --fixture
python3 scripts/ledger-bitemporal.py as-of 2026-09-01
python3 scripts/ledger-bitemporal.py history fact-20260902-x7
```

### Portability classification
- Python3 stdlib + JSONL local; portable; CRIT-001

## 8. Preguntas abiertas

- Volcar decisiones históricas existentes (SE-355/SPEC-188) al ledger: sí como
  Fase 2, sin reescribir el pasado (solo registrar lo que se sabe hoy).
- ¿Skill nueva `decision-ledger` o extensión de una existente? (decidir en impl;
  candidata: integrar en audit/decision skill)

## Referencias
- Utopia bitemporal graph + evidence rows (concepto, análisis 2026-09-02)
- Savia: SE-355 (audit ledger), SE-352 (provenance), SE-268 (memoria two-speed),
  SPEC-188 (decision traces), SE-364 (bucle evidencia), CRIT-001
