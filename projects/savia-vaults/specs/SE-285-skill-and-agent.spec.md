# SE-285 — SaviaVaults Skill + Context Dome Manager Agent

> **Parent**: SE-280/281/282/283/284 (SaviaVaults ecosystem)
> **Scope**: Skill for AI agent interaction with SaviaVaults + Heavy agent for context dome strategy

## Metadatos

- **Task ID:** SE-285
- **PBI padre:** Era 200 — Savia Intelligence Layer
- **developer_type:** agent-team
- **status:** draft
- **stack:** Markdown (SKILL.md) + YAML frontmatter (agent)
- **estimacion:** 6h (3 slices)

## Problema

Savia tiene 136 skills y 81 agentes, pero ninguno sabe interactuar con SaviaVaults. Un agente que necesita buscar documentacion federada, crear una cupula de contexto, o gestionar confidencialidad no tiene instrucciones para hacerlo. Ademas, la gestion estrategica de cupulas de contexto — decidir que va en local vs federado, que nivel de confidencialidad, como estructurar el conocimiento — requiere un agente pesado con criterio.

## Objetivo

Dos artefactos complementarios:

1. **`savia-vaults` skill**: Instrucciones operativas para que cualquier agente Savia use el CLI `vaults` y la API de SaviaVaults. Tactico, no estrategico.

2. **`context-dome-manager` agent**: Agente heavy-model especializado en diseno, estrategia y gestion de cupulas de contexto. Estrategico, con criterio para decidir arquitectura de conocimiento.

## Artefacto 1: `savia-vaults` Skill

### Proposito
Enseñar a cualquier agente Savia a operar SaviaVaults: crear domes, buscar, federar, gestionar backups, confidencialidad.

### Triggers
- "crea una cupula de contexto", "indexa la documentacion", "busca en los vaults"
- "federate este dome", "backup del conocimiento", "nivel de confidencialidad"
- Mencion de `vaults` CLI o SaviaVaults

### Contenido
- Referencia rapida de comandos `vaults`
- Flujos de trabajo comunes (crear dome → indexar → servir → buscar)
- Integracion con MCP tools de SaviaVaults (9 tools)
- Gestion de federacion
- Gestion de backups y confidencialidad
- Anti-patrones (no borrar sin backup, no exponer N3/N4 sin token)

### Modelo
Fast — la skill es operativa, no requiere razonamiento profundo. El agente que la carga ya tiene el contexto de la tarea.

## Artefacto 2: `context-dome-manager` Agent

### Proposito
Agente estrategico de maximo nivel para disenar, auditar, y evolucionar la arquitectura de conocimiento de Savia via cupulas de contexto. Es el "architect del conocimiento".

### Responsabilidades

1. **Diseno de cupulas**: decidir estructura (INDEX.md, MAP.md, carpetas), granularidad de notas, frontmatter
2. **Estrategia de federacion**: que va local vs federado, pesos, politicas de cache
3. **Confidencialidad**: asignar niveles N1-N4, auditar fugas, recomendar cifrado
4. **Contexto como codigo**: tratar el conocimiento como codigo (git, PRs, review, CI)
5. **Codigo como contexto**: extraer conocimiento de codigo fuente a cupulas
6. **Digestion y clasificacion**: orquestar skills de digestion (pdf-digest, excel-digest, meeting-digest) para poblar cupulas
7. **Grafo de conocimiento**: integrar con `knowledge-graph` skill para enriquecer cupulas con relaciones
8. **Publicacion y elevacion**: decidir que conocimiento se promociona de N3→N2→N1, cuando publicar
9. **Auditoria de cupulas**: drift entre docs y codigo, conocimiento huerfano, bus factor
10. **Evolucion**: refactorizar estructura de cupulas, consolidar, archivar

### Modelo
**Heavy** — usa los LLM mas potentes disponibles (Opus-4-7 o equivalente). Las decisiones de arquitectura de conocimiento requieren razonamiento profundo, analisis de trade-offs, y vision estrategica.

### Tools permitidas
- `read`, `glob`, `grep`, `bash`, `write`, `edit`, `task`, `skill`
- Skills: `savia-vaults`, `knowledge-graph`, `context-dome`, `ubiquitous-language`, `bus-factor-analysis`
- Digestion: `pdf-digest`, `excel-digest`, `meeting-digest`, `word-digest`, `pptx-digest`
- `drift-auditor` agent (delegar auditorias)

### Contexto de trabajo
- Conoce SaviaVaults (SE-280-284)
- Conoce el sistema de memoria de Savia (memory-system.md)
- Conoce los niveles de confidencialidad N1-N4b
- Conoce el patron context-dome (SE-252)
- Conoce el knowledge graph (SE-162)
- Conoce ubiquitous language (SE-086)

### Criterio de decisiones

El agente debe aplicar criterio en:

| Decision | Criterio |
|---|---|
| ¿Local o federado? | Latencia (<5ms local vs <500ms federado), soberania, confidencialidad |
| ¿N1, N2, N3 o N4? | Modelo Savia: publico, interno, confidencial, restringido |
| ¿Estructura plana o jerarquica? | <50 notas → plana, >50 → jerarquica con INDEX/MAP |
| ¿Frontmatter obligatorio? | title, tags, created siempre; +status, +confidence, +domain segun nivel |
| ¿Cuando publicar (N3→N1)? | Gate: audit pass + 2 revisores + sin PII + 30 dias desde creacion |
| ¿Cuando archivar? | No accedido en 90 dias + sin referencias entrantes |
| ¿Backup schedule? | Diario incremental, semanal completo, mensual offsite |

## Implementacion

### Slice 1 — Skill SKILL.md (2h)
- `.opencode/skills/savia-vaults/SKILL.md`
- DOMAIN.md con contexto de dominio
- Referencia de comandos, workflows, anti-patrones

### Slice 2 — Agent definition (2h)
- `.opencode/agents/context-dome-manager.md`
- Frontmatter completo (model: heavy, tools, permission L2)
- Criterio de decisiones documentado
- Protocolo de interaccion con otros agentes

### Slice 3 — Registry updates + ROADMAP (2h)
- Actualizar AGENTS.md y SKILLS.md (regenerar)
- Añadir SE-285 al ROADMAP
- Verificar que el skill es detectable por skill-suggest (SE-276)

## Criterios de Aceptacion

**AC-1**: `savia-vaults` skill cargable por cualquier agente via `skill` tool.

**AC-2**: La skill contiene referencia completa de comandos `vaults` (30+ subcomandos).

**AC-3**: `context-dome-manager` agent usa model: heavy, permission L2.

**AC-4**: El agente describe criterio para 6 decisiones clave de arquitectura de conocimiento.

**AC-5**: Ambos artefactos aparecen en AGENTS.md y SKILLS.md regenerados.

**AC-6**: `skill-suggest.sh` sugiere `savia-vaults` ante prompts como "crea una cupula".

## Self-Review — Edge Cases

1. **Skill vs Agent confusion**: la skill es operativa (fast), el agente es estrategico (heavy). Documentado explicitamente.
2. **Solapamiento con context-dome skill existente**: `context-dome` skill (SE-252) es para generar CONTEXT_DOME.md. El nuevo agente es para gestionar cupulas completas. Complementarios.
3. **Solapamiento con architect agent**: architect disena arquitectura de codigo. context-dome-manager disena arquitectura de conocimiento. Diferentes dominios.
4. **Ciclo de vida del conocimiento**: cubierto con criterios de publicacion, archivado, y evolucion.
5. **Multi-idioma**: el agente opera en el idioma del perfil activo (ES/EN).
