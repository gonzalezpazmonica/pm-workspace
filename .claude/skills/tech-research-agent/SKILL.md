---
name: tech-research-agent
description: Agente de investigación técnica autónoma — investiga temas, genera informes, notifica al humano designado
summary: |
  Agente de investigacion tecnica autonoma: investiga temas,
  genera informes y notifica al humano designado.
  Output: informe en output/research-*. Rama agent/research-*.
maturity: experimental
context: fork
agent: architect
category: "sdd-framework"
tags: ["research", "autonomous", "investigation", "reports"]
priority: "low"
---

# Skill: Tech Research Agent

> **Regla de seguridad**: `@docs/rules/domain/autonomous-safety.md` — NO crea PRs, NO modifica código. Solo genera informes y recomendaciones.
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

El humano puede proporcionar `research-program.md` con: objetivo, criterios de evaluación, alternativas a evaluar, restricciones (licencia, stack, versiones), y formato de output esperado. Ver `docs/propuestas/` para ejemplos reales.

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

## Fallback de fetch (SE-061)

Cuando `WebFetch` tool devuelve 403/429/503 o contenido vacío sobre una URL que se está investigando, la skill debe invocar el wrapper `scripts/scrapling-fetch.sh` como fallback adaptativo:

```bash
bash scripts/scrapling-fetch.sh "https://ejemplo-cloudflare.com/docs" --json --timeout 25
```

- Si Scrapling está instalado: bypass nativo de Cloudflare/DataDome/Akamai/Kasada/Incapsula
- Si Scrapling NO está instalado: fallback transparente a curl con user-agent `SaviaResearch/1.0`
- Salida JSON con `status`, `title`, `url_final`, `text`, `backend`
- Exit code 0 = OK, 1 = fetch error, 2 = usage error

Ver `docs/rules/domain/research-stack.md` para la cadena completa de backends y las consideraciones de legalidad/ToS.
