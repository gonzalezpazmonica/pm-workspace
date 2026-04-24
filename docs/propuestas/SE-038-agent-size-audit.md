---
id: SE-038
title: Agent catalog size audit — Rule #22 compliance 65 agentes <4KB
status: APPROVED
origin: ROADMAP-UNIFIED-20260418 Wave 4 D3 + Rule #22 enforcement
author: Savia
related: .claude/agents/, docs/rules/domain/critical-rules-extended.md
approved_at: null
applied_at: null
expires: "2026-06-18"
priority: alta
---

# SE-038 — Agent catalog size audit

## Purpose

Si NO hacemos esto: Rule #22 (critical-rules-extended.md) exige que cada definición de agente (frontmatter + descripción) sea <4KB para no inflar contexto en cada selección. Tenemos 65 agentes — NO sabemos cuántos violan el SLA. Cada vez que el dispatcher carga catálogo (hot path de selección de agente en cualquier /agent-run), todos los agentes se leen. 1 agente a 8KB × 65 = 520KB × sesión = ruido medible en TTFT.

Cost of inaction: el catálogo crece sin medir. Nuevos agentes copian patrones de los que ya exceden. Drift progresivo hasta que el sistema degrade notablemente. El gap se descubre como incidente, no como métrica.

## Objective

**Único y medible**: auditar los 65 agentes contra SLA Rule #22 (<4KB cada uno). Criterio: `scripts/agent-size-audit.sh` reporta compliance + lista violaciones, y post-fix hay 0 agentes >4KB (o justificación explícita documentada por agente).

## Slicing

### Slice 1 — Measurement tool (1h)

- `scripts/agent-size-audit.sh`: scanea `.claude/agents/*.md`, mide bytes + tokens estimados (chars ÷ 4)
- Output: `output/agent-size-audit-{date}.md` con tabla ordenada por tamaño
- Exit code: 1 si algún agente >4KB sin justificación documentada

### Slice 2 — Remediation (3h, depends #violations)

Por cada agente >4KB:
- Opción A: split en sub-agentes especializados
- Opción B: mover prose a DOMAIN.md equivalente en skills (si hay skill relacionado)
- Opción C: documentar excepción en frontmatter (`size_exception: <motivo>`)
- Opción D: comprimir prose (eliminar redundancias)

Metric: reducir tamaño agregado del catálogo en >=20%.

### Slice 3 — Enforcement gate (30min)

- Añadir a `ci-extended-checks.sh` check #10: agent-size-audit pasa sin violaciones
- Blocking en pr-plan.sh G5b

### Slice 4 — Tests BATS (1h)

- `tests/test-agent-size-audit.bats` con 15+ tests (sandbox, edge cases)

## Acceptance Criteria

- [ ] AC-01 `scripts/agent-size-audit.sh` operativo con output estructurado
- [ ] AC-02 Zero agentes >4KB sin justificación explícita
- [ ] AC-03 Catálogo agregado reduce ≥20% bytes
- [ ] AC-04 ci-extended-checks.sh check #10 instalado y verde
- [ ] AC-05 Tests BATS 15+ con auditor score ≥80
- [ ] AC-06 Doc actualización en Rule #22 con métricas reales

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Remediation perjudica calidad del agente | Snapshot antes/después + review humano por agente crítico |
| Nuevas excepciones legítimas (agentes complejos) | Permitir `size_exception:` en frontmatter con explicación |
| SLA 4KB es arbitrario | Medir impacto real en TTFT antes de fix — si <2% degrade, reconsiderar SLA |

## Aplicación Spec Ops

- **Simplicity**: 4KB por agente, una métrica
- **Probe**: Slice 1 es el probe — si 0 violaciones, abort spec (no hay deuda)
- **Speed**: 4 slices, 3 de ellos ≤1h

## Referencias

- Rule #22: `docs/rules/domain/critical-rules-extended.md`
- Agent catalog: `.claude/agents/`
- ROADMAP-UNIFIED-20260418 §Wave 4 D3

## Dependencia

Independiente. Priorizado alto si Slice 1 (probe) encuentra >5 violaciones; bajo si encuentra 0-2.
