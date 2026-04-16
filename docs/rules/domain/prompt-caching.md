---
globs: ["CLAUDE.md"]
---
# Prompt Caching Strategy

Optimiza el costo de tokens de entrada ordenando contenido estable primero con breakpoints de caché.

## Cache-Eligible Content

Archivos a incluir en estrategia de caching:
- CLAUDE.md — Definición del proyecto
- reglas-negocio.md — Reglas de negocio
- equipo.md — Composición del equipo
- politica-estimacion.md — Políticas de estimación

## Caching Strategy: Static Prefix + Dynamic Suffix

**Static Prefix (Se cachea):**
- System prompt
- PM-Workspace CLAUDE.md (reglas globales)
- Project context (CLAUDE.md + reglas-negocio + equipo)

**Dynamic Suffix (No se cachea):**
- User request
- Conversation history

## 4-Level Content Ordering

### Level 1: PM-Workspace Foundation (muy estable - ~5min TTL)
System prompt → PM-Workspace CLAUDE.md → Global rules → [CACHE BREAKPOINT]

### Level 2: Project Context (estable - ~5min TTL)
Project CLAUDE.md → reglas-negocio.md → equipo.md → [CACHE BREAKPOINT]

### Level 3: Task & Skill Content (moderadamente estable - ~5min TTL)
Skill CLAUDE.md → task-specific rules → templates → [CACHE BREAKPOINT]

### Level 4: Dynamic User Input (nunca se cachea)
User request → conversation history

## Cost Optimization

Anthropic ofrece 90% descuento en tokens cacheados:
- Token normal: 1 costo
- Token cacheado: 0.1 costo

**Estimación**: Con 5K tokens de context estable, 10 turnos:
- Sin caché: 50K tokens = 50 créditos
- Con caché: 5K + (45K × 0.1) = 9.5 créditos
- **Ahorro: 81%**

## TTL Guidance

Cache válido: 5min (Anthropic default). Optimizar para:
- Sequential operations dentro misma sesión
- Same-project context loading
- Skill-specific task batches

## Implementation Checklist

- [ ] Load Level 1 primero (PM globals)
- [ ] Load Level 2 segundo (Project context)
- [ ] Load Level 3 tercero (Skill content)
- [ ] Load Level 4 último (User request)
- [ ] Coloca cache_control entre Levels
- [ ] Monitor cache hit rates vía API responses
