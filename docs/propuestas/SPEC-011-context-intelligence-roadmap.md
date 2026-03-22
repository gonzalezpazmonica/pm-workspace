# SPEC-011: Roadmap Unificado — pm-workspace + Savia + SaviaClaw

> Status: **ACTIVE** · Fecha: 2026-03-22
> Ultima actualizacion: 2026-03-22 (post-merge v3.25.1)

---

## Estado actual

| Area | Version | Estado |
|------|---------|--------|
| pm-workspace core | v3.25.1 | 496 commands, 82 skills, 46 agents, 22 hooks |
| Savia Web | Phase 2.5 | Chat SSE, backlog tree+kanban, i18n, file browser |
| SaviaClaw | v1.0 prep | Serial+WiFi, LCD, brain bridge, daemon, savia-voice v2.4 |
| Robotics | Fase 2 | ESP32 MicroPython, safety rules, language pack |

---

## Tier 1 — COMPLETADO

| # | Spec | Que | Estado |
|---|------|-----|--------|
| 1 | SPEC-015 | Context Gate (6 bypass conditions) | DONE |
| 2 | SPEC-012 | L0/L1/L2 progressive loading (20 skills con L1) | Phase 1 DONE |
| 3 | Era21-WS4 | Script hardening (13/13 bugs: 6 criticos + 7 medium) | DONE |

---

## Tier 2 — Phase 1 COMPLETADO

| # | Spec | Que | Estado |
|---|------|-----|--------|
| 4 | SPEC-013 | Session memory extraction (rule-based protocol) | Phase 1 DONE |
| 5 | SPEC-016 | Intelligent compact (pre-compact extraction) | Phase 1 DONE |
| 6 | SPEC-010 N1 | SaviaClaw estabilidad (WiFi auto, heartbeat) | Pendiente |

Phase 2 de SPEC-013/016 (hook automatico) pendiente de acceso a transcript desde Stop hooks.

---

## Tier 3 — EN CURSO (sprints 5-7)

| # | Spec | Que | Esfuerzo | Estado |
|---|------|-----|----------|--------|
| 7 | SPEC-014 | Competence model en perfiles | 3 sprints | Phase 1 DONE (adaptive-output integration) |
| 8 | Era21-WS2 | Git Persistence Engine (indices TSV) | 2 sprints | Pendiente |
| 9 | Era21-WS7 | Savia Flow git-native | 2 sprints | Pendiente (dep: WS2) |
| 10 | SPEC-010 N2 | SaviaClaw proactividad | 1 sprint | Pendiente (dep: N1) |
| 11 | SPEC-017 F1-F3 | Sovereignty USB offline | 2 sprints | Spec DONE + sovereignty-pack.sh DONE |

---

## Tier 4 — Planificado (sprints 8-12)

| # | Spec | Que | Esfuerzo | Deps | Estado |
|---|------|-----|----------|------|--------|
| 12 | Savia Web P3 | Chat multi-thread, user mgmt, ACL | 3 sprints | — | Pendiente |
| 13 | SPEC-010 N3 | SaviaClaw voz avanzada | 2 sprints | N2 | Parcial (savia-voice v2.4 cubre streaming+barge-in, falta meeting mode) |
| 14 | Era21-WS5 | Travel Mode (USB pack/unpack) | 1 sprint | WS4, SPEC-017 | Pendiente |
| 15 | SPEC-017 F4 | SaviaOS booteable (Ubuntu live USB) | 2 sprints | F1-F3 | Diseno DONE |
| 16 | SPEC-003 | Web research system | 2 sprints | — | Pendiente |
| 17 | Era21-WS1 | Savia School v1 | 3 sprints | WS2, WS4 | Pendiente |

---

## Tier 5 — Horizonte (sprints 13+)

| # | Spec | Que | Deps |
|---|------|-----|------|
| 18 | SPEC-010 N4 | BT audio bidireccional (HFP AG) | N3 |
| 19 | SPEC-008 | Meeting digest con speaker diarization | N3 |
| 20 | SPEC-009 | Savia en Teams (Graph API bot) | N3 |
| 21 | SPEC-010 N5 | Guardiana de contexto autonoma | N4, SPEC-013 |
| 22 | SPEC-010 N6 | Multi-SaviaClaw mesh | N5 |
| 23 | Era21-WS1 v2 | Savia School v2 (security, GDPR) | WS1 v1 |
| 24 | Robotics F3 | Embedded Rust (Embassy, ESP-HAL) | Fase 2 |
| 25 | Robotics F4 | ROS2 integration | F3 |
| 26 | Robotics F5 | IA fisica (LeRobot) | F4 |

---

## Backlog de ideas (P4)

Se promueven a Tier cuando hay datos de uso que lo justifiquen.

| Idea | Origen | Trigger |
|------|--------|---------|
| Thompson Sampling profile loading | Fabrik-Codek | SPEC-014 muestra varianza |
| savia:// URI scheme | OpenViking | Handoffs fallan por rutas fragiles |
| Temporal decay en memory-store | Fabrik-Codek | memory-recall stale |
| Outcome inference para NL | Fabrik-Codek | logging manual insuficiente |
| Hybrid RAG agent memory | Fabrik-Codek | >500 entradas |
| Two-stage retrieval /nl-query | OpenViking | accuracy <80% en 3 sprints |
| Semantic drift detection | Fabrik-Codek | cambio frecuente de proyecto |
| U-Shape prompt positioning | Fabrik-Codek | agentes heavy ignoran final |
| Quality gate lessons.md | Fabrik-Codek | >30 entradas con ruido |

---

## Diagrama de dependencias

```
TIER 1 (DONE)                    TIER 2 (Phase 1 DONE)
SPEC-015 (Gate) ✓                SPEC-013 (Session Memory) ✓
SPEC-012 (L0/L1/L2) ✓           SPEC-016 (Smart Compact) ✓
Era21-WS4 (Scripts) ✓           SPEC-010 N1 (Estabilidad) ○

TIER 3 (EN CURSO)                TIER 4 (PLANIFICADO)
SPEC-014 (Competence) ✓p1       Savia Web P3 ○
Era21-WS2 (Git Persistence) ○   SPEC-010 N3 (Voz) ◐ ← N2
Era21-WS7 (Savia Flow) ○ ← WS2 Era21-WS5 (Travel) ○ ← WS4, 017
SPEC-010 N2 ○ ← N1              SPEC-017 F4 (SaviaOS) ○ ← F1-F3
SPEC-017 F1-F3 ✓spec+script     SPEC-003 (Web Research) ○
                                 Era21-WS1 (School) ○ ← WS2, WS4

✓ = done  ✓p1 = phase 1 done  ◐ = partial  ○ = pending
```

---

## Metricas de exito

| Metrica | Baseline | Actual | Objetivo | Spec |
|---------|----------|--------|----------|------|
| Tokens por sesion | ~80K | TBD | <50K | SPEC-012, 015 |
| Info perdida en /compact | ~30% | TBD | <5% | SPEC-013, 016 |
| Skills sugeridos irrelevantes | ~20% | TBD | <5% | SPEC-015 |
| Coaching accuracy | No medido | TBD | >80% | SPEC-014 |
| SaviaClaw uptime | ~80% | TBD | >99% | SPEC-010 N1 |
| Scripts bugs seguridad | 6 criticos | **0** | 0 | Era21-WS4 |

---

## Herramientas nuevas (esta sesion)

| Herramienta | Que hace |
|-------------|---------|
| `push-pr.sh` | CI + CHANGELOG + sign + push + PR + auto-merge en 1 comando |
| `sovereignty-pack.sh` | Descarga deps a cache, copia a USB (Tier 1-3) |
| `session-memory-protocol.md` | Regla de extraccion pre-compact y fin de sesion |
| `pr-signing-protocol.md` | Protocolo strict sign-last para evitar re-sign loops |

---

## Referencias

- [OpenViking](https://github.com/volcengine/OpenViking) — Apache 2.0
- [Fabrik-Codek](https://github.com/ikchain/Fabrik-Codek) — MIT
- era21-masterplan.md, SPEC-010 a SPEC-017, zeroclaw/ROADMAP.md
