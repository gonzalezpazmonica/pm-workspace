# Architectural Laws (SE-386)

Jerarquía normativa: **CRITERIO → LAWS → SPEC → CONTRACTS → IMPLEMENTATION → TESTS**.

CRITERIO decide los límites (CONSTITUCION + savia-ethical-principles + CRITERIO.md). LAWS preservan las garantías:
invariantes durables y observables, independientes de implementación. Una implementación o test que contradiga una
LAW es incorrecta. Fuente normativa: este Markdown humano. `index.yaml` es solo el registro machine-readable.

## Reglas de una LAW
MUST describir comportamiento observable · una única obligación · MUST/MUST NOT · independiente de tecnología ·
decisión duradera · sin detalles de framework · sin duplicar CRITERIO · vinculada a tests cuando verificable.

## Domains
- `human-control.md` — autoridad humana
- `memory.md` — estado canónico de memoria
- `execution.md` — ejecución segura
- `privacy.md` — soberanía de datos
- `federation.md` — capacidades entre instancias
