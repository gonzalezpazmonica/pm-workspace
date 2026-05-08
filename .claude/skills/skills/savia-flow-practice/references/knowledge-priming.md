# Knowledge Priming — Contexto para Agentes AI

> Basado en [Fowler: Knowledge Priming](https://martinfowler.com/articles/reduce-friction-ai/knowledge-priming.html). Los agentes AI son colaboradores capaces pero sin contexto. El priming llena ese vacío.

## Qué es

Manual RAG: cargar la ventana de contexto con información de alto valor del proyecto antes de pedir código/decisiones. Transforma respuestas genéricas en respuestas alineadas con el equipo.

## Las 7 secciones del documento de priming

| # | Sección | Qué incluir | Ejemplo SocialApp |
|---|---------|-------------|-------------------|
| 1 | Arquitectura | Tipo app, componentes, interacciones | Ionic + microservicios + API Gateway + RabbitMQ |
| 2 | Tech stack + versiones | Tecnologías con versión exacta | Node.js 20.x, MongoDB 7.x, Ionic 7.x |
| 3 | Fuentes de conocimiento | 5-10 refs curadas (docs, ADRs, runbooks) | OpenAPI spec, ADR-001 auth, ADR-002 messaging |
| 4 | Estructura proyecto | Directorios, dónde va cada cosa | `src/services/`, `src/shared/`, `ionic/src/` |
| 5 | Convenciones naming | Reglas explícitas de nombrado | Files: kebab-case, functions: camelCase, types: PascalCase |
| 6 | Ejemplos de código | 2-3 snippets reales del "buen código" | Auth middleware, RabbitMQ publisher, Ionic page |
| 7 | Anti-patterns | Qué NO hacer (lecciones aprendidas) | No callbacks anidados, no `any` en TypeScript |

## Cómo se almacena

El priming doc se versiona en el repo, dentro del proyecto:

```
projects/{nombre}/
├── CLAUDE.md              ← priming doc principal
├── .priming/
│   ├── architecture.md    ← sección 1-2 detallada
│   ├── conventions.md     ← secciones 5-7
│   └── examples/          ← snippets de código
```

## Integración con Savia Flow

| Comando | Usa priming para... |
|---------|---------------------|
| `/flow-spec` | Pre-rellenar Technical Design con stack + conventions |
| `/flow-intake` | Validar que la spec referencia las fuentes de conocimiento |
| `/flow-board` | Contextualizar items con arquitectura del proyecto |
| `/pbi-decompose` | Estimar tasks usando convenciones del equipo |

## 5 patrones Fowler adaptados a Savia

1. **Knowledge Priming** → `CLAUDE.md` + `.priming/` por proyecto
2. **Design-First** → `/flow-spec` (capabilities → components → contracts → implementation)
3. **Sensible Defaults** → `pm-config.md` + `pm-workflow.md` (tacit knowledge codificado)
4. **Context Anchoring** → `session-save` + `memory-sync` (decisiones persistidas entre sesiones)
5. **Feedback Flywheel** → E2E test harness + métricas → mejora continua de prompts

## Mantenimiento

- Tech lead revisa trimestralmente
- Actualizar al cambiar framework, refactor mayor, o error recurrente de AI
- Máximo 3 páginas; referenciar docs externos para detalle
- Cada PR que modifique priming requiere review de alguien del equipo

## Jerarquía de conocimiento (prioridad)

1. **Priming docs** (máxima): contexto explícito del proyecto
2. **Conversación actual** (media): mensajes del hilo
3. **Training data** (mínima): patrones genéricos de internet

> Los transformers asignan más atención a tokens específicos del priming doc, desplazando los patrones genéricos del training.
