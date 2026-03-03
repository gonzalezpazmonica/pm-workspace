# Era 20 — Persistent Intelligence & Adaptive Workflows

**Fecha:** 2026-03-03
**Fuente principal:** [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice) (6.647 estrellas, 567 forks)
**Fuente secundaria:** Auditoría interna de pm-workspace vs mejores prácticas documentadas
**Informe completo:** `output/synergy-report-best-practices.md`

---

## Contexto

claude-code-best-practice es el repositorio de referencia de la comunidad para patrones avanzados de Claude Code. Documenta con implementaciones funcionales: hooks (16 tipos de evento), agent memory (3 scopes), skills avanzados, MCPs recomendados, workflow RPI (Research → Plan → Implement), y optimizaciones de contexto.

La auditoría cruzada con pm-workspace reveló que nuestra base es muy sólida (274 comandos, 24 agentes, 21 skills, 74 reglas, 13 hooks) pero nos faltan piezas clave para el salto de "herramienta potente" a "herramienta que aprende".

---

## Análisis de gaps

### GAP 1: Agent Memory (CRÍTICO)

**Estado actual:** pm-workspace no tiene sistema de memoria persistente entre sesiones para agentes.

**Referencia best-practice:** Tres scopes documentados con implementaciones funcionales:
- `memory: user` → `~/.claude/agent-memory/<nombre>/` — privada, cross-project
- `memory: project` → `.claude/agent-memory/<nombre>/` — compartida, versionada en git
- `memory: local` → `.claude/agent-memory-local/<nombre>/` — personal, git-ignored

**Impacto:** Los agentes pierden todo el contexto al cerrar sesión. El architect no recuerda decisiones de diseño previas. El security-guardian no acumula patrones de vulnerabilidades detectadas. El commit-guardian no aprende convenciones del proyecto.

**Solución propuesta (v0.91.0 + v0.92.0):**
1. Crear estructura de directorios `.claude/agent-memory/` con MEMORY.md por agente
2. Añadir `memory: project` al frontmatter de 8 agentes core
3. Extender a Savia con memoria contextual propia (decisiones, vocabulario, preferencias)
4. Integrar con AEPD compliance para data minimization en memoria de agentes

**Esfuerzo:** Medio | **Valor:** Alto

---

### GAP 2: Frontmatter avanzado en comandos (IMPORTANTE)

**Estado actual:** 274 comandos con frontmatter básico (`name`, `description`).

**Referencia best-practice:** Campos adicionales documentados:
- `argument-hint: [hint-text]` — muestra sintaxis en autocompletado
- `allowed-tools: Read, Edit, Bash(npm run *)` — restringe herramientas (menos prompts de permisos)
- `model: haiku|sonnet|opus` — override de modelo por comando

**Impacto:** Comandos ligeros como `/help` o `/sprint-status` consumen modelo opus innecesariamente. Los prompts de permisos interrumpen workflows repetitivos.

**Solución propuesta (v0.93.0):**
1. Definir taxonomía de comandos: lightweight (haiku), standard (sonnet), complex (opus)
2. Añadir campos a comandos de alto tráfico primero (help, sprint-status, backlog, daily, flow-metrics)
3. Actualizar validate-commands.sh para validar nuevos campos
4. Documentar convención en CLAUDE.md

**Esfuerzo:** Bajo | **Valor:** Medio

---

### GAP 3: Workflow RPI formal (IMPORTANTE)

**Estado actual:** pm-workspace tiene los skills separados (product-discovery, pbi-decomposition, spec-driven-development) pero no un workflow que los conecte con gates de validación.

**Referencia best-practice:** Patrón RPI (Research → Plan → Implement) con:
- Estructura de carpetas por feature
- Puertas GO/NO-GO entre fases
- Agentes especializados por fase
- Documentación de progreso por fase

**Impacto:** Sin gates formales, se salta de idea a implementación sin validación. Los skills existen pero se usan de forma aislada.

**Solución propuesta (v0.94.0):**
1. Crear comando `/rpi-start` que orqueste el flujo completo
2. Mapear skills existentes a fases RPI
3. Implementar gates de validación (GO/NO-GO) entre fases
4. Crear `/rpi-status` para tracking de progreso

**Esfuerzo:** Medio | **Valor:** Alto

---

### GAP 4: Output adaptativo (DESEABLE)

**Estado actual:** Savia tiene tono definido pero uniforme para todas las audiencias.

**Referencia best-practice:** Estilos de output documentados: "Explanatory" (aprendizaje), "Learning" (coaching).

**Solución propuesta (v0.95.0):**
1. Tres modos: Coaching (juniors), Executive (stakeholders), Technical (seniors)
2. Auto-detección por contexto y perfil de usuario
3. Workflow de onboarding guiado para nuevos miembros del equipo

**Esfuerzo:** Medio | **Valor:** Medio

---

### GAP 5: MCPs y hooks async (INCREMENTAL)

**Estado actual:** MCP config vacía (correcto: lazy loading). Solo 2/13 hooks son async.

**Referencia best-practice:** MCPs recomendados (Context7, Excalidraw, DeepWiki). Hooks async para observabilidad.

**Solución propuesta (v0.96.0):**
1. Comando `/mcp-recommend` con sugerencias contextuales
2. Expandir `async: true` en hooks de logging
3. Configurar `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50`

**Esfuerzo:** Bajo | **Valor:** Bajo-Medio

---

## Roadmap de implementación

| Versión | Milestone | Prioridad | Dependencias |
|---|---|---|---|
| v0.91.0 | Agent Memory Foundation | P0 | Ninguna |
| v0.92.0 | Savia Contextual Memory | P0 | v0.91.0 |
| v0.93.0 | Smart Command Frontmatter | P1 | Ninguna |
| v0.94.0 | RPI Workflow Engine | P1 | v0.91.0 (agent memory para tracking) |
| v0.95.0 | Adaptive Output & Onboarding | P2 | v0.92.0 (Savia memory) |
| v0.96.0 | MCP Toolkit & Async Hooks | P2 | Ninguna |

**Ruta crítica:** v0.91.0 → v0.92.0 → v0.95.0 (cadena de memoria)
**Ruta paralela:** v0.93.0 y v0.96.0 pueden desarrollarse en paralelo con la ruta crítica

---

## Métricas de éxito

- Agent Memory: ≥8 agentes con `memory: project` activo
- Frontmatter: ≥50 comandos con campos avanzados en primera iteración
- RPI: ≥1 feature completada con flujo RPI end-to-end
- Onboarding: Tiempo de onboarding reducido de ~2 días a ~4 horas para nuevo dev
- Hooks async: ≥80% de hooks de observabilidad marcados como async
- Auto-compact: Threshold configurado y documentado

---

## Reconocimiento

Esta era está directamente inspirada por el trabajo de [Shan Ur Rehman](https://github.com/shanraisshan) en claude-code-best-practice. Se añadirá reconocimiento en README.md cuando se libere v0.91.0.
