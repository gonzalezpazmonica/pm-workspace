---
id: SPEC-122
title: LocalAI emergency-mode hardening — Anthropic API shim
status: IMPLEMENTED
origin: Savia autonomous roadmap — Top pick #3 del research 2026-04-17
author: Savia
related: SAVIA-SUPERPOWERS-ROADMAP.md
priority: alta
applied_at: "2026-04-25"
implemented_at: "2026-04-25"
era: 187
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

## Resolution (2026-04-25)

SPEC-122 completado en Era 187 (batch 54). Todos los 7 AC cumplidos:

- [x] AC-01 `scripts/localai-readiness-check.sh` — runnable, --json/--url/--model flags, exit codes 0/1/2
- [x] AC-02 `.claude/skills/emergency-mode/SKILL.md` — sección "Emergency Mode — Savia ↔ LocalAI Switchover" con `ANTHROPIC_BASE_URL` config y feature matrix cloud-vs-local
- [x] AC-03 `.claude/hooks/emergency-mode-readiness.sh` — SessionStart hook, feature-flag `EMERGENCY_MODE_ENABLED=true`, registrado en `.claude/settings.json` con timeout 12s
- [x] AC-04 `docs/rules/domain/emergency-mode-protocol.md` — protocolo activación/recuperación
- [x] AC-05 `docs/rules/domain/autonomous-safety.md` — sección "Emergency-mode (LocalAI fallback) — SPEC-122" añadida con prohibiciones explícitas (NUNCA bypass AUTONOMOUS_REVIEWER en emergency)
- [x] AC-06 `tests/test-emergency-mode-readiness.bats` — 30 tests certified score 94. Mock LocalAI script via `$CLAUDE_PROJECT_DIR/scripts/localai-readiness-check.sh`. Cubre verdict states (READY/WARN/FAIL/SKIP/TIMEOUT/UNKNOWN), feature-flag silencio, append accumulation, timeout (10s), edge cases. Nota: nombre real es `test-emergency-mode-readiness.bats` (per pm-workspace `test-X.bats` convention) en lugar de `localai-readiness.bats` propuesto. El test-localai-readiness-check.bats existente cubre el script bash separadamente.
- [x] AC-07 CHANGELOG entry — batch 54

Comportamiento del hook:
- Feature-flag OFF → skip silencioso (sin coste)
- Feature-flag ON + script missing → log SKIP, exit 0
- Feature-flag ON + script OK → ejecuta readiness, log verdict, surface FAIL/WARN to stderr
- Timeout 10s en script invocation, hook nunca bloquea SessionStart
- Logs append-only en `output/emergency-mode/readiness.jsonl` con ts ISO 8601 + verdict
