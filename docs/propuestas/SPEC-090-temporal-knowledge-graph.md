---
spec_id: SPEC-090
title: Knowledge Graph temporal en SQLite — cache relacional por maquina
status: Proposed
origin: mempalace research (2026-04-08)
severity: Media
effort: ~3h
---

# SPEC-090: Knowledge Graph Temporal

## Principio

Un grafo de relaciones entre entidades del workspace, almacenado en SQLite
como cache local. Permite consultas que JSONL lineal no puede: impacto en
cascada, relaciones temporales, conexiones entre proyectos.

Texto plano (.md, .jsonl) sigue siendo la fuente de verdad.

## Arquitectura

```
Fuentes de verdad (.md)          SQLite cache (~/.savia/knowledge-graph.db)
─────────────────────            ─────────────────────────────────────────
memory-store.jsonl        →      entities: id, name, type, first_seen, last_seen
MEMORY.md + topic files   →      relations: entity_a, relation, entity_b, valid_from, valid_to
decision-log.md           →      facts: subject, predicate, object, confidence, source
agent-memory/             →      (indices para busqueda rapida)
```

## Schema SQLite

```sql
CREATE TABLE entities (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  type TEXT NOT NULL,  -- person, project, tool, concept, decision
  first_seen TEXT,
  last_seen TEXT
);

CREATE TABLE relations (
  id INTEGER PRIMARY KEY,
  entity_a INTEGER REFERENCES entities(id),
  relation TEXT NOT NULL,  -- uses, owns, blocks, depends_on, decided
  entity_b INTEGER REFERENCES entities(id),
  valid_from TEXT,
  valid_to TEXT,  -- NULL = vigente
  source TEXT,    -- fichero .md de origen
  confidence REAL DEFAULT 1.0
);

CREATE INDEX idx_relations_a ON relations(entity_a);
CREATE INDEX idx_relations_b ON relations(entity_b);
CREATE INDEX idx_entities_name ON entities(name);
```

## Operaciones

1. `scripts/knowledge-graph.sh build` — regenera SQLite desde .md sources
2. `scripts/knowledge-graph.sh query "que relaciones tiene X"` — consulta en lenguaje natural (traducido a SQL)
3. `scripts/knowledge-graph.sh impact "entity"` — cascada de impacto
4. `scripts/knowledge-graph.sh status` — estadisticas del grafo

## Integracion

- `/graph-build` ya existe como comando — conectar al nuevo script
- `/graph-query` ya existe — conectar al SQLite en vez de JSONL
- `/graph-impact` ya existe — ahora con SQL real en vez de grep

## Criterios de aceptacion

- [ ] Script knowledge-graph.sh con subcomandos build/query/impact/status
- [ ] SQLite schema con entities + relations + indices
- [ ] Build lee de: memory-store.jsonl, MEMORY.md, decision-log.md
- [ ] Query traduce consulta simple a SQL y devuelve resultados
- [ ] Impact muestra cascada de relaciones (BFS desde entidad)
- [ ] Degradacion sin SQLite: informar "ejecuta /graph-build primero"
- [ ] Tests BATS >= 10 casos
- [ ] .md/.jsonl sigue siendo la fuente de verdad
