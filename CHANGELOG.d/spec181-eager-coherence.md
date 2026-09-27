---
version_bump: patch
section: Changed
---
- SPEC-181 AC3 medido de verdad: `autonomous-safety.md` se cargaba en cada sesión sin tier (no contaba en el presupuesto) y `radical-honesty.md` declaraba 1263 tokens con ~1816 reales. Núcleos eager + anexos bajo demanda (`autonomous-safety-reference.md`, `radical-honesty-enforcement.md`); tres reglas L1 que no cargaba nadie pasan a L2; 10 reglas sin frontmatter lo reciben. OpenCode carga `knowledge-discovery-priority.md` (SE-335: eager en ambos frontends) en lugar de `agents-catalog.md` (L3, bajo demanda). Eager L0+L1: 2879 ≤ 3000 con presupuestos ≥ tamaño/4. Tests de coherencia: mismo conjunto eager en ambos frontends, L1 == eager, presupuestos honestos, gates inmutables presentes en el núcleo.
