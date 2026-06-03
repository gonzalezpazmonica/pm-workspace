# Knowledge Graph — Memoria Savia con aristas tipadas

> SE-162. Engine: `scripts/knowledge-graph.py` (stdlib Python, sin pip deps).
> DB: `~/.savia/knowledge-graph.db` (SQLite WAL, gitignored, derived).
> Fuente de verdad: `.md` y `.jsonl` — la DB es cache regenerable.

## Por qué

La memoria de Savia era texto plano sin grafo. GBrain (+31pp P@5) demuestra
que añadir aristas tipadas entre entidades (proyecto→spec, decisión→sprint,
regla→spec) multiplica la precisión de recall sin cambiar las fuentes.

## Tipos de entidades (entities)

| Tipo | Ejemplos |
|---|---|
| `project` | pm-workspace, trazabios, savia-web |
| `person` | Monica |
| `spec` | SE-162, SPEC-090 |
| `rule` | architectural-vocabulary, skill-maturity-kanban |
| `skill` | caveman, knowledge-graph |
| `tool` | Azure-DevOps, OpenCode, SQLite |
| `concept` | entradas de memoria genéricas |
| `decision` | entradas tipo decision en memory-store |

## Tipos de relaciones (relations)

| Relación | Semántica |
|---|---|
| `implements` | proyecto o regla implementa spec |
| `uses` | entidad usa otra entidad |
| `mentions` | entrada de memoria menciona entidad |
| `depends_on` | spec depende de otra spec |
| `blocks` | entidad bloquea progreso de otra |
| `owns` | persona/proyecto es propietario |
| `decided` | entidad tomó una decisión |

## Comandos

```bash
bash scripts/knowledge-graph.sh build             # Construye/reconstruye desde fuentes
bash scripts/knowledge-graph.sh status            # Estadísticas del grafo
bash scripts/knowledge-graph.sh query "SE-162"    # Busca entidades y relaciones
bash scripts/knowledge-graph.sh impact "pm-workspace" --depth 2  # Cascada BFS
bash scripts/knowledge-graph.sh entities --type spec              # Lista por tipo
```

## Fuentes de ingesta

1. `output/.memory-store.jsonl` — memory-store del workspace (26 entries hoy)
2. `~/.savia/memory-cache.db` — memoria persistente externa (86 entries)
3. `docs/ROADMAP.md` — extrae specs + depends_on ("Requiere/Post SE-NNN")
4. `docs/rules/domain/*.md` — rule nodes + spec references

## Invariantes (tests/test-knowledge-graph.bats, 26/26)

- Build produce ≥100 entidades y ≥100 relaciones desde fuentes del workspace.
- `pm-workspace` aparece como entidad `project`.
- Tipos de entidad incluyen `spec`, `rule`, `project`.
- Tipos de relación incluyen `implements`, `uses`, `mentions`, `depends_on`.
- Build es idempotente: segunda ejecución produce mismo conteo.
- Degradación sin DB: `status` devuelve mensaje, no crash.

## No-objetivos

- No extrae semántica con LLM en cada escritura (eso es SE-166+).
- No reemplaza `memory-store.jsonl` ni `memory-cache.db` como fuente de verdad.
- No busca en lenguaje natural con embeddings (eso requiere SE-162 Phase 2).
- No sincroniza en tiempo real — se reconstruye con `build`.

## Línea base 2026-06-02

- Entidades: 543 (211 specs, 209 reglas, 46 conceptos, 24 decisiones…)
- Relaciones: 661 (265 implements, 209 uses, 175 mentions, 12 depends_on…)
