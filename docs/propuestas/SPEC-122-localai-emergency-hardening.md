---
id: SPEC-122
title: LocalAI emergency-mode hardening — Anthropic API shim
status: PROPOSED
origin: Savia autonomous roadmap — Top pick #3 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
---

# SPEC-122 — LocalAI Emergency-Mode Hardening

## Why

LocalAI v3.10.0 (Ene 2026) añadió **compatibilidad Anthropic API** — expone `/v1/messages` drop-in para Claude. Cuando la API de Anthropic cae (y cae), Savia puede seguir operando con **el mismo comando** solo cambiando `ANTHROPIC_BASE_URL`.

Savia ya tiene `/emergency-mode` skill y SE-027 (local SLM). Lo que falta:
1. Docs claros del switchover a LocalAI
2. Detección automática del escenario "cloud down"
3. Validación del setup local antes de la crisis

El valor: **sovereignty end-to-end en escenario real de caída**.

## Scope

1. **Actualizar** `.claude/skills/emergency-mode/SKILL.md` con sección LocalAI:
   - Install path
   - Config `ANTHROPIC_BASE_URL=http://localhost:8080/v1`
   - Modelos Anthropic-compatibles disponibles

2. **Script** `scripts/localai-readiness-check.sh`:
   - Verifica LocalAI running en localhost:8080
   - Verifica modelo Claude-compatible disponible
   - Reporta estado OK/WARN/FAIL

3. **Hook** `.claude/hooks/emergency-mode-readiness.sh` que ejecuta el readiness check en SessionStart si `EMERGENCY_MODE_ENABLED=true`.

4. **Docs** `docs/rules/domain/emergency-mode-protocol.md`:
   - Cuándo activar (API Anthropic caída > X min)
   - Cómo activar (`/emergency-mode activate`)
   - Qué se pierde (features cloud-only)
   - Cómo volver a cloud

5. **Update** `autonomous-safety.md` para documentar que emergency-mode NO bypass los gates (AUTONOMOUS_REVIEWER sigue aplicando).

## Design

### Switchover UX

```bash
# Usuario detecta caída de Anthropic
/emergency-mode activate

# Savia responde:
🦉 Modo emergencia activado.
   LocalAI endpoint: http://localhost:8080/v1
   Modelo activo: llama-4-maverick (Anthropic-compat)
   Features desactivadas: web search, gmail MCP, gcal MCP
   Ratio token/velocidad: ~60% de cloud.

# Trabaja como siempre. Cuando cloud vuelve:
/emergency-mode deactivate
```

### Readiness check output

```
=== LocalAI Readiness Check ===
[OK]   LocalAI running on localhost:8080
[OK]   Anthropic API compatibility v3.10.0+
[OK]   Model 'claude-4-haiku-local' loaded (4.8 GB)
[WARN] Model 'claude-4-opus-local' not loaded — download 34 GB?
[OK]   Disk space sufficient (256 GB free)
[OK]   RAM sufficient (64 GB total)

Estado: READY (1 warning — ver arriba)
```

## Acceptance Criteria

- [ ] AC-01 `scripts/localai-readiness-check.sh` crea un binary check runnable
- [ ] AC-02 `.claude/skills/emergency-mode/SKILL.md` incluye sección LocalAI configuration
- [ ] AC-03 `.claude/hooks/emergency-mode-readiness.sh` hook ejecuta readiness en SessionStart si feature-flag on
- [ ] AC-04 `docs/rules/domain/emergency-mode-protocol.md` creado
- [ ] AC-05 `docs/rules/domain/autonomous-safety.md` actualizado nota: emergency-mode respeta AUTONOMOUS_REVIEWER
- [ ] AC-06 Test bats `tests/localai-readiness.bats` verifica script (mock LocalAI endpoint)
- [ ] AC-07 CHANGELOG entry

## Agent Assignment

Capa: Infrastructure + skills + hooks
Agente: infrastructure-agent + tech-writer

## Slicing

- Slice 1: `localai-readiness-check.sh` + mock tests
- Slice 2: Update `/emergency-mode` skill + hook
- Slice 3: Docs protocol + autonomous-safety update + CHANGELOG

## Feasibility Probe

Time-box: 60 min. Riesgo principal: Endpoint LocalAI puede variar por versión. Mitigación: script parametrizado `LOCALAI_URL` env, default `localhost:8080`.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Hook añade latencia SessionStart | Media | Medio | Hook opcional (feature-flag), skip si no habilitado |
| LocalAI API changes rompen compat | Baja | Alto | Pinear versión mínima v3.10.0 en readiness check |
| Emergency-mode actuación incorrecta en cloud-OK | Baja | Alto | Doble check: verificar cloud down antes de activar |

## Referencias

- [mudler/LocalAI v3.10.0](https://github.com/mudler/LocalAI)
- Research report — top pick #3
- SE-027 local SLM fine-tuning (Unsloth + Ollama)
