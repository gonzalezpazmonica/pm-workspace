# Enterprise Onboarding -- Dominio

## Por que existe esta skill

Incorporar personas nuevas a equipos tecnicos es un proceso repetitivo y propenso a olvidos. Sin un sistema estructurado, el tiempo-a-productividad se dispara y la experiencia del nuevo miembro se degrada. Esta skill automatiza la generacion de checklists por rol, knowledge transfer y seguimiento de progreso.

## Conceptos de dominio

- **Modelo 4 fases**: Pre-llegada (Fase 0), Dia 1 (Fase 1), Semana 1 (Fase 2), Mes 1 (Fase 3) con hitos medibles.
- **Knowledge Transfer (KT)**: documento generado desde decision-log y specs del proyecto para acelerar contexto.
- **Checklist por rol**: plantilla adaptada a Developer, QA, PM o Tech Lead con tareas y tiempos especificos.
- **Buddy**: persona asignada como mentor durante las primeras 2 semanas.
- **Time-to-first-PR**: metrica principal de exito; umbral <5 dias para developers.

## Reglas de negocio que implementa

- onboarding-enterprise.md: importacion CSV con schema validado (name, email, role, team, projects, start_date).
- Checklists generados respetan la estructura de equipos en teams/{dept}/.
- Datos de onboarding en output/ son gitignored; KT docs pueden contener datos de cliente (N4).
- Emails nunca se exponen en outputs publicos; usar @handles.

## Relacion con otras skills

- **Upstream**: team-coordination (estructura de equipos), profile-setup (perfiles de usuario).
- **Downstream**: sprint-management (nuevo miembro entra al sprint), capacity-planning (capacidad ajustada).
- **Paralelo**: team-onboarding (version individual vs esta version batch/enterprise).

## Decisiones clave

- CSV batch sobre importacion individual: escala mejor para onboardings simultaneos.
- KT generado desde decision-log: reutiliza conocimiento existente en vez de redactar desde cero.
- Tracking de progreso en ficheros markdown: coherente con la filosofia .md-is-truth del workspace.
