---
name: slack-search
description: >
  Buscar mensajes y decisiones en Slack como contexto para
  reglas de negocio, retrospectivas o análisis de proyecto.
---

# Buscar en Slack

**Búsqueda:** $ARGUMENTS

> Uso: `/slack-search {query} [--channel {canal}] [--from {usuario}] [--since {fecha}]`

## Parámetros

- `{query}` — Texto a buscar en mensajes de Slack
- `--channel {canal}` — Filtrar por canal específico
- `--from {usuario}` — Filtrar por autor del mensaje
- `--since {fecha}` — Mensajes desde esta fecha (formato: YYYY-MM-DD o "2 weeks ago")
- `--project {nombre}` — Buscar en el canal configurado del proyecto
- `--decisions` — Filtrar por mensajes que parezcan decisiones (contienen "decidimos", "aprobado", "acordamos")
- `--limit {n}` — Máximo de resultados (default: 10)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Messaging** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar tono y formalidad según `tone.formality` y `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. `docs/rules/domain/connectors-config.md` — Verificar que Slack está habilitado

## 4. Pasos de ejecución

1. **Verificar conector** — Comprobar que el conector Slack está disponible

2. **Construir búsqueda**:
   - Combinar query + filtros (canal, autor, fecha)
   - Si `--decisions` → ampliar query con términos de decisión
   - Si `--project` → resolver canal del proyecto

3. **Ejecutar búsqueda** via conector MCP de Slack

4. **Presentar resultados**:
   ```
   🔍 Resultados para "{query}" en {canal}

   1. @maria (2026-02-20 en #alpha-dev):
      "Decidimos usar PostgreSQL para el servicio de usuarios..."
      🔗 [Ver en Slack](link)

   2. @carlos (2026-02-18 en #alpha-dev):
      "Acordamos que el rate limit será 100 req/min..."
      🔗 [Ver en Slack](link)

   Encontrados: {N} mensajes
   ```

5. **Si `--decisions`** → ofrecer:
   ```
   ¿Quieres que añada estas decisiones a reglas-negocio.md del proyecto?
   ```

## Casos de uso en PM-Workspace

- **Input para `/diagram-import`**: Buscar decisiones arquitectónicas antes de importar
- **Input para `/pbi-decompose`**: Buscar contexto funcional sobre un PBI
- **Input para `/sprint-retro`**: Recopilar feedback del equipo durante el sprint
- **Auditoría**: Buscar quién aprobó qué y cuándo

## Restricciones

- Solo lectura — no modifica mensajes ni canales
- Respetar privacidad: no mostrar mensajes de canales privados sin acceso
- No almacenar mensajes de Slack en ficheros del repo
- Si no hay resultados → sugerir ampliar la búsqueda
