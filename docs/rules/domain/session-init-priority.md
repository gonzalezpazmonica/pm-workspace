---
name: session-init-priority
description: Sistema de prioridades para compresión del session-init hook
auto_load: false
paths: []
---

# Session-Init Priority System

> 🦉 Menos tokens al arrancar = más espacio para trabajar.

---

## Budget

- **Máximo**: ~300 tokens de additionalContext
- **Máximo items**: 8 líneas en output
- Si hay más items que espacio → se eliminan por prioridad baja

## Niveles de prioridad

### Crítica (siempre presente)

| Item | Tokens aprox. | Motivo |
|---|---|---|
| PAT status | ~10 | Sin PAT no funciona Azure DevOps |
| Perfil activo | ~15 | Determina modo humano/agente |
| Rama git | ~8 | Contexto de trabajo |

### Alta (si aplica)

| Item | Tokens aprox. | Condición |
|---|---|---|
| Actualización disponible | ~20 | Solo si hay nueva versión |
| Herramientas faltantes | ~15 | Solo si falta az/gh/jq |

### Media (condicional)

| Item | Tokens aprox. | Condición |
|---|---|---|
| Backup reminder | ~12 | Sin backup o >24h |
| Emergency plan | ~12 | No ejecutado nunca |
| Wellbeing context | ~25 | wellbeing configurado en workflow.md |

### Baja (probabilística)

| Item | Tokens aprox. | Condición |
|---|---|---|
| Community tip | ~15 | 1/20 sesiones, solo humanos |

## Reglas de corte

1. Críticos SIEMPRE entran (no negociable)
2. Altos entran si hay espacio tras críticos
3. Medios entran si hay espacio tras altos
4. Bajos solo si queda espacio (MAX_ITEMS - 1)
5. Si un nivel no cabe completo → entran los primeros del nivel

## Evolución

Nuevas features que necesiten sugerencia en session-init deben:

1. Definir su nivel de prioridad
2. Estimar tokens del mensaje
3. Añadirse al array correspondiente en `session-init.sh`
4. Documentar aquí su prioridad y condición
