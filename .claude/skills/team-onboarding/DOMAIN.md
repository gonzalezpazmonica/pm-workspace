# team-onboarding — Dominio

## Por que existe esta skill

La incorporacion de un nuevo desarrollador a un proyecto cuesta entre 4 y 8 semanas sin estructura. Esta skill reduce el ramp-up a 5-10 dias generando documentacion personalizada, un plan 30/60/90 y un perfil de competencias que alimenta el algoritmo de asignacion. Ademas garantiza el cumplimiento RGPD desde el primer contacto con el trabajador.

## Conceptos de dominio

- **Nota informativa RGPD**: documento de transparencia (Art. 13-14) que se entrega al trabajador ANTES de recoger cualquier dato de competencias
- **Perfil de competencias**: autoevaluacion calibrada por Tech Lead que genera el campo expertise en equipo.md, usado para asignacion inteligente de tareas
- **Buddy IA**: agente que acompana al nuevo miembro en 3 capas: contexto del proyecto, tour del codigo y primera task asistida
- **Time-to-First-PR**: metrica principal de exito del onboarding, objetivo <=3 dias

## Reglas de negocio que implementa

- RGPD Art. 6.1.f: base legal de interes legitimo para recoger competencias laborales
- RGPD Arts. 15-21: derechos de acceso, rectificacion, supresion, oposicion y portabilidad
- Minimizacion de datos: solo competencias (1-5), interes (S/N) y fecha, sin metricas de productividad individual
- Code Review E1 humano obligatorio en la primera task del nuevo miembro

## Relacion con otras skills

- **Upstream**: `team-coordination` (el miembro se asigna a un equipo antes del onboarding)
- **Downstream**: `capacity-planning` (el perfil de competencias alimenta la capacidad del equipo)
- **Downstream**: `pbi-assign` (expertise del perfil influye en la asignacion inteligente)
- **Paralelo**: `enterprise-onboarding` (onboarding a escala para lotes de incorporaciones)

## Decisiones clave

- Nota informativa ANTES de recoger datos: obligacion legal, no buena practica opcional
- Autoevaluacion + calibracion Tech Lead: la autoevaluacion sola es poco fiable, la calibracion sola es invasiva
- Cuestionario estructurado (no entrevista libre): reproducible, comparable entre miembros, auditable
- Datos en directorios gitignored (privacy/, evaluaciones/): NUNCA se suben al repo publico
