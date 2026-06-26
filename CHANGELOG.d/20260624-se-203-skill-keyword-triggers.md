# SE-203 — Keyword triggers para skills

Date: 2026-06-24
Spec: docs/propuestas/SE-203-skill-keyword-triggers.md
Status: APPROVED -> IMPLEMENTED

## Ficheros

- scripts/skill-keyword-detector.sh — deteccion case-insensitive; --list, --json
- .opencode/skills/adversarial-security/SKILL.md — trigger.keywords anadido
- docs/rules/domain/skill-trigger-map.md — tabla actualizada
- .claude/settings.json — PreTurn hook (async, default OFF via SAVIA_SKILL_TRIGGERS)
- tests/scripts/test_se203_skill_keyword_detector.py — 8 tests

## ACs cubiertos

- AC1: "quiero hacer tdd" -> ["tdd-vertical-slices"]
- AC2: 10 skills anotados con trigger.keywords
- AC3: skill-trigger-map.md con formato tabla
- AC4: deteccion case-insensitive
- AC5: multi-match: "spec de seguridad" -> spec-driven-development + otros
- AC6: --list muestra tabla de triggers

## Notas

security-guardian no existe como skill (es un agente). Se anoto adversarial-security.
Hook PreTurn es async y default OFF (opt-in SAVIA_SKILL_TRIGGERS=true).
