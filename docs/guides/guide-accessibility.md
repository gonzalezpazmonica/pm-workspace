# Guía de Accesibilidad — Savia para todos

> 🦉 Soy Savia. Me adapto a ti. Esta guía explica cómo trabajo con personas con diferentes necesidades, paso a paso.

---

## Por qué importa

El 28,6% de los adultos con discapacidad cognitiva en edad laboral están empleados (vs 75% sin discapacidad). Muchos trabajan en tecnología — Fundación ONCE ha formado a más de 30.000 personas con discapacidad en competencias digitales. pm-workspace funciona en terminal (Claude Code), que ya es accesible por ser texto y teclado. Pero podemos ir mucho más allá: guiar activamente, adaptar outputs, y respetar el ritmo de cada persona.

---

## Configuración rápida

```
/accessibility-setup          → wizard conversacional (5 min)
/accessibility-mode status    → ver qué está activo
/guided-work --task PBI-123   → trabajo guiado paso a paso
/focus-mode --task PBI-123    → entorno limpio, sin distracciones
```

---

## Guía paso a paso por perfil de discapacidad

### Discapacidad visual (baja visión, ceguera)

**Qué activo:** `screen_reader: true`, `high_contrast: true`, `reduced_motion: true`

**Cómo cambia Savia:**
- Los burndown ASCII (`████░░░░`) se convierten en texto: "Progreso: 40%, 35 SP completados de 88"
- Las tablas complejas se convierten en listas descriptivas
- Los semáforos de color siempre incluyen texto: "CRÍTICO" en vez de solo 🔴
- Los separadores decorativos desaparecen
- Los informes generados (DOCX, PPTX) usan texto descriptivo para gráficos

**Ejemplo de uso diario:**
```
Tú: /sprint-status
Savia: Sprint 2026-04, día 6 de 10. Progreso: 40% completado, por debajo del plan.
  4 items activos. 2 alertas: AB#1023 sin movimiento 2 días, riesgo de no completar.
  Capacidad restante: 68 horas humanas, 12 horas agente.
```

### Discapacidad motora (RSI, movilidad reducida)

**Qué activo:** `motor_accommodation: true`, `voice_control: true`

**Cómo cambia Savia:**
- Sugiere aliases cortos cuando hay comandos largos
- No requiere flags complejos: acepta lenguaje natural ("¿cómo va el sprint?" → `/sprint-status`)
- Ofrece ejecutar secuencias de comandos automáticamente
- No interpreta silencio como abandono (timeouts extendidos)
- Compatible con Talon y Dragon NaturallySpeaking

**Ejemplo de uso diario:**
```
Tú: estado del sprint
Savia: [ejecuta /sprint-status automáticamente]
Tú: descompón el PBI 1025
Savia: [ejecuta /pbi-decompose 1025]
```

### ADHD / dificultad de concentración

**Qué activo:** `cognitive_load: low`, `guided_work: true`, `guided_work_level: alto`, `focus_mode: true`, `break_strategy: pomodoro`

**Cómo cambia Savia:**
- `/guided-work` te guía paso a paso con preguntas — un paso a la vez, máximo 3 líneas
- `/focus-mode` oculta todo lo que no sea tu tarea actual
- Pausas Pomodoro cada 25 minutos
- Si te pierdes: "Estabas en el paso 3. ¿Volvemos?"
- Si te bloqueas: reformula más simple, ofrece hacerlo ella, o sugiere pausa

**Ejemplo de uso diario:**
```
Tú: /guided-work --task PBI-1025
Savia: Vamos a implementar el endpoint POST /patients. Son 5 pasos. ¿Empezamos?
Tú: Sí
Savia: Paso 1: Crear PatientController.cs. ¿Lo creo?
Tú: Sí
Savia: Creado. Paso 1/5. ¿Siguiente?
```

### Trastorno del espectro autista

**Qué activo:** `cognitive_load: medium`, `review_sensitivity: true`, `guided_work: true`, `guided_work_level: medio`, `break_strategy: 52-17`

**Cómo cambia Savia:**
- Las code reviews usan lenguaje constructivo: fortalezas primero, nunca "error" o "bug"
- Estructura predecible: siempre el mismo formato, sin sorpresas
- Comunicación directa y sin ambigüedad
- Si hay cambio de contexto, avisa explícitamente
- TDD como estructura: "Los tests definen qué tiene que pasar. Si pasan, has terminado."

**Ejemplo de code review:**
```
Revisión de PatientController.cs
  Lo que está bien: estructura clara, sigue el patrón del proyecto.
  Oportunidades: caso no cubierto en línea 34 (null check).
  Sugerencia: añadir if (patient == null) return NotFound().
  Resumen: buena base, 1 ajuste. ¿Te ayudo?
```

### Dislexia

**Qué activo:** `dyslexia_friendly: true`, `cognitive_load: medium`

**Cómo cambia Savia:**
- Los documentos generados usan fuente sans-serif de alta legibilidad
- Interlineado 1.5, párrafos cortos, alineación izquierda
- Mensajes concisos sin bloques densos de texto
- Palabras comunes, frases cortas

### Discapacidad auditiva

pm-workspace funciona en terminal — todo es texto. No hay componentes de audio. Las personas con discapacidad auditiva pueden usar Savia sin ninguna adaptación especial. Si el equipo usa comunicación por voz (Teams, Slack calls), Savia puede transcribir con `/voice-inbox` y generar resúmenes escritos.

---

## Checklist de configuración

1. Ejecuta `/accessibility-setup` y responde las preguntas
2. Verifica con `/accessibility-mode status`
3. Prueba `/guided-work --task` con una tarea real
4. Ajusta el nivel de guía si es mucho o poco
5. Configura las pausas que te funcionen
6. Si usas lector de pantalla, verifica que los outputs son legibles
7. Si usas control por voz, prueba comandos en lenguaje natural
8. Pide a tu PM que ejecute `/team-workload` para verificar que tu carga es adecuada
9. Si algo no funciona bien → `/feedback` para reportarlo

---

## Fuentes

- [Fundación ONCE "Por Talento Digital"](https://www.fundaciononce.es/es) — Inclusión digital
- [N-CAPS: Context-Aware Prompting System](https://pubmed.ncbi.nlm.nih.gov/26135042/) — Guía adaptativa
- [Neurodivergent-Aware Productivity Framework](https://arxiv.org/html/2507.06864) — Andamiaje cognitivo
- [ADHD/Autism en desarrollo de software](https://arxiv.org/html/2411.13950v1) — Estudio de campo
- [CLI Accessibility](https://afixt.com/accessible-by-design-improving-command-line-interfaces-for-all-users/) — Mejores prácticas
