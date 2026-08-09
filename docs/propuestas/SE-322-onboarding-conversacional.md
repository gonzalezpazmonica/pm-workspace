---
id: SE-322
title: "SE-322 — Onboarding conversacional guiado: instalación por prompt + entrevista"
status: PROPOSED
priority: baja
---

# SE-322 — Onboarding conversacional guiado: instalación por prompt + entrevista

**Status:** PROPOSED
**Fecha:** 2026-08-09
**Area:** Developer experience / Onboarding / UX
**Branch sugerida:** `agent/se322-onboarding-conversacional`
**Estimacion total:** ~12h (2 slices)
**Inspiracion:** `danielmiessler/LifeOS` (install-by-prompt, LifeOS/Workflows/Interview.md)

---

## Contexto y evidencia (2026-08-09)

LifeOS se instala *por prompt*: "Read https://ourlifeos.ai/install and install
LifeOS for me" — el agente lee la página de instalación, camina el setup y
pide permiso antes de tocar nada. Su workflow `Interview.md` es un setup
conversacional guiado que captura perfil, preferencias y estado actual →
estado deseado antes de configurar.

Savia tiene:
- `onboarding-dev` (buddy IA para devs nuevos),
- `team-onboarding` (incorporación + competencias),
- `profile-onboarding` (primera sesión de un usuario nuevo: Savia se presenta
  y pregunta nombre/rol/empresa/proyectos),
- `enterprise-onboarding` (incorporación masiva).

**El hueco.** El onboarding de Savia pide datos *por turno* (nombre, rol,
proyectos) pero sin una entrevista estructurada ni un "install" que configure
el workspace a partir de las respuestas. LifeOS demuestra dos patrones que
Savia no tiene consolidados:
1. **Install-by-prompt**: una instrucción única dispara el setup completo
   (no 10 comandos manuales).
2. **Entrevista guiada (Interview.md)**: captura de estado actual → deseado
   que alimenta la configuración, en vez de preguntas sueltas.

---

## Objetivo

Añadir un flujo de onboarding conversacional guiado: un prompt de entrada
(`/setup` o petición natural) que dispara una entrevista estructurada
(estado actual → deseado) y aplica la configuración del workspace paso a
paso, pidiendo permiso antes de cada mutación.

---

## Out of scope

- NO reescribir `profile-onboarding` (el perfil activo se mantiene).
- NO tocar incorporación masiva (`enterprise-onboarding`).
- NO automatizar acciones irreversibles sin confirmación (regla autonomous-safety).

---

## Diseno

### S1 — Entrevista guiada

`docs/rules/domain/onboarding-interview.md` (patrón LifeOS Interview.md):
- batería de preguntas por etapas: identidad → proyectos → herramientas →
  preferencias → estado deseado,
- deriva a los comandos/skills de perfil existentes (`profile-onboarding`,
  `personal-vault`) para persistir,
- output: `output/onboarding/{usuario}-{fecha}.json` con respuestas
  estructuradas.

### S2 — Install-by-prompt

- comando `/setup` que: ejecuta la entrevista → muestra plan de cambios
  (perfil, projects/, config local) → aplica tras confirmación por paso,
- soporta el caso LifeOS "Read the install page and do it": un prompt natural
  enruta a `/setup` sin fricción,
- checklist de verificación post-setup (config válida, perfil activo,
  proyectos detectados).

---

## Criterios de aceptacion

### AC-S1: Entrevista

- [ ] AC-S1.1: `/setup` recoge identidad, proyectos y preferencias en ≤2
  minutos de interacción (medido).
- [ ] AC-S1.2: las respuestas quedan en `output/onboarding/` y se reflejan en
  el perfil activo sin duplicar campos.

### AC-S2: Install

- [ ] AC-S2.1: el prompt natural "configúrame el workspace" enruta a `/setup`.
- [ ] AC-S2.2: cada cambio se aplica solo tras confirmación explícita.
- [ ] AC-S2.3: checklist post-setup verifica perfil + proyectos + config local.

---

## Ref

- `danielmiessler/LifeOS` → LifeOS/Workflows/Interview.md, install page
- `docs/rules/domain/profile-onboarding.md`, `.opencode/skills/onboarding-dev/SKILL.md`
