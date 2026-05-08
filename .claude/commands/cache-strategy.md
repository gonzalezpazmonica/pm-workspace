---
name: cache-strategy
description: Configurar estrategia de caché por capas con TTL y reglas de invalidación
developer_type: all
agent: none
context_cost: high
---

# /cache-strategy

> 🦉 Savia configura el caché en capas — herramientas, instrucciones, RAG, conversación.

---

## Cargar perfil de usuario

Grupo: **Context Engineering** — cargar:

- `workflow.md` — preferencias de optimización

Ver `docs/rules/domain/context-map.md`.

---

## Parámetros

```
--show              Ver configuración actual del caché
--configure         Modo interactivo de configuración
--lang es|en        Idioma del output
```

---

## Flujo

### Paso 1 — Verificar configuración existente

1. Leer `$HOME/.pm-workspace/cache-config.json` si existe
2. Si no existe → informar que no hay configuración
3. Mostrar 4 capas de caché:
   - **Tools** (herramientas MCP, scripts)
   - **System** (instrucciones de Claude, reglas @)
   - **RAG** (knowledge base, documentación)
   - **Conversation** (contexto de sesión actual)

### Paso 2 — Mostrar estrategia actual (--show)

```
🗂️ Cache Strategy — Configuración Actual

Layer: TOOLS
├─ TTL: 7 días (604800 seg)
├─ Size: ~25% del presupuesto
└─ Invalidation: cambios en docs/rules/

Layer: SYSTEM
├─ TTL: 30 días
├─ Size: ~35%
└─ Invalidation: cambios en CLAUDE.md

Layer: RAG
├─ TTL: 14 días
├─ Size: ~20%
└─ Invalidation: cambios en docs/

Layer: CONVERSATION
├─ TTL: 1 sesión (8 horas)
├─ Size: ~20%
└─ Invalidation: /compact o timeout
```

### Paso 3 — Configuración interactiva (--configure)

Pedir por cada capa:

1. ¿Habilitar? (sí/no)
2. TTL (días)
3. Tamaño máximo (% del presupuesto)
4. Regla de invalidación (manual/auto/never)
5. Warm-up trigger (opcional)

Guardar en `$HOME/.pm-workspace/cache-config.json`.

### Paso 4 — Mostrar beneficios

```
📊 Estimación de Ahorros

Cache hit rate esperado: 65-75%
Reducción de tokens: 60-90%
Latencia mejorada: 2-3x más rápido
Cost savings: hasta 90% en sesiones largas
```

### Paso 5 — Generar fichero de referencia

Guardar en `output/cache-strategy-{YYYYMMDD}.md`:
- Configuración aplicada
- TTL por capa
- Reglas de invalidación
- Warm-up triggers
- Comandos para monitorizar (`/cache-analytics`)

---

## Validación

- ✅ Suma de tamaños ≤ 100%
- ✅ TTL Tools < TTL System < TTL RAG
- ✅ al menos 1 capa habilitada
- ✅ configuración guardada en JSON válido

---

## Restricciones

- Solo lectura de config existente — no modificar sin `--configure`
- NUNCA desabilitar Conversation layer sin confirmación
- Tools layer debe ser ≥25% para que herramientas tengan hit rate

