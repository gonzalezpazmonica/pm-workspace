# SCL-007 — Federación cross-dome real: lecciones entre instancias vía A2A

**Status:** APPROVED → IMPLEMENTED (2026-08-17)
**Fecha:** 2026-08-17
**Area:** Memoria / Federación / SaviaVaults A2A
**Branch:** agent/scl-001-aprendizaje-continuo
**Estimación:** ~4h

---

## Origen

SCL-002 implementó la persistencia en la cúpula SaviaLearning y la federación
*local* (importar lecciones de la propia cúpula). Lo que faltaba: **federación
cross-dome real** — que una instancia de Savia comparta sus lecciones con otra
instancia remota, y que la recupere y la use. La infraestructura A2A de
SaviaVaults (servidor `/health`, `/search`, `/share`) ya existía; SCL-007 la
cablea al bucle de aprendizaje.

## Diseño

```
Instancia A (SaviaLearning)                 Instancia B (remota)
  learning-federate.sh --share <id> --to B:url
    └─ POST /share {path: learning/<id>.md, content}
                                              → escribe en B/vaults/SaviaLearning/learning/
  learning-federate.sh --search-remote --url B:url --query "q"
    └─ GET /search?q=q → lista lecciones de B
                                              → B importa como INFERRED (--import)
```

- **Share**: envía la nota markdown de la lección (fuente de verdad) a la
  cúpula de la instancia remota vía `/share`. La nota conserva su frontmatter
  (entity/relations) → indexada en el grafo de la instancia receptora.
- **Search-remote**: consulta `/search` del servidor remoto y lista las
  lecciones (`learning/*.md`).
- **Import**: la instancia receptora trae la lección como propuesta local
  `INFERRED` (shadow, sin efecto), pendiente de `human_authored` — nunca
  auto-activa (CRIT-031).

## Acceptance criteria

- AC-1. `--share <id> --to <url>` envía la lección al dome remoto vía `/share`
  (A2A) y la nota aparece en el dir de la instancia receptora (test con
  servidor real).
- AC-2. `--search-remote --url --query` consulta `/search` y lista lecciones
  del dome remoto (test con servidor mock A2A).
- AC-3. La lección compartida/remota se importa como `INFERRED` + `proposed` +
  `federated: true` (test).
- AC-4. Importar la misma lección dos veces no duplica (test).
- AC-5. `--share` sin `--to` es error de uso (test).
- AC-6. `--search-remote` sin `--url`/`--query` es error de uso (test).

## Verification method

1. Suite BATS `tests/test-scl-007-federacion.bats` (6 tests).
2. E2E real: instancia A comparte la lección PAT a un servidor A2A remoto;
   la instancia B importa como INFERRED con `source_dome: SaviaLearning`.

## Nota sobre infra A2A

El servidor A2A de SaviaVaults sirve `/share` (escribe notas) correctamente.
El `/search` del servidor en modo multi-dome consulta los domes registrados;
en el modo `--path` directo puede no respetar el path para el search (bug
pre-existente de SaviaVaults, fuera del scope de SCL-007). El contrato
`--search-remote` de SCL consume `/search` tal como lo sirve el servidor.

## Out of scope

- Autenticación/TLS entre instancias (token opcional soportado por A2A).
- Reconciliación de conflictos entre lecciones duplicadas en distintas
  instancias (SE-309 knowledge governance).
- Descubrimiento automático de instancias (registro manual vía `--to`).

## Referencias

- SCL-002: `docs/specs/SCL-002-cupula-aprendizaje.spec.md`
- SaviaVaults A2A: `projects/savia-vaults/src/server/a2a.ts`,
  `src/federation/`
- Script: `scripts/learning-federate.sh --share/--search-remote`
