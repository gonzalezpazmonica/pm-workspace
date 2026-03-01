---
name: whatsapp-search
description: >
  Buscar mensajes en WhatsApp como contexto para decisiones.
  Acuerdos, conversaciones, decisiones del equipo.
---

# WhatsApp Search

**Argumentos:** $ARGUMENTS

> Uso: `/whatsapp-search {query}` o `/whatsapp-search --chat {nombre} {query}`

## Parámetros

- `{query}` — Texto a buscar en los mensajes
- `--chat {nombre}` — Buscar solo en un chat específico (contacto o grupo)
- `--since {fecha}` — Desde cuándo buscar (YYYY-MM-DD, defecto: 30 días)
- `--limit {n}` — Máximo de resultados (defecto: 20)
- `--media` — Incluir mensajes con media (audios, imágenes)
- `--context {n}` — Mensajes de contexto antes/después (defecto: 2)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Messaging** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar tono y formalidad según `tone.formality` y `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. @.claude/rules/domain/messaging-config.md — Config WhatsApp
2. MCP WhatsApp configurado y sesión activa

## 4. Pasos de ejecución

### 1. Verificar conexión
- Comprobar `WHATSAPP_ENABLED = true` y sesión activa

### 2. Buscar mensajes
- MCP: `list_chats` → obtener chats disponibles
- Si `--chat` → filtrar por nombre de chat
- MCP: `list_messages` con filtros temporales
- Filtrar por query en contenido del mensaje

### 3. Presentar resultados

```
## WhatsApp Search — "{query}"
Resultados: 5 mensajes en 2 chats (últimos 30 días)

### Grupo "Equipo Sala Reservas"
[2026-02-25 10:15] Ana García:
  "Hemos decidido usar Redis para la caché del dashboard"
  → contexto: discusión sobre performance del sprint review

[2026-02-26 14:30] Pedro López:
  "El cliente confirmó que la fecha límite es el 15 de marzo"
  → contexto: reunión con stakeholder

### Chat "Ana García"
[2026-02-27 09:00] Ana García:
  "Te reenvío el email del cliente con los nuevos requisitos"
  → adjunto: requisitos-v2.pdf
```

### 4. Ofrecer acciones
- "¿Quieres que cree un PBI a partir de esta decisión?"
- "¿Quieres que añada esto como nota al sprint?"

## Ejemplos

```bash
/whatsapp-search "fecha límite"
/whatsapp-search --chat "Equipo Sala Reservas" "decisión"
/whatsapp-search --since 2026-02-01 "requisitos" --media
```

## Restricciones

- Solo lectura — no modifica ni borra mensajes
- Los datos están en SQLite local (nunca se envían a terceros)
- Mensajes de otros chats no relacionados con el proyecto → excluir
