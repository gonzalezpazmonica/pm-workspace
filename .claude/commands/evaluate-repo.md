---
name: evaluate-repo
description: >
  Evaluación estática de seguridad y calidad de un repositorio externo.
  Puntuación 1-10 en 6 categorías con veredicto final.
---

# Evaluación de Repositorio Externo

**Repositorio:** $ARGUMENTS

> Si no se pasa argumento, evalúa el repositorio actual.

## Instrucciones

1. **NO ejecutes código** — solo inspección estática
2. Clona a `/tmp/eval-repo-$(date +%s) --depth 1`
3. Lee: README, CLAUDE.md, package.json, *.csproj, hooks, commands, scripts, configs

## Criterios (1-10 cada uno)

1. **Calidad de código** — estructura, legibilidad, consistencia
2. **Seguridad** — ejecución implícita, filesystem, red, credenciales, escalación
3. **Documentación** — transparencia, side effects documentados, coincide con implementación
4. **Funcionalidad** — cumple scope declarado
5. **Higiene del repo** — mantenibilidad, licencia, calidad de publicación
6. **Compatibilidad pm-workspace** — Hexagonal/DDD, convenciones .NET, github-flow, no conflicto con agentes/skills

## Checklist Claude Code

Responder a cada punto: hooks (stop/lifecycle/pre-post-commit), shell scripts, estado persistente, acciones implícitas sin confirmación, defaults seguros (opt-in), mecanismo de desactivación.

## Análisis de permisos

- **Declarados** (docs/config) vs **Inferidos** (inspección) → marcar: confirmado/probable/incierto
- Listar discrepancias

## Red flags

Verificar: malware, ejecución implícita no documentada, actividad de red no documentada, claims falsos, supply-chain, auto-updates.

## Informe

Generar informe con puntuaciones, media global, y veredicto:
- ✅ RECOMENDAR | 🟡 CON RESERVAS | 🔍 REVISIÓN MANUAL | 🔴 RECHAZAR

Si RECHAZAR → indicar heurística: malicioso, ejecución de alto riesgo, discrepancia severa, defaults inseguros.

## Restricciones

- NUNCA instalar dependencias ni ejecutar código
- NUNCA aprobar automáticamente — es recomendación al humano
- Si duda entre 🟡 y 🔴 → elevar a 🔴
- Limpiar: `rm -rf /tmp/eval-repo-*`
