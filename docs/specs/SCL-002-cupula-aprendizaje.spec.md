# SCL-002 — Cúpula de aprendizaje: persistencia real y federación cross-instancia

**Status:** APPROVED → IMPLEMENTED (2026-08-17)
**Fecha:** 2026-08-17
**Area:** Memoria / Epistemología / SaviaVaults
**Branch:** agent/scl-001-aprendizaje-continuo
**Estimación:** ~6h (3 slices)

---

## Origen

SCL-001 implementó el bucle de aprendizaje (captura → propuesta → ciclo de vida →
métrica → reporte) pero **no cumplió su promesa de persistencia cross-instancia**:
las lecciones vivían en `docs/learning-proposals/` (local al repo) y un JSONL en
`output/` (gitignored). No había cúpula, ni entidad en el grafo, ni forma de que
**otros savias** consumieran las lecciones. La operadora lo señaló: "¿en qué
cúpula persisten las lecciones y cómo otros savias se benefician?" — y era un
maquillaje. Esta spec lo implementa de verdad.

## Arquitectura

```
SaviaVaults (servidor de cúpulas)
└── example-context (cúpula de contexto de ejemplo)
└── savia-docs    (cúpula de docs — NO tocar)
└── SaviaLearning (cúpula NUEVA del bucle SCL)
    └── learning/
        └── LP-YYYYMMDD-<hash>.md   ← lección persistida (git-backed)

Flujo de captura con persistencia:
  learning-proposal.sh --persist
    → genera propuesta local (docs/learning-proposals/LP-*.md)
    → learning-persist.sh → escribe nota en SaviaLearning/learning/
      con frontmatter entity + relations + wikilinks
    → KnowledgeGraph de SaviaVaults la indexa (nodo + 3 relaciones)

Federación (consumo cross-instancia):
  learning-federate.sh --list          → lecciones disponibles en la cúpula
  learning-federate.sh --import <id>   → trae la lección como propuesta
    local INFERRED (shadow, sin efecto), pendiente de human_authored
```

## Slice 1 — Cúpula propia + schema

**AC-1.1.** Schema `learning_proposal.yaml` existe en
`projects/savia-vaults/schema/entities/` con type, id, provenance
(INFERRED/human_authored), lifecycle, origin, trigger, target, evidence_hash,
created_utc, expected_p_consistent (test).

**AC-1.2.** Cúpula `SaviaLearning` creada y registrada en
`projects/savia-vaults/savia-vaults.domes.json` con path relativo y
confidentiality N2 (asercion).

**AC-1.3.** `graph --action stats` sobre SaviaLearning indexa una nota persistida
como nodo con sus relaciones (test E2E con SaviaVaults real).

## Slice 2 — Persistencia real

**AC-2.1.** `learning-persist.sh --file <proposal>` escribe la nota en
`vaults/SaviaLearning/learning/<id>.md` con frontmatter `entity.type:
learning_proposal`, `entity.id`, `relations` (PROPOSES_CHANGE, EVIDENCE_FROM,
MEASURED_BY) y wikilinks (test).

**AC-2.2.** Idempotencia: persistir la misma propuesta dos veces → 1 nota, la
segunda devuelve exit 1 con "ALREADY" (test).

**AC-2.3.** `learning-proposal.sh --persist` persiste automáticamente en la
cúpula tras generar la propuesta (test).

## Slice 3 — Federación mínima

**AC-3.1.** `learning-federate.sh --list` lista las lecciones de la cúpula con
id, lifecycle, provenance y target (test).

**AC-3.2.** `learning-federate.sh --import <id>` importa la lección como
propuesta local con `provenance: INFERRED`, `lifecycle: proposed`,
`federated: true`, `source_dome: SaviaLearning` (test).

**AC-3.3.** La importación es idempotente (2ª llamada → exit 1 "ALREADY") (test).

**AC-3.4.** La propuesta federada nunca se auto-activa: recorre el ciclo normal
de SCL-001 (requiere `human_authored` para `active`).

## Out of scope

- Autenticación/A2A real entre instancias remotas (SCL-003): la federación aquí
  es sobre la cúpula git-backed local compartida, no red remota.
- Ingestión al grafo vía MCP (ya funciona vía frontmatter; MCP es transporte).

## Verification method

1. Suite BATS `tests/test-scl-002-cupula.bats` (7 tests).
2. Prueba en producción real: captura con `--persist` → nota en
   `vaults/SaviaLearning/learning/` → `graph --action stats` muestra nodo +
   relaciones → `learning-federate.sh --list` y `--import` funcionan.
3. `savia-vaults dome list` registra SaviaLearning.

## Referencias

- SCL-001: `docs/specs/SCL-001-aprendizaje-continuo.spec.md`
- Regla: `docs/rules/domain/scl-001-learning-loop.md`
- Scripts: `scripts/learning-{persist,federate}.sh`
- SaviaVaults: `projects/savia-vaults/` (schema, domes.json, CLI)
