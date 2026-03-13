---
name: code-improve
description: Launch autonomous code improvement loop — detects opportunities, applies improvements, creates PRs for review
---

# /code-improve

Lanza un bucle autónomo de mejora de código inspirado en autoresearch. Detecta oportunidades, aplica mejoras medibles, y genera PRs pendientes de revisión humana.

## 1. Cargar configuración

1. Leer `@.claude/rules/domain/autonomous-safety.md` — reglas de seguridad (OBLIGATORIO)
2. Leer `@.claude/rules/domain/pm-config.md` + `pm-config.local.md`
3. Leer `.claude/skills/code-improvement-loop/SKILL.md`

## 2. Uso

```
/code-improve [--project {nombre}] [--scope {path}] [--tipo {coverage|complexity|lint|deps|todos|all}] [--max-tasks {n}] [--dry-run]
```

- `--project`: Proyecto específico (default: proyecto activo)
- `--scope`: Limitar a una ruta específica (default: todo el proyecto)
- `--tipo`: Tipo de mejora (default: `all`)
- `--max-tasks`: Máximo de mejoras a intentar
- `--dry-run`: Solo detectar oportunidades sin aplicar

## 3. Gate de arranque

```
✅ AUTONOMOUS_REVIEWER configurado    → si no: ❌ ABORT
✅ Tests del proyecto pasan            → si no: ❌ "Baseline roto"
```

## 4. Detección y confirmación

Mostrar oportunidades detectadas:

```
🔄 Code Improvement Loop — {proyecto}

📊 Métricas baseline:
  Cobertura: 67.3%
  Complejidad máx: 18 (src/api/handler.ts)
  Warnings linter: 42
  TODOs sin ticket: 8
  Deps desactualizadas: 3

📋 Oportunidades detectadas: {n}
  1. [coverage] src/auth/ — cobertura 42% → objetivo 80%
  2. [complexity] src/api/handler.ts — complejidad 18 → objetivo ≤10
  3. [lint] src/ — 42 warnings corregibles
  ...

👤 Reviewer: {AUTONOMOUS_REVIEWER}
⏱️ Time-box por tarea: {AGENT_TASK_TIMEOUT_MINUTES} min

¿Confirmar arranque? (s/n)
```

## 5. Output

```
🔄 Code Improvement — Completado

✅ PRs creados: {n}
⚠️ Descartados (métricas no mejoraron): {n}
❌ Crashes: {n}

📊 Mejoras propuestas:
  Cobertura: 67.3% → 78.1% (+10.8%) [3 PRs]
  Complejidad máx: 18 → 12 (-6) [1 PR]
  Warnings: 42 → 15 (-27) [2 PRs]

📄 Resultados: output/improvement-results-{fecha}.tsv
📝 Audit log: output/agent-runs/improvement-{fecha}-audit.log

⚡ /compact
```
