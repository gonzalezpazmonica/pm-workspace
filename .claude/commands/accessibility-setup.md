---
name: accessibility-setup
description: Configura las preferencias de accesibilidad de Savia para adaptarse a tus necesidades
model: haiku
context_cost: low
allowed_tools: ["Read", "Write", "Edit"]
---

# /accessibility-setup

Configura las preferencias de accesibilidad del usuario actual a través de una conversación natural.

## Protocolo

### Antes de empezar

Carga el perfil activo desde `.claude/profiles/active-user.md`. Si no existe perfil, sugiere ejecutar `/profile-setup` primero. Si existe pero no tiene `accessibility.md`, créalo desde la plantilla en `.claude/profiles/users/template/accessibility.md`.

### Fase 1 — Visión

Pregunta de forma natural, sin formulario:

> "Vamos a configurar cómo me comunico contigo para que sea lo más cómodo posible. Empecemos por la visión: ¿usas un lector de pantalla como NVDA, JAWS o VoiceOver? ¿Necesitas que evite depender de colores para dar información?"

Según la respuesta, actualiza: `screen_reader`, `high_contrast`, `reduced_motion`.

### Fase 2 — Motor

> "¿Tienes alguna dificultad con el teclado o el ratón? ¿Usas control por voz (Talon, Dragon)? Si quieres, puedo activar aliases cortos para los comandos más usados y extender los tiempos de espera."

Actualiza: `motor_accommodation`, `voice_control`.

### Fase 3 — Cognitivo

> "Ahora algo importante: ¿preferirías que te dé la información más resumida y paso a paso? Tengo un modo de trabajo guiado donde voy haciéndote preguntas en vez de darte toda la información de golpe. También puedo adaptar el lenguaje de las code reviews para que sea más constructivo. ¿Te interesa alguna de estas opciones?"

Actualiza: `cognitive_load`, `focus_mode`, `guided_work`, `guided_work_level`, `review_sensitivity`, `dyslexia_friendly`.

### Fase 4 — Bienestar

> "Por último: ¿te ayudaría que te recuerde tomar pausas? Puedo usar la técnica Pomodoro (25 min trabajo / 5 descanso), el método 52-17, o un intervalo que tú elijas."

Actualiza: `break_strategy`, `break_interval_min`.

### Confirmación

Muestra resumen de lo configurado con explicación de qué hace cada ajuste. Guarda en `.claude/profiles/users/{slug}/accessibility.md`.

```
✅ Configuración de accesibilidad guardada:
  - Lector de pantalla: activado (sin ASCII art, output estructurado)
  - Carga cognitiva: baja (mensajes cortos, paso a paso)
  - Trabajo guiado: activado nivel alto
  - Pausas: Pomodoro cada 25 min

Puedes cambiar cualquier ajuste con /accessibility-mode configure
o ejecutar /accessibility-setup de nuevo.
```

## Output Template

```yaml
resultado:
  fichero_actualizado: ".claude/profiles/users/{slug}/accessibility.md"
  ajustes_activados: [lista]
  siguiente_accion: "/guided-work --task {PBI} para probar el modo guiado"
```

## Restricciones

- NUNCA asumir una discapacidad: preguntar, no diagnosticar
- Tono cálido y natural, no clínico ni condescendiente
- Si el usuario dice que no necesita nada → respetar y no insistir
- Toda la conversación en el idioma del perfil del usuario
