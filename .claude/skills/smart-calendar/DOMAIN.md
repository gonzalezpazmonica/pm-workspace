---
name: smart-calendar-domain
description: Contexto de dominio para gestion inteligente de agenda PM
---

# Por que existe esta skill

Un PM de consultora grande gestiona 5-15 reuniones/dia, 3+ proyectos,
decenas de tareas sin fecha fija que se posponen hasta ser urgentes.
Las herramientas existentes (Outlook, Teams) gestionan eventos pero
no priorizan trabajo ni alertan de lo que se queda atras.

## Conceptos de dominio

- **Focus block**: bloque de tiempo protegido para trabajo profundo (min 45min)
- **Deadline proximity**: dias restantes hasta la fecha limite (urgencia crece exponencialmente)
- **Rebalanceo**: redistribuir bloques de focus cuando cambia el calendario
- **Capacity day**: % del dia disponible para trabajo productivo (100% - reuniones)
- **Guardian alert**: aviso proactivo de item que se puede quedar atras

## Reglas de negocio

- Eisenhower Matrix adaptado: DO/SCHEDULE/DELEGATE/ELIMINATE
- Deep Work (Newport): bloques minimos de 45 min, max 3h
- PMI: time management como area de conocimiento critica
- Buffer de 15 min entre reuniones (reset cognitivo)

## Relacion con otras skills

- **Upstream**: sprint-management (fechas), meeting-digest (reuniones pendientes)
- **Downstream**: daily-routine (vista del dia), wellbeing-guardian (burnout)
- **Paralela**: capacity-planning (capacidad del equipo, no del PM)

## Decisiones clave

- Microsoft Graph API sobre alternativas (Google Calendar, CalDAV)
  porque el ecosistema target es Microsoft (Teams/Outlook/Azure DevOps)
- OAuth delegated (no app-only) para acceso con consentimiento del usuario
- Focus blocks como "tentative" (no bloquean calendario para otros)
- Alertas basadas en reglas declarativas, no ML (predecible, auditable)
