# Proto Architecture Research — Aplicabilidad a Savia

> Análisis técnico del sistema Proto (Arc Institute, 2026) y su traslación a pm-workspace.
> Generado: 2026-06-28

## Qué es Proto

Proto es un sistema de optimización de secuencias proteicas desarrollado por el Arc Institute (2026). Utiliza técnicas de inferencia probabilística — concretamente Markov Chain Monte Carlo (MCMC) y Rejection Sampling — combinadas con modelos estructurales como AlphaFold para encontrar secuencias de proteínas que satisfagan múltiples constraints biológicos simultáneamente.

**Componentes clave verificados:**

1. **Dual Pool (proposal/result)**: distingue `proposal_sequences` (workspace efímero del sampler, se evalúan y descartan) de `result_sequences` (mejores encontradas, persistentes tras superar constraints del optimizer).

2. **Energy-Based Model**: cada constraint devuelve `f(x) ∈ [0.0, 1.0]`. La energía total es la suma ponderada. El sampler minimiza energía. Permite comparar propuestas y detectar qué constraint es el cuello de botella.

3. **Multi-stage Coarse-to-Fine**: Stage 1 usa Rejection Sampling barato (5000 muestras, constraints simples). Stage 2 usa MCMC costoso con AlphaFold sobre los mejores candidatos del Stage 1. Constraints caros solo en el stage final.

4. **Self-describing API**: `get_tool_schema` y `get_tool_example` son herramientas MCP que devuelven el esquema exacto de inputs/outputs. `llms.txt` es un índice de toda la documentación en formato texto plano para LLMs.

5. **Typed Sequences**: cada secuencia tiene un tipo estático que define qué constraints pueden aplicarse. No hay evaluación de constraints inválidos.

6. **Temperature Annealing**: el parámetro de temperatura del sampler decrece durante la búsqueda para pasar de exploración (alta temperatura) a explotación (baja temperatura).

---

## Los 4 primitivos aplicables a Savia

### SE-235: Dual Pool (Proposal State vs Result State)

**Analogía exacta**: las ramas `agent/*` son el proposal pool; `main` es el result pool.

**Gap detectado**: ningún mecanismo impide que un artefacto en rama `agent/*` sea referenciado como fuente de verdad por otro artefacto antes de pasar por el Code Review Court. El plugin `block-proposal-as-source.ts` cierra este gap.

**Aplicabilidad: ALTA** — La analogía es directa y el gap es real.

---

### SE-236: Energy-Based Scoring en Code Review Court

**Analogía exacta**: los jueces del Code Review Court son los constraints. Su output (PASS/FAIL/CONDITIONAL) es la evaluación de la secuencia. El gap: producen texto libre, no scores numéricos.

**Beneficio**: con scores numéricos, el court-orchestrator puede detectar el bottleneck judge, ordenar PRs por calidad, y parar anticipadamente si la energía ya supera el umbral sin esperar a todos los jueces.

**Aplicabilidad: ALTA** — La analogía es directa. El script `court-score-aggregator.sh` implementa la agregación de energía.

---

### SE-237: Coarse-to-Fine DAG Scheduling

**Analogía exacta**: Proto Stage 1 (barato) filtra antes de Stage 2 (costoso). En Savia: `feasibility-probe` (MEDIUM) → `test-runner` (MEDIUM) → `court-orchestrator` (EXPENSIVE).

**Gap detectado**: no está documentado como patrón, y pipelines ad-hoc pueden invocar `court-orchestrator` antes de `test-runner`. El checker `dag-gate-cost-checker.sh` detecta estas inversiones.

**Aplicabilidad: ALTA** — El patrón ya existe parcialmente, falta formalización y enforcement.

---

### SE-238: Skills Schema Descubrible Programáticamente

**Analogía exacta**: `get_tool_schema` en Proto. `SKILLS.md` de Savia es legible por humanos pero no estructurado para consumo programático. Un agente externo o un router automático necesita `skills-schema.json`.

**Aplicabilidad: ALTA** — Coste de implementación bajo (script de generación), beneficio alto para routing automático.

---

## Por qué las otras 2 mejoras NO son aplicables

### Typed Sequences (no aplicable)

Proto usa tipos estáticos para las secuencias proteicas porque el espacio de posibles secuencias es combinatoriamente enorme y los constraints son específicos a tipos de aminoácidos. En Savia, los artefactos (specs, código, hooks) no tienen tipos estáticos que restrinja qué constraints (jueces) pueden evaluarlos. Los 5 jueces del Code Review Court aplican a cualquier PR. Añadir un sistema de tipos estáticos para artefactos de Savia requeriría redefinir toda la arquitectura del court sin beneficio claro — el court ya aplica todos los jueces a todos los PRs y omite los que no son relevantes.

**Decisión**: No aplicable. Overhead de implementación alto, beneficio marginal en el contexto de Savia.

---

### Temperature Annealing (no aplicable)

Proto usa temperature annealing para controlar la exploración del sampler MCMC: alta temperatura al inicio (acepta propuestas malas para explorar el espacio), baja temperatura al final (solo acepta mejoras). Este mecanismo tiene sentido en sistemas de búsqueda estocástica con espacios continuos.

El pipeline SDD de Savia no es un sampler estocástico. Los agentes implementan specs determinísticas, no exploran un espacio de búsqueda. No hay un parámetro de "temperatura" que modular — los agentes o implementan bien una spec o no lo hacen. El SPEC-197 (Annealing Schedule Meta-Judges) ya analiza esta idea y la descarta por las mismas razones.

**Decisión**: No aplicable. El modelo mental no traslada. SPEC-197 cubre el análisis previo.

---

## Resumen de SE-235..SE-238

| Spec | Primitivo Proto | Gap en Savia | Artefactos |
|------|----------------|--------------|------------|
| SE-235 | Dual Pool | Referencias cross-pool sin control | `block-proposal-as-source.ts`, sección en `autonomous-safety.md` |
| SE-236 | Energy-Based Constraints | Scores cualitativos, no comparables | `court-score-aggregator.sh`, `court-numeric-scoring.md` |
| SE-237 | Coarse-to-Fine Stages | Pipeline order no enforced | `dag-gate-cost-checker.sh`, `coarse-to-fine-gates.md` |
| SE-238 | Self-describing API | No schema programático de skills | `skills-schema-generate.sh`, `skills-schema.json`, `.llms.txt` |
