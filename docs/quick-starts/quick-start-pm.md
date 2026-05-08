# Quick Start — PM / Scrum Master

> 🦉 Hola, PM. Soy Savia. Voy a ser tu copiloto en la gestión de sprints, capacidad del equipo e informes. Aquí tienes lo esencial para empezar.

---

## Primeros 10 minutos

Abre Claude Code en la raíz de pm-workspace y ejecuta estos tres comandos:

```
/sprint-status --project MiProyecto
```
Verás el burndown, items activos, alertas y capacidad restante del sprint actual.

```
/team-workload --project MiProyecto
```
Muestra la carga de cada miembro: horas asignadas vs disponibles, y detecta sobrecargas.

```
/daily-routine
```
Te propongo la rutina del día según tu rol: qué revisar, en qué orden, qué comandos usar.

---

## Tu día a día

**Lunes** — `/sprint-status` para preparar la semana. Si hay items bloqueados, los verás en las alertas.

**Cada mañana** — `/async-standup --compile` recoge los avances del equipo. Si alguien no reportó, te aviso.

**Miércoles** — `/team-workload` a mitad de sprint para detectar desvíos. Si la velocity baja y las horas suben, puede ser burnout → `/wellbeing-check`.

**Viernes de cierre** — `/sprint-review` genera el resumen. `/sprint-retro` estructura la retrospectiva con patrones detectados.

**Fin de sprint** — `/report-hours` exporta la imputación a Excel. `/report-executive` genera el informe para dirección.

---

## Cómo hablarme

No necesitas memorizar comandos. Puedes pedirme las cosas en lenguaje natural:

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Cómo va el sprint?" | `/sprint-status` |
| "¿Quién está sobrecargado?" | `/team-workload` + análisis de capacity |
| "Necesito el informe para el cliente" | `/report-executive` o `/excel-report` |
| "Prepara la daily de mañana" | `/async-standup --start` |
| "Descompón este PBI en tareas" | `/pbi-decompose {id}` |
| "¿Llegaremos a fin de sprint?" | `/sprint-forecast` con Monte Carlo |

---

## Dónde están tus ficheros

```
output/
├── reports/           ← informes generados (Excel, PowerPoint)
├── sprint-snapshots/  ← fotos del estado del sprint
└── .memory-store.jsonl ← mi memoria persistente

.opencode/commands/
├── sprint-*.md        ← comandos de sprint (plan, status, review, retro)
├── report-*.md        ← comandos de reporting
├── team-*.md          ← comandos de equipo y capacity
└── pbi-*.md           ← gestión de backlog
```

Los informes se generan en `output/` con fecha en el nombre. Puedes abrirlos directamente o enviarlos.

---

## Cómo se conecta tu trabajo

Las horas que imputa tu equipo (`/report-hours`) las uso para calcular costes por proyecto (`cost-management`). Esos costes alimentan las facturas y aparecen en el informe de dirección (`/ceo-report`). Si la velocity cae y las horas aumentan, activo alertas de burnout que el CEO ve en `/ceo-alerts`. Todo está conectado — tu trabajo como PM es el punto de entrada de datos que alimenta toda la cadena.

---

---

## Desde el móvil

Si tienes Savia Mobile instalado, puedes consultar estos mismos comandos desde tu teléfono Android. La app se conecta al Savia Bridge y te permite chatear con Savia con streaming en tiempo real — ideal para reuniones, desplazamientos o revisiones rápidas.

Configura el Bridge: `python3 savia-bridge.py --print-token` para obtener el token de conexión. Más info: `projects/savia-mobile-android/docs/BRIDGE-GUIDE.md`

---

## Siguientes pasos

- [Sprints e informes en detalle](../readme/04-uso-sprint-informes.md)
- [Configuración avanzada](../readme/06-configuración-avanzada.md)
- [Guía de flujo de datos](../data-flow-guide-es.md)
- [Comandos y agentes completos](../readme/12-comandos-agentes.md)
