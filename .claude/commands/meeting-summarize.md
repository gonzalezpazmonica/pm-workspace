---
name: meeting-summarize
description: Transcribe y extrae action items de reuniones — Sprint Review, Retro, Planning, Daily
developer_type: all
agent: task
context_cost: high
---

# /meeting-summarize

> 🦉 Savia convierte tus reuniones en acciones concretas.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, empresa
- `preferences.md` — language, detail_level, report_format
- `projects.md` — proyecto(s)
- `tone.md` — formality

---

## Subcomandos

- `/meeting-summarize {file}` — resumir desde fichero de audio/texto
- `/meeting-summarize --type daily` — formato optimizado para daily standup
- `/meeting-summarize --type review` — formato para Sprint Review
- `/meeting-summarize --type retro` — formato para Retrospectiva
- `/meeting-summarize --type planning` — formato para Sprint Planning

---

## Flujo

### Paso 1 — Procesar input

Si el input es audio (.mp3, .wav, .ogg, .m4a):
1. Transcribir con Faster-Whisper (local, sin APIs externas)
2. Detectar idioma automáticamente
3. Identificar hablantes si es posible (diarización básica)

Si el input es texto (.md, .txt) o notas pegadas:
1. Parsear directamente

### Paso 2 — Extraer información estructurada

Según el tipo de reunión:

**Daily standup:**
```
📋 Daily — {fecha}

  Participantes: {lista}

  {persona 1}:
    Ayer: {lo que hizo}
    Hoy: {lo que hará}
    Bloqueantes: {si los hay}

  {persona 2}: ...

  ⚠️ Bloqueantes detectados: {N}
  📌 Action items: {lista}
```

**Sprint Review / Planning / Retro:**
```
📋 {tipo} — Sprint {N} — {fecha}

  Participantes: {lista}
  Duración: {estimada}

  📝 Resumen: {3-5 frases}

  ✅ Decisiones tomadas:
    1. {decisión} — Responsable: {persona}
    2. {decisión} — Responsable: {persona}

  📌 Action Items:
    - [ ] {acción} — @{persona} — Deadline: {fecha}
    - [ ] {acción} — @{persona} — Deadline: {fecha}

  💡 Ideas/Propuestas mencionadas (sin compromiso):
    - {idea}
```

### Paso 3 — Generar action items rastreables

Para cada action item detectado:
1. Asignar responsable (si se mencionó)
2. Estimar deadline (si se mencionó, o siguiente daily por defecto)
3. Sugerir crear PBI/Task en Azure DevOps si es trabajo significativo

### Paso 4 — Guardar y distribuir

Guardar en: `output/meetings/YYYYMMDD-{tipo}-{proyecto}.md`

Sugerir: "¿Quieres que envíe el resumen por Slack/Teams?"

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: meeting_summarize
type: "sprint_review"
duration_minutes: 45
participants: 6
decisions: 3
action_items: 5
output_file: "output/meetings/20260302-review-sala-reservas.md"
```

---

## Restricciones

- **NUNCA** inventar lo que no se dijo — solo extraer de la transcripción
- **NUNCA** atribuir frases a personas sin certeza razonable
- **NUNCA** enviar resúmenes sin confirmación del PM
- Transcripción siempre local (Faster-Whisper) — no enviar audio a APIs externas
- Si la calidad del audio es baja → indicar secciones inciertas con [inaudible]
