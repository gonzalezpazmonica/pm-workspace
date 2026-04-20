---
id: SPEC-009
title: SPEC-009: Savia como participante en Teams
status: PROPOSED
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-009: Savia como participante en Teams

> Status: **DRAFT** · Fecha: 2026-03-21
> "Savia entra a la reunión de Teams como una persona más."

---

## Problema

ZeroClaw cubre reuniones presenciales, pero muchas reuniones son por
Teams. Savia necesita participar en ambas con el mismo protocolo de
etiqueta, los mismos roles y los mismos guardrails.

## Arquitectura: 2 canales, mismo cerebro

```
┌─────────────────────────────────────────────────┐
│              SAVIA (cerebro)                     │
│  Context Guardian + Speaker Roles + Etiquette    │
├────────────────────┬────────────────────────────┤
│ Canal FÍSICO       │ Canal TEAMS                 │
│ ZeroClaw ESP32     │ Graph API + Bot             │
│ Audio I2S → STT    │ Transcript API → texto      │
│ TTS → Altavoz      │ Chat API → mensaje          │
│ Voiceprints local  │ Speaker ID por Graph user   │
└────────────────────┴────────────────────────────┘
```

La diferencia clave: en Teams no necesitamos STT/TTS ni voiceprints.
Teams proporciona transcripción nativa con speaker identity via Graph.

## Capacidades de Teams que Savia usa

| Capacidad | API | Para qué |
|-----------|-----|---------|
| Transcripción en vivo | Graph callTranscript | Leer qué se dice |
| Speaker identity | Graph identitySet | Saber quién habla |
| Chat de reunión | Graph chatMessage | Responder consultas |
| Estado de reunión | Graph onlineMeeting | Saber cuándo empieza/termina |
| Presencia | Graph presence | Indicar que Savia está activa |

## Modos de participación en Teams

### Modo A: Bot en el chat (MVP, sin audio)

Savia se une al chat de la reunión de Teams (no al audio).
Lee transcripciones de Teams en tiempo real vía Graph API.
Responde en el chat cuando le preguntan o detecta ventana.

```
Teams meeting chat:
  Carlos: ¿Cuántos PBIs quedan bloqueados?
  Savia (bot): 2 items bloqueados: AB#1023 (3 días) y AB#1045 (1 día).
               El AB#1023 bloquea la feature de pagos.
```

Ventajas: no necesita audio, no necesita Azure ACS, funciona hoy.

### Modo B: Bot con audio (futuro)

Savia se une a la llamada de Teams como participante de audio.
Usa Azure Communication Services (ACS) para recibir/enviar audio.
Habla con voz sintetizada (Piper TTS) y escucha (Whisper STT).

Esto es Modo A + ZeroClaw voice pipeline pero por Teams.

## Implementación Modo A (MVP)

### 1. Cuenta de Savia en Azure AD

```
Nombre: Savia (PM Assistant)
Email: savia@{tenant}.onmicrosoft.com
Tipo: Service account o member (según tenant)
Licencia: Microsoft 365 Business Basic (para Teams)
```

### 2. Azure AD App Registration

```
App: pm-workspace-savia-bot
Permissions:
  - OnlineMeetings.Read.All (transcripts)
  - Chat.ReadWrite (post messages)
  - CallRecords.Read.All (meeting metadata)
  - User.Read.All (speaker identity)
Auth: Client credentials (service principal)
```

### 3. Flujo de una reunión

```
1. Savia detecta reunión en calendario
   (Graph API: events con isOnlineMeeting=true)

2. Al iniciar la reunión:
   → Se une al chat de la reunión
   → Publica: "Savia aquí. Escuchando y tomando notas. 📝"
   → Lee transcript en polling (cada 10s)

3. Durante la reunión:
   → Cada chunk de transcript pasa por:
     a. Context Guardian (contradictions, risks, actions)
     b. Speaker Roles (mapear Graph user → rol del proyecto)
     c. Meeting Participant (detectar si debe hablar)
   → Si le preguntan en el chat: responde en chat
   → Si detecta ventana + info crítica: posta en chat
     con prefijo "⚠️" para distinguir de respuestas normales

4. Al terminar:
   → Descarga transcript completo
   → Ejecuta meeting-digest agent
   → Publica resumen en el chat o canal del proyecto
   → Persiste digest en projects/{p}/
```

## Mapeo speaker → rol (sin voiceprints)

En Teams, los hablantes se identifican por su Azure AD identity.
Savia mapea `user.displayName` → `equipo.md` → rol → permisos.

```python
# Graph transcript incluye speaker identity:
# {"speaker": {"user": {"displayName": "Carlos García"}}}
# Savia busca "Carlos García" en equipo.md → developer → permisos
```

No necesita voiceprints. Teams ya resuelve la identidad.

## Protocolo de chat

### Savia responde consultas

```
@Savia ¿cuál es la velocity del sprint?
→ Savia: Sprint 2026-06: velocity 43 SP (avg 5 sprints: 41).
         2 items bloqueados. Burndown on track.
```

### Savia interviene proactivamente (solo si CRÍTICO)

```
⚠️ Savia: Atención — lo que se acaba de decidir sobre cambiar el
scope del módulo de pagos contradice la decisión del 15-mar
(decisión-log #47). ¿Queréis que detalle la contradicción?
```

### Post-reunión (automático)

```
📋 Resumen de reunión — Sprint Review 2026-06

Participantes: Carlos, María, Pedro, Ana
Duración: 45 min

Decisiones:
  1. Priorizar feature de exportación sobre dashboard
  2. Mover AB#1023 al siguiente sprint

Action items:
  - María: terminar API de exportación (jueves)
  - Carlos: review del PR#89 (mañana)

Riesgos detectados:
  - Auth service dependency no mencionada (impacta Sprint 7)

Preguntas sin responder:
  - ¿Quién se encarga del deploy a PRE?

📄 Detalle: projects/alpha/meetings/20260321-sprint-review.md
```

## Configuración

```
# En CLAUDE.local.md o projects/{p}/CLAUDE.md

TEAMS_APP_CLIENT_ID     = "..."
TEAMS_APP_CLIENT_SECRET_FILE = "$HOME/.azure/teams-bot-secret"
TEAMS_APP_TENANT_ID     = "..."
TEAMS_SAVIA_USER_ID     = "..."  # Object ID de la cuenta savia@
TEAMS_AUTO_JOIN          = true   # unirse automáticamente a meetings
TEAMS_PROACTIVE_CHAT     = true   # intervenir en chat si crítico
TEAMS_POST_DIGEST        = true   # publicar digest al terminar
```

## Seguridad

- Credenciales en `$HOME/.azure/` (gitignored, N2)
- NUNCA publicar datos N4b (evaluaciones, salary) en chat de Teams
- Speaker roles aplicados: el `filter_response()` filtra ANTES de
  publicar en chat, igual que antes de hablar por voz
- Transcripts de Teams clasificados N4 (datos de proyecto)
- Audit log de todas las intervenciones de Savia en Teams

## Fases

### Fase A — Transcript polling + digest post-meeting

- Graph API lee transcripts después de la reunión
- meeting-digest agent procesa
- Publica resumen en canal del proyecto

### Fase B — Chat bot activo durante reunión

- Se une al chat de la reunión
- Lee transcript en tiempo real (polling 10s)
- Responde consultas en chat
- Context guardian activo

### Fase C — Intervención proactiva en chat

- Detecta ventanas (pausa en transcript)
- Publica alertas críticas con ⚠️
- Mismo protocolo de etiqueta que ZeroClaw

### Fase D — Audio + pantalla compartida (ACS)

**Opciones investigadas:**

**Opción 1: Azure Communication Services (ACS) — RECOMENDADA**
- Se une a la reunión de Teams como participante con audio + video
- Puede ENVIAR audio (TTS → PCM → ACS) = Savia HABLA
- Puede ENVIAR screen share (video stream) = Savia COMPARTE PANTALLA
- No necesita licencia Teams (BYOI model)
- Precio: ~$0.004/min por participante
- SDK: Python via `azure-communication-calling` o web SDK
- Limitación: no puede iniciar recording/transcription

```
Savia (ACS) → se une a Teams meeting
  → Recibe audio de todos (escucha)
  → Envía audio TTS cuando habla
  → Envía screen share para mostrar informes
  → Lee transcripts via Graph API (complemento)
```

**Opción 2: Real-time Media Bot (Graph Comms)**
- Acceso raw a streams de audio/video frame por frame
- Requiere: Windows Server + .NET + GPU para video
- Microsoft recomienda NO usarlo para IA agents
- Demasiado complejo para nuestro caso

**Opción 3: Copilot Studio Agent (Microsoft)**
- Microsoft recomienda esto para IA en reuniones
- Pero es propietario y limitado a su ecosistema
- No encaja con Savia (queremos control total)

**Decisión: ACS (Opción 1)** — equilibrio entre capacidades y
complejidad. Savia se une como participante ACS, puede hablar
y compartir pantalla, sin infraestructura Windows ni GPUs.

### Screen sharing: cómo funciona

```
1. Savia genera informe (markdown → imagen/PDF)
2. Convierte a video stream (PIL → frames → ACS)
3. ACS envía como screen share en la reunión
4. Los participantes ven el informe en pantalla
5. Savia narra el informe por voz simultáneamente
```

Ejemplo: durante Sprint Review, alguien pregunta
"¿cómo va el burndown?". Savia genera el gráfico,
lo comparte en pantalla y narra los datos clave.
