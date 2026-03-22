---
name: skill-auto-activation
description: Regla para activación inteligente de skills basada en contexto
---

# Skill Auto-Activation Protocol

## Cuándo se aplica

Cada vez que el usuario inicia una interacción que podría beneficiarse de un skill especializado.

## Paso 0 — Context Gate (fast-path) [SPEC-015]

ANTES de evaluar skills, verificar si el prompt es trivialmente clasificable.
Si cumple CUALQUIERA de estas condiciones → NO evaluar skills, responder directamente:

1. **Slash command**: prompt empieza con `/` → el comando ya es explícito
2. **Confirmación simple**: prompt es sí/no/ok/vale/claro/cancelar/hecho/listo
3. **Saludo o despedida**: hola/adiós/gracias/buenos días/hasta luego
4. **Corrección directa**: "no eso no", "cambia X por Y", "para", "deshaz"
5. **Prompt ultra-corto**: <= 4 palabras sin sustantivos técnicos (sprint, spec, pipeline, deploy, etc.)
6. **Respuesta a pregunta de Savia**: el turno anterior de Savia terminó con `?`

Si NINGUNA condición aplica → continuar con el Protocolo de scoring (Paso 1+).

## Progressive Loading L0/L1/L2 [SPEC-012]

| Nivel | Contenido | Tokens | Cuando |
|-------|-----------|--------|--------|
| L0 | name + description (frontmatter) | ~10-15 | Siempre disponible en catalogo |
| L1 | summary (3-5 lineas en frontmatter) | ~40-60 | Al identificar skill relevante (scoring) |
| L2 | SKILL.md completo + references | ~100-500 | Solo durante ejecucion del skill |

Flujo: L0 para scoring → L1 si score >=70% (decision) → L2 solo al ejecutar.
Tras ejecucion: descartar L2, mantener L1 en contexto.

## Protocolo

1. **Detección**: Al recibir un prompt, evaluar contra L0 (name+description). Si score >70%, cargar L1 (summary)
2. **Sugerencia**: Si se detecta match, informar al usuario: "Skill `{nombre}` podría ayudar aquí. ¿Lo activo?"
3. **Confirmación**: NUNCA activar sin confirmación explícita del usuario
4. **Registro**: Registrar cada activación y su resultado en `.claude/skills/eval-registry.json`
5. **Aprendizaje**: Si el usuario rechaza la sugerencia 3 veces consecutivas para el mismo skill+contexto, dejar de sugerir

## Scoring

### Base scoring (40%)
- `keyword_match`: 20% — palabras clave del prompt vs. tags del skill
- `category_match`: 20% — categoría del skill vs. tipo de tarea detectado

### Context scoring (30%)
- `project_context`: 15% — tipo de proyecto y ficheros presentes
- `category_affinity`: 15% — si la categoría del skill coincide con el capability group activo (tool-discovery.md)

### History scoring (30%)
- `history_boost`: 15% — activaciones previas exitosas del skill
- `priority_boost`: 15% — skills con `priority: "high"` reciben +5% base

### Threshold: 70% mínimo para sugerir

## Categorías de Skills

Las 7 categorías (definidas en frontmatter `category:` de cada SKILL.md):

| Categoría | Contexto de activación |
|---|---|
| `pm-operations` | Sprint, capacity, backlog, planning |
| `sdd-framework` | Specs, implementación, dev sessions |
| `governance` | Compliance, security, validation |
| `devops` | Pipelines, deploy, diagrams, repos |
| `reporting` | Informes, métricas, exports |
| `communication` | Mensajería, voice, notificaciones |
| `quality` | Performance, testing, DX, audits |

## Restricciones

- No sugerir más de 2 skills por interacción
- No sugerir skills durante `/focus-mode` activo
- Respetar feedback negativo del usuario (tune -)
- Los skills de seguridad (security-guardian, pii-gate) siempre tienen prioridad
- Skills con `priority: "low"` solo se sugieren si score > 85%
