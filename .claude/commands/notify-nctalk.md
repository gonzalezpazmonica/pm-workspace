---
name: notify-nctalk
description: >
  Enviar notificaciones e informes a una sala de Nextcloud Talk.
  Funciona con cualquier instancia Nextcloud (self-hosted o cloud).
---

# Notify Nextcloud Talk

**Argumentos:** $ARGUMENTS

> Uso: `/notify-nctalk {sala} {mensaje}` o `/notify-nctalk --team {msg}`

## Parámetros

- `{sala}` — Nombre o token de la sala de Nextcloud Talk
- `{mensaje}` — Texto a enviar
- `--team` — Enviar a la sala del equipo configurada en `messaging-config.md`
- `--pm` — Enviar a la sala privada del PM
- `--file {ruta}` — Adjuntar fichero (compartir via Nextcloud Files)
- `--project {nombre}` — Contexto de proyecto
- `--silent` — Enviar sin notificación push a los participantes

## 2. Cargar perfil de usuario

1. Leer `.claude/profiles/active-user.md` → obtener `active_slug`
2. Si hay perfil activo, cargar (grupo **Messaging** del context-map):
   - `profiles/users/{slug}/identity.md`
   - `profiles/users/{slug}/preferences.md`
   - `profiles/users/{slug}/tone.md`
3. Adaptar tono y formalidad según `tone.formality` y `preferences.language`
4. Si no hay perfil → continuar con comportamiento por defecto

## 3. Contexto requerido

1. @.claude/rules/domain/messaging-config.md — Config Nextcloud Talk (URL, token, salas)
2. Acceso a la API REST de Nextcloud Talk

## 4. Pasos de ejecución

### 1. Verificar conexión
- Comprobar `NCTALK_ENABLED = true`
- Verificar acceso: `GET /ocs/v2.php/apps/spreed/api/v4/room` con token de app
- Si falla → indicar al PM cómo generar token de app

### 2. Resolver sala
- Si `--team` → usar `NCTALK_ROOM_TEAM` de config
- Si `--pm` → usar `NCTALK_ROOM_PM` de config
- Si nombre → buscar sala por displayName en lista de rooms

### 3. Preparar mensaje
- Formatear para Nextcloud Talk (soporta markdown completo)
- Si `--file` → subir a Nextcloud Files primero, luego compartir enlace

### 4. Enviar
- `POST /ocs/v2.php/apps/spreed/api/v4/chat/{token}`
- Body: `{ "message": "{texto}", "silent": false }`
- **Confirmar con PM antes de enviar**

### 5. Confirmar envío

```
✅ Mensaje enviado a Nextcloud Talk
Sala: "Equipo Sala Reservas" (5 participantes)
Contenido: Resumen sprint 2026-04 (512 chars)
Adjunto: sprint-report.pdf (compartido via Nextcloud Files)
```

## Ejemplos

```bash
/notify-nctalk --team "Sprint review mañana a las 10:00"
/notify-nctalk "pm-notifications" "Alerta: 2 CVEs críticos detectados"
/notify-nctalk --team --file output/reports/sprint-report.pdf
/notify-nctalk --team --silent  # envía último informe sin notificar
```

## Restricciones

- NUNCA enviar sin confirmación del PM
- Requiere Nextcloud Talk v17+ (API v4) con capability `spreed`
- Ficheros adjuntos requieren acceso a Nextcloud Files (misma cuenta)
