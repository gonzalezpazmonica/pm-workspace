---
name: context-tracking
description: Protocolo de tracking de uso de contexto para optimización del context-map
auto_load: false
paths: []
---

# Context Tracking Protocol

> 🦉 Medir para mejorar. Savia registra qué contexto usa y aprende a ser más eficiente.

---

## Qué se registra

Cada vez que un comando carga fragmentos de perfil:

| Campo | Descripción | Ejemplo |
|---|---|---|
| timestamp | UTC ISO 8601 | `2026-03-01T09:15:00Z` |
| command | Comando ejecutado | `sprint-status` |
| fragments | Fragmentos cargados (CSV) | `identity.md,workflow.md,projects.md,tone.md` |
| tokens_est | Tokens estimados | `270` |

## Qué NO se registra

- Contenido de los ficheros cargados
- Datos del usuario (nombre, proyectos, preferencias)
- Output de los comandos
- Conversación o prompts

## Almacenamiento

- Fichero: `$HOME/.pm-workspace/context-usage.log`
- Formato: pipe-delimited (timestamp|command|fragments|tokens_est)
- Tamaño máximo: 1MB (~5000 entradas)
- Rotación automática: tail de últimas 5000 entradas si supera 1MB
- Backup antes de reset

## Estimación de tokens

Tokens estimados por fragmento de perfil:

| Fragmento | Tokens aprox. |
|---|---|
| identity.md | ~50 |
| workflow.md | ~80 |
| tools.md | ~60 |
| projects.md | ~100 |
| preferences.md | ~70 |
| tone.md | ~40 |

Total perfil completo: ~400 tokens.
Carga típica (3-4 fragmentos): ~200-270 tokens.

## Métricas de optimización

1. **Token efficiency**: tokens_total / comandos_ejecutados
2. **Fragment utilization**: veces_cargado / veces_disponible por fragmento
3. **Co-occurrence index**: pares de comandos con gap <5 min
4. **Waste ratio**: fragmentos cargados pero no referenciados en output

## Integración con session-init

El hook `session-init.sh` puede registrar automáticamente el contexto
base cargado al inicio de sesión, usando:

```bash
bash scripts/context-tracker.sh log "session-init" "identity.md" "50"
```

## Comando de análisis

`/context-optimize` lee el log y genera recomendaciones.
Ver `.opencode/commands/context-optimize.md` para el flujo completo.

---

## Privacidad

- El log es local (nunca se sube, nunca se comparte)
- El log NO se incluye en backups (es datos de uso, no datos de usuario)
- El usuario puede borrar el log en cualquier momento con `/context-optimize reset`
- El tracking es opt-in: solo funciona si el log existe
