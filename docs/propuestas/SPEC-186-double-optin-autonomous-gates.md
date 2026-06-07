---
spec_id: SPEC-186
title: Double opt-in para gates autonomos (env var + flag explicito)
status: IMPLEMENTED
tier: 1
priority: P1
effort: 1-2h
era: 199
wave: 1
deps: []
unblocks: []
origin: output/research/obsidian-second-brain-mejoras-cupulas-20260601.md
inspiration: obsidian-second-brain politica "explicit + scoped" para acciones destructivas
timeline:
  - from: "2026-06-01"
    until: "2026-06-02"
    learned: "2026-06-01"
    value: "PROPOSED"
    source: "feat(roadmap): Era 199 -- 7 SPECs from obsidian-second-brain analysis (#794)"
  - from: "2026-06-02"
    learned: "2026-06-02"
    value: "IMPLEMENTED"
    source: "feat(spec-186): double opt-in for autonomous skills Era 199 Wave 1 (#796)"
---

# SPEC-186 — Double opt-in para gates autonomos

> Estado: PROPOSED · Tier 1 · P1 · Estimacion 1-2h · Era 199 · Wave 1

## Resumen

Skills autonomas (overnight-sprint, code-improvement-loop, adversarial-security, tech-research-agent) requieren DOS confirmaciones independientes para arrancar: variable de entorno persistente Y flag explicito en la invocacion. Cierra el vector de activacion accidental por env var heredada.

## Motivacion

- Hoy basta con que una env var este `=true` para que un agente autonomo arranque sin gate adicional.
- Riesgo: env var heredada de sesion previa (especialmente en shells persistentes o CI) activa skill destructiva sin intencion.
- Patron obsidian: acciones destructivas requieren confirmacion explicita en cada invocacion, no solo configuracion previa.

## Scope

1. Helper `scripts/savia-double-optin-check.sh` que valida:
   - Variable persistente correcta (cada skill define la suya).
   - Flag `--confirm-autonomous` presente en argv.
2. Skills protegidas: overnight-sprint, code-improvement-loop, adversarial-security, tech-research-agent, savia-dual (failover).
3. Si falta cualquiera de las dos confirmaciones, skill aborta con mensaje claro:
   ```
   ERROR: Doble opt-in requerido.
     Necesitas (1) variable persistente y (2) flag --confirm-autonomous.
     Razon: prevenir activacion accidental por env heredada.
   ```
4. Logging en `output/agent-runs/optin-audit.log` de cada arranque con timestamp + usuario + skill + ambos factores.
5. Bypass test-only via `SAVIA_TESTING=1` documentado solo en codigo de tests.

## Acceptance Criteria

- AC1: Helper acepta exit 0 si ambas confirmaciones presentes, exit 1 si falta cualquiera.
- AC2: overnight-sprint sin flag `--confirm-autonomous` aborta aunque env var este set.
- AC3: overnight-sprint con flag pero sin env var aborta.
- AC4: overnight-sprint con ambos arranca normalmente.
- AC5: Log de auditoria registra los 4 campos (timestamp, usuario, skill, factores).
- AC6: BATS cubre las 4 combinaciones (00, 01, 10, 11) para 2 skills representativas.
- AC7: Mensaje de error indica exactamente cual de los dos factores falta.
- AC8: `SAVIA_TESTING=1` permite bypass solo si el caller es un test bats reconocido.

## Slices

1. **Slice 1 (0.5h)** — Helper shell + tests unitarios.
2. **Slice 2 (0.5-1h)** — Integracion en 5 skills + logging.
3. **Slice 3 (0.5h)** — BATS combinaciones + doc en `docs/rules/domain/autonomous-safety.md` (apendice).

## Out of scope

- Confirmacion interactiva TUI (v1 solo flag + env).
- Re-confirmacion periodica durante ejecucion (v1 solo al arranque).
- Integracion con sistemas externos de aprobacion (Slack, email).
