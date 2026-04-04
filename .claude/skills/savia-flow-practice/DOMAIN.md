# Savia Flow Practice -- Dominio

## Por que existe esta skill

Scrum clasico optimiza la cadencia (sprints) pero no el flujo continuo ni la conexion entre descubrimiento y produccion. Savia Flow es una metodologia dual-track orientada a outcomes con specs ejecutables. Esta skill lleva la teoria a la practica: configura boards, mide flujo y coordina los dos tracks.

## Conceptos de dominio

- **Dual-Track**: Exploration (descubrir que construir) y Production (construir lo que esta listo) corren en paralelo.
- **Spec-Ready**: puente entre tracks; una spec completa con outcome, metricas de exito, restricciones y Definition of Done.
- **4 roles**: Flow Facilitator (optimizar flujo), AI Product Manager (discovery/specs), Pro Builder (devs), Quality Architect (gates).
- **Metricas DORA + IA**: Cycle Time 3-7d, Lead Time 7-14d, Throughput 8-12/sem, CFR <5%, Spec-to-Built <5d, Rework <15%.
- **Knowledge Priming**: preparacion de contexto AI con 7 secciones y patrones Fowler para agentes de codigo.

## Reglas de negocio que implementa

- Solo items Spec-Ready entran a Production Track; discovery incompleto no se construye.
- WIP limits por columna para evitar cuellos de botella.
- Metricas de flujo calculadas desde datos reales de Azure DevOps (WIQL).
- Coexistencia con Scrum: equipos pueden adoptar gradualmente sin migrar de golpe.

## Relacion con otras skills

- **Upstream**: product-discovery (JTBD + PRD alimentan exploration track), spec-driven-development (specs ejecutables).
- **Downstream**: pbi-decomposition (specs descompuestas en tasks), capacity-planning (WIP y carga por track).
- **Paralelo**: sprint-management (Scrum clasico vs Savia Flow; coexisten).

## Decisiones clave

- Dual-track sobre single backlog: separa descubrimiento de ejecucion para evitar construir lo incorrecto.
- Outcome-driven sobre output-driven: medir impacto, no solo entrega.
- Plataforma agnostica: diseño abstracto con adapters por plataforma (Azure DevOps completo, Jira/GitLab planned).
