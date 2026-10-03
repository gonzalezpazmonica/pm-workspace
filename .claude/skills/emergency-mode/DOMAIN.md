# emergency-mode — DOMAIN

## Dominio: Resilience / Sovereignty

Cubre el escenario de cloud-down donde Savia debe continuar operando con infraestructura local (LocalAI v3.10+).

## Concepts canónicos

- **Cloud endpoint**: API de Anthropic (api.anthropic.com).
- **Emergency endpoint**: LocalAI en `http://localhost:8080` (sirve `/v1/messages`, compatibilidad Anthropic API).
- **Switchover**: `ANTHROPIC_BASE_URL` a la base sin `/v1` (Claude Code añade `/v1/messages`) más `ANTHROPIC_MODEL` y `ANTHROPIC_SMALL_FAST_MODEL` con un id cargado en LocalAI.
- **Readiness**: estado validado del stack local antes del switchover.

## Invariantes

1. El switchover NUNCA bypass Rule #8 (AUTONOMOUS_REVIEWER sigue aplicando).
2. El switchover NUNCA es automático — decisión humana.
3. El readiness check se ejecuta ANTES del switchover, no después.
4. Features cloud-only (web search, MCP remotos) se reportan como NO DISPONIBLES en el skill output.

## Métricas de salud

- LocalAI uptime durante emergency (medido por `localai-readiness-check.sh`).
- Delta productividad vs cloud (estimado ~40% degradación).
- Tiempo de vuelta a cloud una vez restaurado.

## Referencias

- SPEC-122
- SPEC-SE-027 (SLM training local)
- `scripts/localai-readiness-check.sh`
