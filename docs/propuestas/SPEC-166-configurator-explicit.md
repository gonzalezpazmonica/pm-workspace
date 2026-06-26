---
id: SPEC-166
title: Explicit configurator agent (centralize System 2 dispatch)
status: IMPLEMENTED
priority: MEDIUM
estimated_hours: 8
tier: 2
origin: lecun-jepa-h-research-2026
---

# SPEC-166 Configurator Explicit

## Problema
El "configurador" en H-JEPA decide que sub-modulos activar para una tarea (que agentes, que skills, que reglas cargar, que memoria recuperar). En Savia hoy esta logica esta dispersa entre:

- `.claude/profiles/savia-identity.md` (carga estatica)
- `.claude/profiles/active-user.md` (perfil + memoria auto)
- Cada skill decide a quien delegar via Task
- Hooks que cargan reglas bajo demanda

Sin configurador explicito, no hay punto unico de decision ni telemetria de "que se cargo y por que" para cada turno.

## Solucion
Agente `configurator` (fast-tier) invocado al inicio de cada turno mode_2:

Inputs: prompt del usuario, perfil activo, memoria reciente, comando invocado
Outputs JSON: `{agents_to_invoke: [...], skills_to_load: [...], rules_to_attach: [...], memory_queries: [...], rationale: "..."}`

El orquestador principal consume el output y carga solo lo declarado. Esto:
- Reduce contexto cargado por turno (evita "cargar todo por si acaso")
- Permite auditar decisiones de dispatch
- Habilita A/B testing de estrategias de carga

## Slices
1. Agente configurator + schema de output JSON (2h)
2. Hook UserPromptSubmit que invoca configurator y guarda decision (3h)
3. Loader que respeta decision del configurator (skip resto) (2h)
4. Tests BATS + telemetria `output/configurator-decisions.jsonl` (1h)

## AC
- Configurator emite JSON valido en >= 95% de turnos
- Contexto cargado por turno mode_2 cae >= 20% vs baseline actual
- Telemetria registra: turn_id, decision, rationale, tokens_loaded
- Tests BATS score >= 80
- Fallback: si configurator falla, cargar contexto completo (degradacion segura)

## Riesgos
- Configurator omite carga critica → output peor
- Mitigacion: shadow mode 2 semanas (decide pero no aplica)
- Latencia adicional del turno (config = +1 LLM call)
- Mitigacion: solo se activa en mode_2 (gracias a SPEC-163)

## Out of scope
- Aprendizaje del configurator desde feedback (deferido, requiere SPEC-164)
- Configurator para skills dinamicas (v1 solo agents + rules)

## Origen
LeCun: el configurador es el modulo que orquesta. Sin el explicito, el sistema no puede razonar sobre su propia estrategia de carga.

## Trabajo relacionado
- Sinergico con SPEC-163 (router decide mode, configurator decide que cargar dentro de mode_2)
- Consume telemetria de SPEC-164 (memory feedback) para mejorar decisiones
