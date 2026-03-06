---
paths:
  - "**/wellbeing-*"
  - "**/guardian-*"
---

# Regla: Configuración del Wellbeing Guardian
# ── Sistema proactivo de bienestar individual para usuarios de Savia ──

> Basado en: "AI Doesn't Reduce Work—It Intensifies It" (HBR, Feb 2026, Berkeley Haas)
> La IA intensifica el trabajo de 3 formas: expansión de tareas, difuminación
> de límites trabajo-vida, y multitasking cognitivo. Soluciones: pausas
> intencionales, secuenciación del trabajo, y tiempo de conexión humana.

## Estrategias de descanso

| Estrategia | Foco (min) | Descanso (min) | Pausa larga | Ideal para |
|---|---|---|---|---|
| `pomodoro` | 25 | 5 | 20-30 cada 4 ciclos | Tareas variadas |
| `52-17` | 52 | 17 | — | Deep work / coding |
| `5-50` | 50 | 5 (analógico) | 15 cada 3 ciclos | Trabajo con IA |
| `custom` | configurable | configurable | configurable | Preferencias personales |

Complementarias (siempre activas):
- **Regla 20-20-20**: cada 20min, mirar a 6m durante 20s (fatiga visual)
- **INSST España**: pausa 10-15min por cada 60-90min de pantalla
- **Pausas activas**: estiramientos y cambio de postura reducen molestias un 30%

## Schema de horario en workflow.md

Campos opcionales (backward-compatible) a añadir en `workflow.md` del perfil:

```yaml
# Wellbeing
work_hours_start: "09:00"        # Hora local inicio jornada
work_hours_end: "18:00"          # Hora local fin jornada
lunch_break: "13:00-14:00"       # Franja de comida
conciliation: ""                 # Ej: "17:00-18:00" (conciliación)
break_strategy: "pomodoro"       # pomodoro | 52-17 | 5-50 | custom
custom_focus_min: 25             # Solo si strategy=custom
custom_break_min: 5              # Solo si strategy=custom
max_daily_hours: 10              # Alerta si se supera
silence_weekends: true           # Nudge de desconexión en fin de semana
```

Nota: `timezone` se obtiene de `preferences.md` → no duplicar.

## Plantillas de nudge

### Break debido
```
⏸️ Llevas {elapsed}min de foco continuo. Tu estrategia {strategy}
sugiere un descanso de {break_min}min. ¿Buen momento para parar?
```

### Fuera de horario
```
🌙 Son las {hora_actual}. Tu jornada termina a las {work_hours_end}.
¿Necesitas continuar o prefieres dejarlo para mañana?
```

### Fin de semana
```
📅 Hoy es {día_semana}. Recuerda que desconectar es parte del rendimiento.
¿Hay algo urgente que requiera tu atención ahora?
```

### Hidratación y postura
```
💧 Llevas {elapsed}min en esta sesión. Buen momento para hidratarte,
estirar y aplicar la regla 20-20-20 (mira a 6m durante 20s).
```

### Post-descanso
```
✅ ¡Bienvenido/a de vuelta! Pausa de {break_duration}min registrada.
Llevas {breaks_today} descansos hoy. ¡Buen ritmo!
```

## Reglas de conducción

- **Una sugerencia, no una orden** — el usuario decide siempre
- **Sin bloqueo** — los nudges son informativos, nunca interrumpen
- **Frecuencia máxima** — máximo 1 nudge cada 25min (evitar fatiga)
- **Escalado amable** — si el usuario ignora 3 nudges seguidos, reducir frecuencia
- **Fuera de horario** — máximo 1 aviso al inicio, luego silencio salvo que pidan
- **Privacidad** — datos de horario son locales, nunca en commits públicos

## Integración con sistemas existentes

### burnout-radar
- Wellbeing Guardian exporta `break_compliance_score`: (breaks_tomados / esperados) × 100
- Radar lo consume como señal individual para el heat map del equipo

### sustainable-pace
- El `wellbeing_factor` de la fórmula se alimenta de la adherencia real a descansos
- Factor = break_compliance_score / 100 (normalizado 0-1)

### daily-routine
- Wellbeing integra work_hours para ajustar sugerencias de horario
- No duplica la rutina diaria; la complementa con micro-pausas

## Seguridad y privacidad

- Datos de horario → perfil local del usuario, nunca en SaviaHub público
- Historial de breaks → log local (git-ignorado si se implementa)
- NUNCA registrar contenido de trabajo en logs de bienestar
- Respetar preferencia `silence_weekends` sin excepciones
