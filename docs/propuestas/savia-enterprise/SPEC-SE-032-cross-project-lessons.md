---
status: PROPOSED
---

# SPEC-SE-032: Cross-Project Lessons Pipeline

> **Estado**: Draft — Roadmap
> **Prioridad**: P2 (Productividad)
> **Dependencias**: agent-memory-isolation.md (existente), self-improvement.md
> **Era**: 231
> **Inspiración**: synthesis-console `_lessons/YYYY-MM-DD-slug.md`

---

## Problema

pm-workspace tiene `tasks/lessons.md` como registro de lecciones, pero
es per-workspace (no per-proyecto) y no tiene mecanismo de cross-pollination.
Cuando un agente resuelve un problema en el proyecto A, esa solución no
llega automáticamente al proyecto B.

synthesis-console resuelve esto con ficheros `_lessons/` date-sorted que
son consultables desde cualquier proyecto antes de escalar.

## Solución

Pipeline de 3 fases: extracción de lecciones post-tarea, catalogación
cross-project, y consulta automática pre-escalación.

## Diseño

### Almacenamiento

```
output/lessons/
├── YYYY-MM-DD-slug.md        ← lecciones extraídas
├── index.jsonl                ← índice searchable
└── archive/                   ← >90 días
```

Cada lección:
```markdown
---
date: 2026-04-12
slug: retry-logic-timeout
projects: [proyecto-alpha, sala-reservas]
agents: [dotnet-developer, architect]
domain: error-handling
confidence: 80
---

## Problema
El timeout de 30s en HttpClient causaba cascading failures.

## Solución
Implementar retry con exponential backoff + circuit breaker.

## Aplicabilidad
Cualquier proyecto con llamadas HTTP a servicios externos.
```

### Pipeline

1. **Extracción** (post-tarea): cuando un agente resuelve un bloqueante,
   el orquestador extrae la lección con `scripts/lesson-extract.sh`
2. **Catalogación**: la lección se indexa en `index.jsonl` con tags de
   dominio, proyectos, agentes, y keywords
3. **Consulta** (pre-escalación): antes de escalar al humano, buscar
   en lessons si hay solución conocida

### Consulta automática

Integración con `nl-command-resolution.md`:
- Si el agente encuentra un error → buscar en lessons antes de retry
- Si hay match con confianza >70% → aplicar solución del lesson
- Si no hay match → escalar normalmente y extraer lesson post-resolución

## Privacidad

- Lessons en `output/lessons/` (N1 si son genéricos)
- Si contienen datos de proyecto → mover a `projects/{p}/lessons/` (N4)
- Cross-project lessons SOLO con datos genéricos (nunca nombres de cliente)
- `_sanitize_pii()` obligatorio antes de escribir

## Comandos

| Comando | Descripción |
|---------|-------------|
| `/lesson-extract` | Extraer lección de la tarea actual |
| `/lesson-search` | Buscar lecciones por dominio/keyword |
| `/lesson-stats` | Estadísticas de lecciones por proyecto |

## Tests (mínimo 6)

1. Script existe y es ejecutable
2. Extracción genera fichero con frontmatter válido
3. Búsqueda encuentra lección por dominio
4. PII se sanitiza antes de escribir
5. Index se actualiza tras extracción
6. Stats reporta correctamente
