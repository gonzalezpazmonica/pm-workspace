# Accesibilidad en PM-Workspace

> 🦉 Soy Savia. Me adapto a cómo trabajas tú, no al revés. Si necesitas que te hable diferente, que te guíe paso a paso, o que adapte mis salidas para tu lector de pantalla — solo configúralo.

---

## Configuración rápida

```
/accessibility-setup
```

Un wizard de 5 minutos que te pregunta qué necesitas. Guarda tus preferencias para todas las sesiones.

```
/accessibility-mode status
```

Ver qué adaptaciones están activas.

---

## Funcionalidades principales

**Trabajo guiado** (`/guided-work`) — Savia te acompaña paso a paso con preguntas. Un paso a la vez, a tu ritmo. Si te atascas, reformula. Si necesitas descanso, guarda el progreso. Tres niveles de guía: alto (preguntas cerradas), medio (bloques de pasos), bajo (checklist).

**Modo foco** (`/focus-mode`) — Carga una sola tarea y oculta todo lo demás. Sin sprint board, sin backlog, sin distracciones. Combinable con trabajo guiado.

**Salida adaptada** — Si usas lector de pantalla, Savia reemplaza diagramas ASCII por texto. Si necesitas alto contraste, no depende de colores. Si prefieres mensajes cortos, limita la salida a 5 líneas.

**Revisiones constructivas** — Las code reviews usan lenguaje de fortalezas primero, sin palabras que generen rechazo. Configurado con `review_sensitivity: true`.

**Pausas** — Integración con el sistema de bienestar. Pomodoro, 52-17, o el intervalo que prefieras.

---

## Configuraciones comunes

| Necesidad | Qué activar |
|---|---|
| Uso lector de pantalla | `screen_reader: true`, `high_contrast: true` |
| Movilidad reducida / RSI | `motor_accommodation: true` |
| ADHD / concentración | `guided_work: true`, `focus_mode: true`, `cognitive_load: low` |
| Autismo | `review_sensitivity: true`, `guided_work: true` |
| Dislexia | `dyslexia_friendly: true` |

---

## FAQ

**¿Puedo desactivarlo temporalmente?** Sí: `/accessibility-mode off`. Se reactiva con `on`.

**¿Afecta al rendimiento?** No. Las adaptaciones son instrucciones de formato, no procesamiento extra.

**¿Lo ven mis compañeros?** No. Tu perfil de accesibilidad es local, solo afecta a tu sesión.

**¿Funciona con lector de pantalla X?** Savia genera texto plano compatible con NVDA, JAWS y VoiceOver. Si algo no funciona, reporta con `/feedback`.

---

Guía completa: [guide-accessibility.md](guides/guide-accessibility.md)
