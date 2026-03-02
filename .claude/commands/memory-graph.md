---
name: memory-graph
description: Grafo semántico de relaciones semánticas entre memorias. Construye knowledge graph de engrams. Consulta conexiones. Detecta memorias aisladas. Genera visualización Mermaid.
developer_type: all
agent: task
context_cost: high
---

# /memory-graph

Crea un grafo de conocimiento mapeando las relaciones entre memorias: qué entidades aparecen en dónde, qué decisiones influyen en qué eventos, qué contexto conecta memorias aparentemente aisladas. Herramienta de descubrimiento y coherencia.

## Sintaxis

```
/memory-graph [--build] [--query entity] [--visualize] [--lang es|en]
```

## Flags

- `--build` — Construye el grafo desde engrams
- `--query entity` — Busca conexiones de una entidad específica
- `--visualize` — Genera diagrama Mermaid (defecto: activado con --build)
- `--lang es|en` — Idioma de salida (defecto: es)

## Ejemplo de Uso

```bash
/memory-graph --build --visualize
# Construye grafo completo, genera diagrama Mermaid

/memory-graph --query "proyecto-alpha" 
# Encuentra todas las memorias conectadas con proyecto-alpha

/memory-graph --build --lang en
# Grafo en inglés (sin visualización)
```

## Qué es el Grafo

Nodos = memorias. Aristas = relaciones semánticas:

```
Entity (entidad aparece en múltiples memorias)
  └─ 2025-02-15_session.md
  └─ 2025-02-28_decisions.md
  └─ 2025-03-01_retrospective.md

Decision → Event (decisión causó evento)
  └─ "Usar GraphQL" → "Reescribir BFF completado"

Context Bridge (contexto común conecta memorias)
  └─ Sprint 2.3 ↔ Goals T1 2025
```

## Salida esperada

```
Grafo de Conocimiento — Engrams
================================
Nodos: 12 memorias
Aristas: 24 relaciones

Entidades principales:
  - "proyecto-alpha" (grado 6) — aparece en 6 memorias
  - "tech-debt" (grado 4) — conecta decisiones y retros
  - "sprint-2.4" (grado 5) — contexto de 5 memorias

Memorias aisladas (revisar):
  - 2025-01-05_experiment.md — sin conexiones

Diagrama Mermaid:
[Visualización generada → memory-graph.mermaid]
```

## Detección de Patrones

### Memoria Aislada
Nodo sin aristas. Indica memoria que no se conecta con el resto (posible
antigua, específica de contexto extinto, o no referenciada).

### Hub de Conocimiento
Nodo de alto grado (varias aristas). Centro neurálgico: si desaparece,
se fragmenta el grafo. Crítico preservar.

### Cadena de Decisiones
Path que atraviesa múltiples memorias. Muestra causa-efecto a lo largo
del tiempo.

### Contexto Superpuesto
Varias memorias con las mismas entidades. Candidatas a consolidación
o resumen cruzado.

## Archivos generados

- `memory-graph.json` — Grafo completo en JSON (nodes + edges)
- `memory-graph.mermaid` — Visualización Mermaid (embebible en MD)
- `memory-graph-analysis.md` — Reporte con patrones detectados

## Casos de uso

1. **Onboarding**: Nuevo miembro ejecuta `/memory-graph --query proyecto`
   para entender qué decisiones y eventos pivotales afectaron el proyecto.

2. **Auditoría de coherencia**: Detectar memorias obsoletas o desconectadas.

3. **Planificación**: Visualizar cómo las decisiones pasadas restringen
   o habilitan opciones futuras.

4. **Educación**: Mostrar el "hilo histórico" de una iniciativa a través
   de múltiples engrams.

## Configuración

En `config.yaml`:

```yaml
memory:
  graph:
    entity_extraction: true
    min_degree_isolation: 1    # nodos con grado < 1 = aislados
    mermaid_max_nodes: 20      # comprimir si > 20 nodos
```

---
Persona: Savia — "El conocimiento vive en relaciones, no en fragmentos aislados. Mi grafo te muestra dónde está la sabiduría conectada."
