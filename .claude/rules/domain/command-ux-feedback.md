# Regla: UX Feedback — Estándares de retroalimentación para comandos
# ── OBLIGATORIO para todos los comandos de pm-workspace ──────────────────────

## Principio fundamental

> El PM SIEMPRE debe saber qué está pasando. Ningún comando puede ejecutarse
> sin dar feedback visual en pantalla. El silencio es un bug.

## 1. Banner de inicio

Al comenzar CUALQUIER comando, mostrar inmediatamente:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /comando:nombre — Descripción breve
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Verificación de Prerequisitos

Comprobar requisitos. Si falta configuración → modo interactivo
(NO parar con error genérico). Pedir datos uno a uno, guardar, reintentar.

Detalles: **→ `command-ux-checklist.md`** (checklist, retry flow, ejemplos)

## 3. Progreso y Errores

**Progreso**: `📋 Paso 1/4 — Recopilando datos...` Si tarda, informar: `(esto puede tardar ~30s)...`

**Errores no-críticos**: `⚠️ Error en paso X — Causa — Acción sugerida — ¿Continuar?`

**Errores críticos**: `❌ Error crítico — Causa — Sugerencia`

Detalles: **→ `command-ux-checklist.md`**

## 4. Banner de Finalización

**Siempre mostrar** al terminar (éxito completo / parcial / error):
- Banner con status (✅/⚠️/❌)
- Ruta de fichero si se guardó
- Duración
- Sugerencia de siguiente paso si procede

Ejemplos completos: **→ `command-ux-checklist.md`**

## 5. Retry Automático

Fallo por configuración → Pedir dato → Guardar → Reintentar automáticamente.

## 6. Output-First

Resultado > 30 líneas → guardar en fichero, mostrar resumen en chat.
Ver `@context-health.md`

## 7. Anti-Improvisación

Un comando SOLO hace lo que su `.md` define explícitamente:
- **Solo acciones listadas** — no inventar comportamiento
- **Solo ficheros indicados** — respetar rutas exactas
- **Si no está cubierto** → error con sugerencia, NO improvisar

## 8. Auto-Compact Post-Comando (OBLIGATORIO)

TRAS CADA slash command → incluir en banner:
```
⚡ /compact — Ejecuta para liberar contexto antes del siguiente comando
```

**Si PM pide otro comando sin compactar:**
```
⚠️ Contexto alto — ejecuta `/compact` antes de continuar.
```

**Aplicación**: TODOS los comandos sin excepción.
