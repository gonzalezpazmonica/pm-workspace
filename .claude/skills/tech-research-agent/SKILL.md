---
name: tech-research-agent
description: Agente de investigación técnica autónoma — investiga temas, genera informes, notifica al humano designado
maturity: experimental
context: fork
agent: architect
category: "sdd-framework"
tags: ["research", "autonomous", "investigation", "reports"]
priority: "low"
---

# Skill: Tech Research Agent

> **Regla de seguridad**: `@.claude/rules/domain/autonomous-safety.md` — NO crea PRs, NO modifica código. Solo genera informes y recomendaciones.
> **Inspirado en**: Patrón `program.md` de [autoresearch](https://github.com/karpathy/autoresearch) — instrucciones declarativas para investigación autónoma.

## Cuándo usar esta skill

- Se necesita investigar un tema técnico (alternativas a una tecnología, benchmark de opciones, estado del arte)
- Se quiere auditar dependencias (CVEs, versiones desactualizadas, licencias incompatibles)
- Se busca un análisis comparativo para tomar una decisión arquitectónica informada
- El Tech Lead quiere delegar la fase de recopilación de información a un agente

## Qué produce

1. **Informe de investigación** — `output/research-{tema}-{YYYYMMDD}.md`
2. **Recomendaciones accionables** — incluidas en el informe, NUNCA ejecutadas automáticamente
3. **Audit log** — `output/agent-runs/research-{tema}-{YYYYMMDD}-audit.log`

**NO produce:** PRs, commits, cambios en código, tareas en el backlog.

## Prerequisitos

```
1. AUTONOMOUS_RESEARCH_NOTIFY configurado  → si no: ❌ ABORT
2. Tema de investigación definido           → si no: pedir al humano
```

## Flujo completo

```
Humano ejecuta /tech-research {tema} [--program {archivo.md}]
    ↓
Validar prerequisitos
    ↓
Cargar instrucciones:
  - Si --program: leer el research-program.md proporcionado
  - Si solo tema: generar plan de investigación y MOSTRAR AL HUMANO para aprobación
    ↓
[Humano confirma el plan]
    ↓
Ejecutar investigación (time-box: AGENT_TASK_TIMEOUT_MINUTES × 3):
  - Buscar documentación oficial
  - Analizar código del proyecto actual
  - Comparar alternativas con criterios definidos
  - Recopilar benchmarks públicos si aplica
  - Identificar riesgos y trade-offs
    ↓
Generar informe estructurado en output/
    ↓
Notificar a AUTONOMOUS_RESEARCH_NOTIFY:
  "📋 Investigación completada: {tema}
   Informe: output/research-{tema}-{fecha}.md
   Recomendaciones: {resumen de 2-3 líneas}"
```

## Estructura del informe

```markdown
# Investigación: {tema}
> Fecha: {YYYY-MM-DD} · Solicitado por: {humano} · Agente: tech-research-agent

## Contexto
Por qué se investiga, qué problema se busca resolver.

## Estado actual
Qué usa el proyecto actualmente, métricas relevantes.

## Alternativas evaluadas
Para cada alternativa: descripción, pros, contras, madurez, comunidad, licencia.

## Comparativa
Tabla resumen con criterios ponderados.

## Riesgos
Qué puede salir mal con cada opción, esfuerzo de migración.

## Recomendación
Opción preferida con justificación. SIEMPRE marcada como "propuesta pendiente de decisión humana".

## Fuentes
Enlaces a documentación, benchmarks, artículos consultados.

## Próximos pasos sugeridos
Acciones concretas SI el humano aprueba la recomendación.
```

## Research Programs (patrón program.md)

El humano puede proporcionar un archivo `research-program.md` con instrucciones específicas:

```markdown
# Research Program: Alternativas a Entity Framework

## Objetivo
Evaluar ORMs alternativos para .NET con mejor rendimiento en alta concurrencia.

## Criterios de evaluación
1. Rendimiento en queries complejas (joins, subqueries)
2. Soporte para batch operations
3. Madurez y comunidad
4. Curva de aprendizaje para el equipo
5. Compatibilidad con nuestro stack (SQL Server, Azure)

## Alternativas a evaluar
- Dapper
- RepoDB
- LINQ to DB
- Raw ADO.NET con Dapper

## Restricciones
- Debe soportar SQL Server y Azure SQL
- Debe tener soporte para .NET 8+
- Licencia: MIT, Apache 2.0 o similar

## Output esperado
Tabla comparativa + recomendación justificada + estimación de esfuerzo de migración.
```

## Restricciones estrictas

```
NUNCA → Modificar código del proyecto
NUNCA → Crear PRs
NUNCA → Crear tareas en el backlog
NUNCA → Instalar dependencias
NUNCA → Ejecutar código no seguro (solo análisis estático y búsqueda web)
NUNCA → Tomar decisiones — solo RECOMENDAR
SIEMPRE → Generar informe en output/
SIEMPRE → Notificar a AUTONOMOUS_RESEARCH_NOTIFY
SIEMPRE → Citar fuentes en cada afirmación
SIEMPRE → Marcar nivel de confianza (alto/medio/bajo) en cada recomendación
SIEMPRE → Si no encuentra evidencia, decirlo explícitamente
```

## Cuándo NO usar

- Para implementar cambios (usar SDD o code-improvement-loop) o acceso a sistemas con credenciales
- Si no hay AUTONOMOUS_RESEARCH_NOTIFY configurado o involucra datos sensibles del negocio
