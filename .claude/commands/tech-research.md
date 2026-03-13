---
name: tech-research
description: Launch autonomous technical research — investigates topics, generates reports, notifies designated human
---

# /tech-research

Lanza un agente de investigación técnica autónoma. Investiga el tema indicado y genera un informe con recomendaciones para revisión humana.

## 1. Cargar configuración

1. Leer `@.claude/rules/domain/autonomous-safety.md` — reglas de seguridad (OBLIGATORIO)
2. Leer `@.claude/rules/domain/pm-config.md` + `pm-config.local.md`
3. Leer `.claude/skills/tech-research-agent/SKILL.md`

## 2. Uso

```
/tech-research {tema} [--program {archivo.md}] [--project {nombre}]
```

- `{tema}`: Tema a investigar (obligatorio)
- `--program`: Archivo research-program.md con instrucciones detalladas
- `--project`: Proyecto de contexto (default: proyecto activo)

Ejemplos:
```
/tech-research "Alternativas a Entity Framework para alta concurrencia"
/tech-research "Estado actual de Blazor vs React para SPAs" --project mi-proyecto
/tech-research --program docs/research-programs/orm-evaluation.md
```

## 3. Gate de arranque

```
✅ AUTONOMOUS_RESEARCH_NOTIFY configurado  → si no: ❌ "Configura AUTONOMOUS_RESEARCH_NOTIFY"
✅ Tema o program definido                   → si no: ❌ "Indica tema o --program"
```

## 4. Plan de investigación

Si no se proporciona `--program`, generar plan y mostrar:

```
🔍 Tech Research — {tema}

📋 Plan de investigación:
  1. Analizar estado actual del proyecto
  2. Identificar alternativas viables
  3. Comparar con criterios técnicos
  4. Evaluar riesgos y esfuerzo de migración
  5. Generar recomendación con nivel de confianza

👤 Notificar a: {AUTONOMOUS_RESEARCH_NOTIFY}
⏱️ Tiempo estimado: {AGENT_TASK_TIMEOUT_MINUTES × 3} min

¿Confirmar investigación? (s/n)
```

## 5. Output

```
🔍 Tech Research — Completado

📄 Informe: output/research-{tema}-{fecha}.md
👤 Notificado: {AUTONOMOUS_RESEARCH_NOTIFY}

Recomendación (resumen):
  {2-3 líneas con la recomendación principal y nivel de confianza}

⚠️ Todas las recomendaciones son propuestas pendientes de decisión humana.

⚡ /compact
```
