---
id: policy-soberania-datos
type: policy
name: "Soberanía de datos"
status: active
enforcement: mandatory
implements_criterio: CRITERIO#soberania-datos
owner: person-monica
relations:
  - { type: AppliesTo, target: unit-savia-core }
created: 2026-09-01
updated: 2026-09-01
origin: owner
source: human
---

# Soberanía de datos

Implementa CRITERIO#soberania-datos (CRIT-001): los datos N3+ jamás salen a
proveedores cloud. Todas las entidades `resource` deben cumplir esta política.
