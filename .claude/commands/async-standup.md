---
name: async-standup
description: Recogida asíncrona de standups — cada dev reporta cuando quiera, Savia compila
agent: task
context_cost: medium
---

# /async-standup

> 🦉 Standup asíncrono: cada dev reporta a su ritmo, Savia compila el reporte diario.

---

## Parámetros

- `--project {nombre}` — Proyecto de PM-Workspace (obligatorio)
- `--channel` — Canal WhatsApp/Slack/Talk para recolectar reports (si no especificado: usar STANDUP_CHANNEL)
- `--compile` — Compilar reports recolectados hasta ahora (defecto)
- `--start` — Iniciar período de recolección (envía mensaje recordatorio a equipo)
- `--deadline {HH:MM}` — Hora límite compilación (defecto: 15:00)
- `--list` — Listar reports pendientes y completados

---

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config del proyecto
2. `projects/{proyecto}/team.md` — Miembros del equipo y contactos
3. `.claude/rules/domain/messaging-config.md` — Canales de mensajería

---

## Pasos de ejecución

### Fase 1 — Iniciar recolección (--start)

1. Leer equipo de `team.md`
2. Enviar mensaje recordatorio a cada miembro por WhatsApp/Slack/Talk:
   ```
   🦉 Standup asíncrono de {proyecto} abierto hasta {deadline}.
   Reporta: ¿Ayer qué hiciste? ¿Hoy qué harás? ¿Bloqueantes?
   Responde con: /standup-report [tuNombre]
   ```
3. Iniciar período de escucha (modo inbox)
4. Mostrar confirmación

### Fase 2 — Recolectar reports

Escuchar mensajes en canal designado. Detectar patrones:
- Primer mensaje: identificar dev por nombre
- Estructura esperada: "ayer: X | hoy: Y | bloqueantes: Z"
- Aceptar variaciones de redacción (NLP flexible)

Guardar cada report en `{proyecto}/standups/YYYYMMDD/{dev}.txt`

### Fase 3 — Compilar reporte (--compile)

1. Leer todos los reports recolectados hasta las {deadline}
2. Agrupar por estado: "ayer", "hoy", "bloqueantes"
3. Detectar patrones:
   - Bloqueantes recurrentes → sugerir escalación
   - Dependencias cruzadas → señalar
   - Desvíos de velocidad → alertar
4. Generar markdown:

```markdown
## Async Standup — {proyecto} — {YYYY-MM-DD}

### Participación: 7/8 (87.5%)
Falta reportar: Carlos

### Ayer (Sprint 2026-NN)
- Ana: Finalizar integración pagos + code review de Pedro
- Pedro: Tests unitarios backend, 4/5 completados
- María: Documentación API, 80% avance
...

### Hoy (prioridad del sprint)
- Ana: Deploy PRE de pagos, validación PO
- Pedro: Terminar tests, PR review, standup técnico
- María: Completar docs, generar diagrama OpenAPI
...

### 🚨 Bloqueantes
1. **Pedro**: "Dependencia de Ana para config de API keys PRE"
2. **Carlos**: "No llegó a reportar — seguimiento pendiente"

### Patrones detectados
- Dolor: Testing (mencionado 3 veces) → 3 sprints consecutivas
- Alerta: Config PRE sin documentar (riesgo deploy)
- Oportunidad: Pair María + Ana para acelerar docs

### Próximos pasos sugeridos
1. Resolver bloqueante PRE keys: meeting rápido Ana + Pedro
2. Seguimiento a Carlos (Viernes)
3. Considerar docu técnica como task separada sprint próximo
```

5. Guardar en `output/standups/YYYYMMDD-standup-{proyecto}.md`

---

## Integración

- Daily routine (09:15): ejecutar `/async-standup --project {p} --compile`
- Sprint planning: `/async-standup --project {p} --list` para tendencias
- `/sprint-status` → incluir bloqueantes recolectados

---

## Restricciones

- Reports solo 24h — reports > 24h se ignoran
- Compilación automática a deadline especificada (no esperar manualmente)
- Si participación < 50%: marcar reporte como "incompleto" + alertar PM
- Nunca eliminar reports brutos (guardar para auditoría)
