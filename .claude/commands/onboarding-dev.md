---
name: onboarding-dev
description: Technical onboarding with AI Buddy — auto-generates project docs, personalized plan, and 3-layer buddy agent
---

# /onboarding-dev

Onboarding técnico completo para nuevos desarrolladores. Auto-genera documentación del proyecto, plan personalizado 30/60/90, y activa un Buddy IA de 3 capas (orientación, ejecución, contexto).

## 1. Cargar configuración

1. Leer `.claude/skills/onboarding-dev/SKILL.md` — flujo completo y guardarraíles
2. Leer `projects/{proyecto}/CLAUDE.md` — contexto del proyecto
3. Leer `equipo.md` — miembros actuales

## 2. Uso

```
/onboarding-dev {nombre} --rol {rol} --seniority {jr|mid|sr} --proyecto {nombre} [--fecha {YYYY-MM-DD}]
```

- `{nombre}`: Nombre del nuevo miembro
- `--rol`: developer | frontend | backend | fullstack | qa | devops
- `--seniority`: jr | mid | sr
- `--proyecto`: Proyecto al que se incorpora
- `--fecha`: Fecha de incorporación (default: hoy)

Ejemplo:
```
/onboarding-dev "Alex García" --rol backend --seniority mid --proyecto mi-api
```

## 3. Prerequisitos

```
✅ Proyecto configurado (CLAUDE.md existe)  → si no: ❌ "Usa /project-new primero"
✅ Acceso al repositorio                      → si no: ❌ "No se puede analizar el proyecto"
```

## 4. Ejecución por fases

### Fase 1: Auto-análisis del proyecto

```
📖 Onboarding Dev — Fase 1: Auto-análisis

Analizando proyecto {nombre}...

Generando documentación:
  ✅ 01-arquitectura-alto-nivel.md
  ✅ 02-mapa-equipos-ownership.md
  ✅ 03-glosario-interno.md
  ✅ 04-herramientas-accesos.md
  ✅ 05-setup-local.md
  ✅ 06-flujos-pr-estandares.md
  ✅ 07-como-se-despliega.md
  ✅ 08-decisiones-tecnicas-clave.md
  ✅ 09-historico-incidencias.md
  ✅ 10-faq-onboarding.md
  ✅ 11-calidad-procesos.md
  ✅ 12-expectativas-rampup.md

📁 Documentación en: projects/{proyecto}/onboarding/
```

### Fase 2: Plan personalizado

```
📖 Onboarding Dev — Fase 2: Plan personalizado

Adaptando para: {nombre} ({rol}, {seniority})

  ✅ Plan 30/60/90 días
  ✅ Checklist de accesos y configuraciones
  ✅ Guía de primer PR

📁 Plan en: projects/{proyecto}/onboarding/{nombre}-*.md
```

### Fase 3: Buddy IA

```
📖 Onboarding Dev — Fase 3: Buddy IA activado

🤖 Buddy IA configurado para {nombre}
   Base de conocimiento: 12 documentos del proyecto
   Capas: Orientación · Ejecución · Contexto

   Uso: /onboarding-ask {pregunta}

   Guardarraíles activos:
   ⚠️ No inventa — si no sabe, lo dice
   ⚠️ Cita fuentes — siempre con archivo y sección
   ⚠️ Señala confianza — alto/medio/bajo
   ⚠️ Escala a humano — si el tema lo requiere
```

## 5. Output final

```
📖 Onboarding Dev — Completado

👤 Nuevo miembro: {nombre} ({rol}, {seniority})
📁 Documentación: projects/{proyecto}/onboarding/ (12 documentos)
📋 Plan: projects/{proyecto}/onboarding/{nombre}-plan-30-60-90.md
🤖 Buddy IA: activo vía /onboarding-ask

📊 Métricas a rastrear:
  - Tiempo hasta primer PR: objetivo ≤ {3|5} días
  - Primer PR sin cambios: objetivo ≤ {5|10} días
  - Confianza ≥7/10: objetivo día {5|10|15}

💡 Siguiente paso: Compartir projects/{proyecto}/onboarding/ con {nombre}

⚡ /compact
```
