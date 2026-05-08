# Court External Judges Policy — SPEC-124

> Política para incluir jueces externos (OSS o de terceros) en el Code Review Court de Savia. Diversidad de criterio sin lock-in.

## Por qué un juez externo

El Court interno tiene 4 jueces (correctness, security, architecture, cognitive). Los 4 corren bajo el mismo modelo y misma instrucción base — riesgo de **sesgo compartido**: si los 4 ignoran el mismo edge case, nadie lo cataliza.

Un 5º juez **independiente** (modelo distinto, prompt distinto, autor distinto) reduce el sesgo común. Si los 5 acuerdan, la confianza es real. Si el 5º discrepa, se aprende.

## Política de inclusión

| Requisito | Verificación |
|---|---|
| OSS auditable (license MIT/Apache/BSD) | Repo público + license file |
| Self-hostable (no API obligatoria de un proveedor único) | Docker o instalable local |
| Versión pinable | Semver tags o commit SHA |
| Output schema validable | Test bats con mock + schema |
| Opt-in (default disabled) | Feature flag en `pm-config.md` |
| Tag distintivo en comentarios | `[pr-agent]`, `[external-X]`, etc. |
| Respeta AUTONOMOUS_REVIEWER | No auto-merge, no aprobación final |

## Jueces aprobados

| Juez | Origen | Versión | Activación |
|---|---|---|---|
| `pr-agent-judge` | qodo-ai/pr-agent (Apache 2.0) | `PR_AGENT_VERSION` | `COURT_INCLUDE_PR_AGENT=true` |

## Reglas de operación

1. **Veredicto consultivo, no veto.** El juez externo emite verdict + findings. Court interno los lee, los pondera, decide. El externo NO tiene derecho de veto.
2. **No bloquea CI por defecto.** Si el juez externo falla (network, API key faltante, version mismatch), CI continúa con 4 jueces. Falla graceful.
3. **Comments tagged.** Comentarios PR del juez externo deben llevar prefijo `[pr-agent]` (o el tag correspondiente) para distinguir del Court interno.
4. **Cost gate.** Cada juez externo declara `MAX_LINES` o equivalente. Diff superior → skip silencioso con `::notice::` en CI.
5. **Skip on draft.** Solo se invoca en PRs no-draft. Drafts evolucionan; revisión externa malgasta tokens.
6. **Conflict resolution.** Si externo y interno discrepan en `verdict`, `court-orchestrator` documenta ambos en `.review.crc` y eleva al humano. NUNCA bypass automático.

## Activación paso a paso

1. Habilitar flag en `docs/rules/domain/pm-config.md`:
   ```
   COURT_INCLUDE_PR_AGENT = true
   PR_AGENT_VERSION       = "0.27"
   PR_AGENT_MODEL         = "claude-sonnet-4-6"
   ```

2. Configurar workflow en `.github/workflows/pr-agent-review.yml` (usa template):
   ```yaml
   jobs:
     review:
       uses: ./.github/workflows/templates/pr-agent-review.yml
       secrets: inherit
   ```

3. Configurar secrets en GitHub repo: `ANTHROPIC_API_KEY` o `OPENAI_API_KEY`.

4. Verificar con un PR de prueba — `[pr-agent]` debe aparecer en comments.

## Desactivación

Cambiar flag a `false`. Siguiente PR no invoca al externo. Comments previos persisten — borrarlos manualmente si se quieren limpiar.

## Auditoría

`court-orchestrator` registra en `output/court/{run-id}.json` el verdict de cada juez (interno + externo). Drift de schema externo → bats test falla → CI bloquea hasta repinear o desactivar el juez.

## Riesgos documentados

| Riesgo | Mitigación |
|---|---|
| Token cost en PRs grandes | `MAX_LINES` cap (default 1000) |
| Externo requiere API key del usuario | Secrets en repo + graceful skip |
| Output schema cambia entre versiones | Pin version + bats schema test |
| Conflicto con Court interno | Documentar ambos veredictos, no auto-resolver |
| Datos del PR enviados a tercero | Solo OSS self-hostable; revisar política privacy del juez |

## Referencias

- `SPEC-124` — pr-agent wrapper como 5º juez
- `.opencode/agents/court-orchestrator.md` — orchestrator del Court
- `.github/workflows/templates/pr-agent-review.yml` — workflow reusable
- `scripts/pr-agent-run.sh` — wrapper CLI
- `docs/agent-teams-sdd.md` — Court arquitectura interna (4 jueces)
