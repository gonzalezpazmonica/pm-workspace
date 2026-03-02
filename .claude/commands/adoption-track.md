---
name: adoption-track
description: Tracking de adopción — comandos usados por rol, curva de aprendizaje, puntos de fricción
developer_type: all
agent: task
context_cost: medium
---

# /adoption-track

> 🦉 Métrica de adopción en tiempo real: ¿quién usa Savia? ¿Qué comanda? ¿Dónde frenan?

Dashboard de adopción por rol, equipo y comando. Detección automática de fricción.

---

## Datos Recopilados

Por cada comando ejecutado:
- **Usuario/rol** (del perfil activo)
- **Timestamp** (hora ejecución)
- **Comando** (ej: `/sprint-status`)
- **Resultado** (✅ éxito, ⚠️ con aviso, ❌ error)
- **Duración** (segundos)
- **Contexto** (proyecto, sprint actual)
- **Proyecto** (si aplica)

Almacenado en: `output/adoption-tracking.jsonl` (append-only log)

---

## Flujo

### Paso 1 — Recopilar datos
- Leer logs de ejecución de comandos (últimas N sesiones)
- Extraer: comando, usuario, proyecto, éxito/error, duración
- Agregar con timestamps de sesión

### Paso 2 — Calcular métricas por rol

**Adoption Rate**: % de usuarios del rol que han usado Savia (≥1 comando)

**Command Frequency**: promedio comandos/usuario/semana
- Baja (<1): usuarios pasivos, no enganchados
- Normal (1-3): usuarios steady
- Alta (>3): power users

**Success Rate**: % comandos exitosos vs. totales
- <80%: alto dolor, requiere support/training
- 80-95%: normal
- >95%: excelente

**Learning Velocity**: comando nuevo cada cuántos días (adoptando amplitud)

### Paso 3 — Identificar friction points

**Frenos por comando** (comandos frecuentemente fallidos):
- `/sprint-status` falla 30% → prob: config PAT
- `/pbi-create` abandono 70% → prob: demasiadas opciones

**Frenos por rol**:
- QA usa `/qa-dashboard` pero no `/testplan-generate` → desconoce interconexión
- DevOps no toca infra commands → requiere training

**Escalones de aprendizaje**:
- Salto grande entre L1→L2 → necesita mentoría

### Paso 4 — Detectar riesgo de churn

Alertas automáticas:
- Usuario activo hace 2 semanas, sin actividad última semana → ⚠️ churn risk
- Rol con <20% adoption rate → 🔴 critical, necesita intervención
- Command con >50% error rate → 🔴 comando roto o confuso

### Paso 5 — Generar recomendaciones

Por rol:
- Tech Lead: "Activo en specs, nunca usa `/debt-track` → sugerir training"
- PM: "Alto uso de reportes, pero no planificación → sugerir `/sprint-autoplan`"
- Developer: "Domina SDD, pero no tests → sugerir `/testplan-generate`"

Por comando:
- Reescribir o crear tutorial: comandos con >30% error rate
- Crear video de 3 min: comandos con alto potencial pero bajo uso
- Agregar ejemplo: comandos que la gente abandona al paso 1

---

## Output

**Dashboard ejecutivo**:
```
╔════════════════════════════════════════════╗
║ ADOPTION METRICS — PROYECTO SALA-RESERVAS ║
╚════════════════════════════════════════════╝

Global Adoption Rate: 65% (13/20 usuarios)
Commands in Use: 28/201 (14%)
Avg Commands per User: 2.4/week
Overall Success Rate: 87%

┌─ BY ROLE ─────────────────────────────────┐
│ PM          │ 95% adoption │ 4.2 cmd/week │
│ Developer   │ 60% adoption │ 1.8 cmd/week │
│ QA          │ 55% adoption │ 2.1 cmd/week │
│ Tech Lead   │ 100% adoption│ 3.5 cmd/week │
└───────────────────────────────────────────┘

Top 5 Commands:
 1. /sprint-status      — 45 uses, 98% success
 2. /my-sprint          — 38 uses, 94% success
 3. /sprint-plan        — 22 uses, 91% success
 4. /pbi-create         — 18 uses, 72% success ⚠️
 5. /pr-pending         — 15 uses, 100% success

Friction Points:
 🔴 /pbi-create: 72% success (→ too complex, 8 options)
 🔴 Devs: 60% adoption (→ not engaging, ≠ workflow)
 ⚠️  Churn risk: Carlos (last active 8 days ago)
```

**Detailed report**: `output/adoption-track-{proyecto}-{YYYYMMDD}.md`
- Tabla completa de comandos × roles
- Gráfico de curva de aprendizaje
- Recomendaciones por rol y por comando
- Propuestas de intervención

---

## Restricciones

- NUNCA exponer datos privados de usuarios (reducir a role/anónimo)
- Tracking is opt-in — usuarios pueden `/adoption-track private` para excluirse
- Data retention: máximo 90 días (luego anonimizar)
