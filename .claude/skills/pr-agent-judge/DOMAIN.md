# PR Agent Judge — Dominio

## Por que existe esta skill

El Code Review Court de pm-workspace usa 4 jueces internos (correctness, security, architecture, cognitive) — todos del mismo linaje (agentes Claude + prompts propios). Esa homogeneidad es un punto ciego: errores que los 4 comparten (sesgos del mismo modelo base, ciegos ante el mismo tipo de bug) pasan el tribunal. Esta skill introduce un 5º juez externo (qodo-ai/pr-agent) con benchmark publico (60.1% F1 en detección de bugs), opt-in, para añadir diversidad de criterio. La heterogeneidad de jueces es el mecanismo que reduce false-negatives del tribunal.

## Cuando usar

Activar cuando:
- Court está convocado sobre un PR no trivial (>100 LOC)
- `COURT_INCLUDE_PR_AGENT=true` en `pm-config.md` o `pm-config.local.md`
- El PR toca código crítico de negocio o seguridad (donde el coste de un false-negative del Court es alto)

NO usar cuando:
- Test-only PR (tests no mueven la aguja del Court; añadir juez externo es overhead sin valor)
- Doc-only PR (igual)
- Emergency hotfix (la ventana de tiempo no justifica el roundtrip adicional)

## Limites

- Dependencia externa: qodo-ai/pr-agent es OSS pero requiere `pip install` (~150 MB con deps). Aislado en virtualenv dedicado — NO contamina el entorno global
- Latencia adicional: +30-90s por revisión de PR medio (variable según tamaño)
- Costo de API: consume tokens del proveedor configurado en pr-agent (OpenAI/Anthropic/local) — puede duplicar el coste de revisión del Court
- Formato: pr-agent emite su propio schema JSON; el wrapper normaliza a formato Court pero algunas observaciones quedan como `notes` no estructuradas

## Confidencialidad

El wrapper ejecuta `pr-agent` localmente contra el diff del PR. Si `pr-agent` está configurado con LLM de terceros (OpenAI API), el diff se envía a ese proveedor — auditar antes de activar en repos con PII o N2+.

Para uso zero-egress: configurar `pr-agent` contra LocalAI/Ollama local. Documentado en SPEC-124 y `docs/rules/domain/pr-agent-integration.md`.

## Outputs

Todo output va a formato JSON estándar Court:
- `judge`: "pr-agent"
- `verdict`: PASS | FAIL | NEEDS_REVIEW
- `findings`: [{category, severity, file, line, message}]
- `metadata`: {version, f1_benchmark, latency_ms, cost_tokens}

El Court-orchestrator agrega este verdict con los otros 4 jueces y produce el veredicto final — NO merge autónomo, respeta Rule #8.

## Referencias

- SKILL.md (este directorio) — protocolo de invocación y comandos
- SPEC-124: `docs/propuestas/SPEC-124-pr-agent-wrapper.md`
- qodo-ai/pr-agent: https://github.com/qodo-ai/pr-agent
- Code Review Court: `.claude/skills/code-review-court/`
