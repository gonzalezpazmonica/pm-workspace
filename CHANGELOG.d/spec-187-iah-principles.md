### Añadido — SPEC-187 — Alineación IAH

Alineación de los principios éticos de Savia con el marco IAH (Inteligencia Artificial Humanista).

**Principios nuevos** (`docs/rules/domain/savia-ethical-principles.md`):
- §14 Sostenibilidad ambiental y huella digital (IAH-7)
- §15 Pluralismo cultural y lenguas minoritarias (IAH-8)
- §16 Robustez técnica frente a manipulación (IAH-9)
- §17 Explicabilidad como derecho (IAH-3)

**Refinamientos**:
- §3 Responsabilidad: añadido párrafo sobre dominios críticos (salud, justicia, empleo, educación, finanzas personales) con prohibición de actuar sin supervisión humana explícita.
- §4 Dignidad humana: añadida obligación ACTIVA de auditoría de sesgos.

**Protocolo de conflicto**: corolarios IAH-7/IAH-8 — sostenibilidad > eficiencia, pluralismo > eficiencia.

**Tabla de integración**: ampliada a 17 filas (§14-§17).

**Tests**: `tests/test-ethical-principles-iah-coverage.bats` — 9/9 PASS.
