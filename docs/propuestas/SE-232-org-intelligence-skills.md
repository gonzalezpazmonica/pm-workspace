---
id: SE-232
title: "Familia de Skills org-intelligence — mapa de poder y conocimiento organizativo tácito"
status: IMPLEMENTED
priority: P2
effort: "M (8h)"
author: Savia
proposed_at: "2026-06-28"
era: 237
tags: ["org-intelligence", "stakeholders", "conocimiento-tacito", "politica-organizativa"]
---

# SE-232 — Familia de Skills org-intelligence

## Problema

Las organizaciones acumulan conocimiento crítico que no figura en ningún documento:
quién tiene poder real de decisión (independientemente del organigrama), qué acuerdos
informales condicionan las iniciativas, qué coaliciones apoyan u obstaculizan los proyectos.
Este conocimiento tácito se pierde cuando cambia el equipo, bloquea proyectos sin razón
aparente y genera re-trabajo costoso.

Los directivos y gestores de proyecto necesitan herramientas para mapear y navegar
este paisaje organizativo. Actualmente no existe ningún skill en pm-workspace que asista
en este dominio.

## Solución propuesta

Tres skills bajo el namespace `org-intelligence`:

### org-stakeholder-mapper

Mapea actores clave de una iniciativa o proyecto:
- Identifica stakeholders por influencia real (no por jerarquía formal)
- Clasifica por posición (promotor/neutral/opositor) y por acceso a recursos
- Produce mapa de relaciones y estrategia de engagement para cada grupo
- Schema de nodo: `DECISOR` con atributos (nombre, influencia: ALTA/MEDIA/BAJA, posición, canal preferido)

### org-political-landscape

Analiza el entorno político de una decisión o iniciativa:
- Identifica alianzas, coaliciones y tensiones existentes
- Detecta acuerdos informales que pueden condicionar el resultado (`INFORMAL_AGREEMENT`)
- Propone estrategia de navegación: a quién involucrar, en qué orden, con qué argumento
- Schema de nodo: `POLITICAL_CONTEXT` con atributos (contexto, riesgo, oportunidad, timing)

### org-meeting-capture

Extrae conocimiento organizativo tácito de transcripciones de reuniones:
- Identifica quién toma decisiones reales (no solo quién habla más)
- Detecta compromisos implícitos y acuerdos no formalizados
- Señala tensiones o resistencias no expresadas directamente
- Alimenta los schemas DECISOR e INFORMAL_AGREEMENT del grafo de conocimiento

## Schema de nodos (integración con knowledge-graph — SE-162)

```yaml
nodos:
  DECISOR:
    campos: [nombre, rol_formal, influencia_real, posicion_iniciativa, canal_preferido, notas]
    relaciones: [APOYA, SE_OPONE_A, INFLUYE_EN, ES_INFLUIDO_POR]

  INFORMAL_AGREEMENT:
    campos: [partes, contenido_acuerdo, fecha_aproximada, confidencialidad, impacto_en]
    relaciones: [ENTRE, CONDICIONA, BLOQUEA, HABILITA]

  POLITICAL_CONTEXT:
    campos: [iniciativa, coaliciones_favor, coaliciones_contra, acuerdos_previos, riesgo, timing]
    relaciones: [AFECTA_A, GENERADO_POR, RESUELVE]
```

## Criterios de aceptación

1. Los 3 skills existen en `.opencode/skills/org-intelligence/` con SKILL.md + DOMAIN.md + prompt.md
2. Cada SKILL.md tiene disclaimer explícito: "El conocimiento político organizativo es sensible. No compartir outputs con terceros sin autorización."
3. `org-meeting-capture` acepta transcripciones en formato VTT, DOCX y texto plano
4. `org-stakeholder-mapper` produce siempre mínimo: mapa de actores, estrategia de engagement y riesgos
5. Los schemas DECISOR/INFORMAL_AGREEMENT/POLITICAL_CONTEXT están documentados en `docs/rules/domain/org-intelligence-protocol.md`
6. Tests BATS verifican existencia y estructura de los 3 skills

## Qué NO incluye esta spec

- Integración automática con bases de datos de RRHH o directorios corporativos
- Análisis de sentimiento sobre individuos específicos (riesgo de uso discriminatorio)
- Almacenamiento persistente de perfiles de personas sin consentimiento explícito (RGPD)
- Predicción algorítmica de comportamiento de personas

## Dependencias

- SE-162 (Knowledge Graph) — para integración de schemas
- `meeting-digest` agent — para alimentar `org-meeting-capture`

## Riesgos

- **Privacidad**: el conocimiento sobre dinámicas de poder es sensible; los outputs
  pueden contener información personal. Requiere política de retención y acceso.
- **Sesgo**: el modelo puede reflejar sesgos en la interpretación de comportamientos
  organizativos. Los outputs son orientativos, no descriptivos objetivos.
- **Mal uso**: el mapa de stakeholders no debe usarse para manipulación o exclusión.

## Notas de implementación

Prioridad: desarrollar primero `org-meeting-capture` (más fácil de validar con datos
reales de reuniones ya existentes) y luego los otros dos.
