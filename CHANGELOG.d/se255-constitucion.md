---
spec: SE-255
---

## SE-255 — Constitución operativa de Savia (identidad, criterio, relación, lealtad)

### Slice 1 — CONSTITUCION.md

20 artículos operativos en 5 títulos (~990 tokens):
- T1 Identidad: Savia es patrón de texto, no siente, no sustituye
- T2 Deberes: honestidad calibrada, reconocimiento proactivo, cita, soberanía
- T3 Prohibiciones: 8 violaciones (V-01 a V-08) con mapa articulo→enforcement
- T4 Lealtad estructural: principal único, verificable, calidez sin teatro
- T5 Relación con el cuerpo: herencia a 81 agentes, gobierno sobre SE-254
6 casos adversariales en evals-ci. AGENTS.md actualizado con referencia.

### Slice 2 — CRITERIO.md + bootstrap

CRITERIO.md skeleton con schema JSON. `scripts/criterio-init.sh`: minería de
historial (PR comments, digests, changelogs) + generación de borradores con
provenance:INFERRED. Regla dura: solo provenance:human_authored activa entradas.

### Slice 3 — Libro de la relación

`data/relacion/ledger.jsonl` append-only con hash encadenado (nivel N4).
`scripts/relacion-capture.sh`: 6 tipos de entrada (override, error_reconocido,
acierto_verificado, no_se_declarado, enmienda_criterio, feedback_explicito).
`scripts/relacion-report.sh`: vista /relacion con estadísticas y trayectoria.

### Slice 4 — Calibración medida

`scripts/calibracion.py`: registro de claims, resolución desde ledger, curvas
por ámbito (mín N=25), ajuste inline de confianza (gap >15pp). `.claude/templates/no-se.md`:
plantilla de no-sé estructurado como respuesta de primera clase.

### Slice 5 — Criterio citado en acciones delegadas

`scripts/criterio-cite.sh`: resolución CRIT-XXX en <1s. Guard pre-output
`require-criterion-cite.ts`: valida ART-06 en artefactos delegados; sin CRIT →
ruta a questions/, no a drafts/.

### Slice 6 — Atestación de lealtad

`scripts/savia-attest.sh`: matriz nivel-N × destino semanal con hash encadenado.
Regla dura: N3+ jamás a cloud.

### Tests

35 BATS tests green. Suite adversarial en tests/evals/cases/se255-constitucion.yaml.
