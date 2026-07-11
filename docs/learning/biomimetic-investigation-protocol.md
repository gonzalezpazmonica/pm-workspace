# Biomimetic Investigation Protocol — Learned Patterns

> Generated from 2 sessions: brainless-patterns (DONT-MERGE 2026-06-18) and
> biochem-context (MERGE candidate 2026-06-19). Captures reusable discipline
> for any future "apply X biological pattern to context engineering" task.

## Pre-flight gates (innegociables)

Aplicar a CADA patrón candidato ANTES de tocar código:

1. **Cheap-baseline test**: ¿hay un comando Unix de una línea que dé el 80% del
   valor? Si sí, el patrón muere. Ejemplos que matan: `git log --since=30d
   --name-only | sort | uniq -c`, `sha256sum`, `grep -c`, `find -name`.

2. **No-simulator rule**: si la métrica de éxito requiere un simulador escrito
   por mí en el mismo sistema cerrado, el patrón muere. Solo cuentan baselines
   externos verificables.

3. **Falsifiability**: la hipótesis tiene que ser refutable con datos reales en
   <2 horas. Si no, muere.

4. **Security pre-flight**: cualquier input externo (usuario, agente) pasa por
   escape/validación desde la primera línea. Sin excepciones por "es prototipo".

5. **Concurrency pre-flight**: cualquier estado mutable necesita flock o
   append-only puro desde la primera línea.

6. **Spec primero**: NO escribo código sin spec SDD mínima aprobada. Rule #8.

## Adversarial review en 2 fases

- **Fase A (pre-flight)**: convoca juez ANTES de implementar. Si veredicto es
  KILL, archiva la propuesta. Coste evitado: días de implementación inútil.
- **Fase B (post-impl)**: convoca juez DESPUÉS de implementar contra el
  artefacto real. Aplica fixes CRITICAL/HIGH antes de proponer merge.

## Vocabulario biológico: regla de oro

> **El código de producción usa nombres técnicos honestos. La inspiración
> biológica vive solamente en frontmatter y documentación.**

Ejemplos correctos:
- OK Función `_fingerprint`, frontmatter `bioquimica:` con `inspiracion`,
  `analogo_biologico`, `paper_dois`, `warning: "no implementa X"`.
- FAIL Función `pheromone_deposit`, archivos en `scripts/brainless/`, variables
  `crispr_validated`, scripts llamados `stentor-cascade.sh`.

## DOI validation

Cualquier DOI citado pasa por `curl https://api.crossref.org/works/<doi>`.
Si HTTP ≠ 200, el DOI muere. Si el título no coincide con la afirmación, el
DOI muere. Anota fecha de validación en `doi_validated:` del frontmatter.

## Criterios AC autoimpuestos

Cuando un criterio AC propio falla, hay 2 opciones honestas:
- (a) Hacer más trabajo hasta que el AC se cumpla.
- (b) Reescribir el AC honestamente, con historia de qué cambió y por qué.

NUNCA opción (c): mergear ignorando el AC. Esa es exactamente la racionalización
que Rule #8 está diseñada para atrapar.

## Consolidación de patrones repetidos (Rule #6)

Cuando inventarías N callers convergentes:
- N>5: candidato fuerte a skill consolidadora.
- Antes de migrar TODOS, audita cuáles tienen lógica auxiliar (fallbacks,
  corner cases) que la skill perdería. Esos NO se migran. Anótalo en
  comentarios `SE-XXX NOTE: not migrated, reason: ...`.
- Migración con prueba de equivalencia byte-a-byte vs baseline pre-cambio.

## Lecciones aplicables a cualquier patrón biológico futuro

| Patrón biológico | Aplicación realista | Trampa común |
|---|---|---|
| Stigmergy (Tero, Reid) | Sustrato compartido para coordinar agentes | Inyección si no se escapa input |
| Quimiotaxis (Berg) | Búsqueda gradient-ascent local | Mínimos locales múltiples |
| LSH biológico (Dasgupta) | Pre-filtro a HNSW | Requiere vectorización previa |
| DNA barcoding (Hebert) | Fingerprint determinista corto | No detecta near-duplicates |
| CRISPR memoria (Barrangou) | Append-only post-validación | Capacidad limitada, no semántico |
| Sparse coding (Olshausen) | Representación con pocos elementos activos | Coste aprendizaje del diccionario |
| Splicing alternativo (Ast) | Múltiples vistas de una fuente | Errores de splicing → bugs |

## Anti-patrones específicos (matar al detectarlos)

- **"Bioluminescent observability"**, **"chromosomal indexing"**, **"enzymatic
  caching"** — si un nombre suena demasiado bien, probablemente es theater.
- **Métrica que es función del input que la genera** (tautología circular).
- **Simulador que comparte features entre routing y validation**.
- **AC autoimpuesto al final, ignorado al final**.
- **"Esto es exploratorio, SDD sería ceremonial"** (precisamente cuando lo
  necesitas más).

## Patrón meta: la inspiración biológica es una lente, no una métrica

La biología te ayuda a pensar en problemas de coordinación distribuida,
codificación sparse, fallback jerárquico, memoria selectiva. Te da
**hipótesis** que aún tienen que validarse con baselines clásicos. NO te
da implementación lista. NO te da mejora garantizada. NO te da licencia
para ignorar disciplina de ingeniería.
