---
name: notify-slack
description: >
  Enviar notificación o informe al canal de Slack del proyecto.
  Soporta texto libre, resultados de otros comandos y formateo Slack.
---

# Notificar en Slack

**Argumentos:** $ARGUMENTS

> Uso: `/notify-slack {canal} {mensaje}` o `/notify-slack --project {p} {mensaje}`

## Parámetros

- `{canal}` — Canal de Slack (ej: `#proyecto-alpha-dev`). Si empieza con `@`, envía DM
- `--project {nombre}` — Usa el canal configurado en `projects/{p}/CLAUDE.md` (campo `SLACK_CHANNEL`)
- `--thread {ts}` — Responder en un hilo existente (timestamp del mensaje padre)
- `{mensaje}` — Texto a enviar. Soporta formato Slack (markdown, mentions, emojis)

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Messaging** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar tono y formalidad según `tone.formality` y `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. `.claude/rules/connectors-config.md` — Verificar que Slack está habilitado
2. `projects/{proyecto}/CLAUDE.md` — Canal del proyecto (si se usa `--project`)

## 4. Pasos de ejecución

1. **Verificar conector** — Comprobar que el conector Slack está disponible
   - Si no está activado → mostrar instrucciones de activación

2. **Resolver canal**:
   - Si se pasa `{canal}` explícito → usar ese canal
   - Si se usa `--project` → buscar `SLACK_CHANNEL` en el CLAUDE.md del proyecto
   - Si ninguno → usar `SLACK_DEFAULT_CHANNEL` de connectors-config
   - Si ninguno configurado → pedir al usuario que especifique canal

3. **Formatear mensaje** para Slack:
   - Convertir tablas markdown a formato Slack (bloques de código)
   - Respetar emojis y menciones (@usuario, @here, @channel)
   - Si el mensaje es muy largo (>4000 chars) → dividir en múltiples mensajes
   - Añadir pie: `_Enviado desde PM-Workspace_`

4. **Enviar mensaje** usando el conector MCP de Slack
   - Si `--thread` → responder en hilo
   - Si no → mensaje nuevo en el canal

5. **Confirmar envío**:
   ```
   ✅ Mensaje enviado a {canal}
   ```

## Uso desde otros comandos (flag --notify-slack)

Otros comandos de PM-Workspace pueden usar el flag `--notify-slack` para publicar
su resultado automáticamente. Cuando un comando incluye este flag:

1. Ejecutar el comando normalmente
2. Tomar el resumen/resultado principal
3. Formatearlo para Slack (compacto, sin tablas complejas)
4. Enviarlo al canal del proyecto
5. Mostrar confirmación

Comandos que soportan `--notify-slack`:
- `/sprint-status` → Publica resumen de estado del sprint
- `/sprint-review` → Publica items completados y velocity
- `/board-flow` → Publica alertas de WIP y cuellos de botella
- `/team-workload` → Publica distribución de carga
- `/kpi-dashboard` → Publica KPIs principales
- `/pbi-decompose` → Notifica asignaciones de tasks
- `/diagram-status` → Publica estado de diagramas

## Ejemplos

```
/notify-slack #dev-team Sprint 14 completado: 34 SP, velocity 32 📈
/notify-slack --project ProyectoAlpha ⚠️ WIP limit superado en columna "In Progress"
/notify-slack @maria.garcia Tu task #1234 ha sido asignada (4h estimadas)
```

## Restricciones

- **SIEMPRE confirmar antes de enviar** si el mensaje contiene @channel o @here
- No enviar mensajes vacíos
- No enviar secrets, tokens o datos sensibles
- Máximo 10 mensajes por ejecución de comando (protección contra spam)
- Si el canal no existe → informar al usuario, no crear canal
