# SPEC-011: Roadmap Unificado — pm-workspace + Savia + SaviaClaw

> Status: **ACTIVE** · Fecha: 2026-03-22
> Ultima repriorizacion: 2026-03-22

---

## Estado actual

| Area | Version | Estado |
|------|---------|--------|
| pm-workspace core | v3.24.0 | 401+ commands, 79 skills, 44 agents, 16 hooks |
| Savia Web | Phase 2.5 | Chat SSE, backlog tree+kanban, i18n, file browser |
| SaviaClaw | v1.0 prep | Serial+WiFi, LCD, LED, brain bridge, daemon, voice pipeline |
| Robotics | Fase 2 | ESP32 MicroPython, safety rules, language pack |

---

## Criterios de priorizacion

1. **ROI de tokens** — reducir consumo = mas capacidad por sesion
2. **Perdida de informacion** — lo que se pierde no se recupera
3. **Experiencia de usuario** — adaptacion, fluidez, menos friccion
4. **Riesgo tecnico** — bajo riesgo primero, alto riesgo con mas prep
5. **Dependencias** — lo que desbloquea mas cosas va antes

---

## Tier 1 — Hacer AHORA (sprint actual y siguiente)

Bajo riesgo, alto ROI, sin dependencias.

| # | Spec | Area | Que | Esfuerzo | Estado |
|---|------|------|-----|----------|--------|
| 1 | SPEC-015 | Core | Context Gate skill activation | <1 sprint | DONE 2026-03-22 |
| 2 | SPEC-012 | Core | L0/L1/L2 progressive loading | 2 sprints | Phase 1 EN CURSO |
| 3 | Era21-WS4 | Core | Script hardening (6 criticos) | 1 sprint | DONE 2026-03-22 (6/6 fixed) |

**Justificacion:** SPEC-015 y SPEC-012 atacan el problema #1 de pm-workspace
(consumo de contexto). WS4 arregla bugs de seguridad activos. Los tres son
independientes y pueden ejecutarse en paralelo.

---

## Tier 2 — Hacer PRONTO (sprints 3-4)

Medio riesgo, previenen perdida de informacion.

| # | Spec | Area | Que | Esfuerzo | Deps |
|---|------|------|-----|----------|------|
| 4 | SPEC-013 | Core | Session memory extraction hook | 2 sprints | Ninguna |
| 5 | SPEC-016 | Core | Intelligent compact | 1 sprint | Reutiliza extractor de SPEC-013 |
| 6 | SPEC-010 N1 | SaviaClaw | Estabilidad (WiFi auto, heartbeat, reconnect) | 1 sprint | Ninguna |

**Justificacion:** SPEC-013+016 eliminan la perdida de ~30% de decisiones
entre sesiones. SaviaClaw N1 es prerequisito de todo lo demas en hardware.

---

## Tier 3 — Hacer DESPUES (sprints 5-7)

Medio-alto esfuerzo, mejoran la inteligencia del sistema.

| # | Spec | Area | Que | Esfuerzo | Deps |
|---|------|------|-----|----------|------|
| 7 | SPEC-014 | Core | Competence model en perfiles | 3 sprints | Mejor con SPEC-012 (adapta L1) |
| 8 | Era21-WS2 | Core | Git Persistence Engine (indices TSV) | 2 sprints | Ninguna |
| 9 | Era21-WS7 | Core | Savia Flow git-native (tasks, specs, sprints) | 2 sprints | WS2 (indices) |
| 10 | SPEC-010 N2 | SaviaClaw | Proactividad (daemon, sensores, LCD status) | 1 sprint | N1 |
| 11 | SPEC-017 F1-F3 | Core | Sovereignty USB (deps offline + installer) | 2 sprints | WS4 (scripts) |

**Justificacion:** SPEC-014 hace a Savia mas inteligente por dominio.
SPEC-017 garantiza soberanía de dependencias — Savia funciona sin internet.
WS2+WS7 dan persistencia sin BD. SaviaClaw N2 lo hace proactivo.

---

## Tier 4 — Planificado (sprints 8-12)

Requieren Tiers anteriores o son de alto esfuerzo.

| # | Spec | Area | Que | Esfuerzo | Deps |
|---|------|------|-----|----------|------|
| 11 | Savia Web Phase 3 | Web | Chat multi-thread, user mgmt, file ACL | 3 sprints | — |
| 12 | SPEC-010 N3 | SaviaClaw | Voz (wake word, TTS, voice-console protocol) | 2 sprints | N2 |
| 13 | Era21-WS5 | Core | Travel Mode (USB pack/unpack) | 1 sprint | WS4, SPEC-017 |
| 13b | SPEC-017 F4 | Core | SaviaOS booteable (distro live USB) | 2 sprints | SPEC-017 F1-F3 |
| 14 | SPEC-003 | Core | Web research system | 2 sprints | — |
| 15 | Era21-WS1 | Vertical | Savia School v1 | 3 sprints | WS2, WS4 |

**Justificacion:** Savia Web Phase 3 ya tiene specs escritos. SaviaClaw N3
necesita N2 estable. Travel Mode necesita scripts robustos. School necesita
indices y scripts — y requiere auditoria de seguridad (GDPR infantil).

---

## Tier 5 — Horizonte (sprints 13+)

Vision a largo plazo. Specs por escribir cuando llegue el momento.

| # | Spec | Area | Que | Deps |
|---|------|------|-----|------|
| 16 | SPEC-010 N4 | SaviaClaw | BT audio bidireccional (HFP AG) | N3 |
| 17 | SPEC-008 | SaviaClaw | Meeting digest con speaker diarization | N3 |
| 18 | SPEC-009 | SaviaClaw | Savia en Teams (Graph API bot) | N3 |
| 19 | SPEC-010 N5 | SaviaClaw | Guardiana de contexto autonoma | N4, SPEC-013 |
| 20 | SPEC-010 N6 | SaviaClaw | Multi-SaviaClaw mesh | N5 |
| 21 | Era21-WS1 v2 | Vertical | Savia School v2 (security audit, GDPR) | WS1 v1 |
| 22 | Robotics F3 | Vertical | Embedded Rust (Embassy, ESP-HAL) | Fase 2 |
| 23 | Robotics F4 | Vertical | ROS2 integration | Fase 3 |
| 24 | Robotics F5 | Vertical | IA fisica (LeRobot) | Fase 4 |

---

## Backlog de ideas Context Intelligence (P4 de investigacion)

Ideas extraidas de OpenViking y Fabrik-Codek. Sin spec aun.
Se promueven a Tier cuando hay datos de uso que lo justifiquen.

| Idea | Origen | Trigger para promover |
|------|--------|----------------------|
| Thompson Sampling profile loading | Fabrik-Codek | Datos de SPEC-014 muestran varianza en profundidad optima |
| savia:// URI scheme | OpenViking | Handoffs entre agentes fallan por rutas fragiles |
| Temporal decay en memory-store | Fabrik-Codek | memory-recall devuelve entradas stale frecuentemente |
| Outcome inference para NL | Fabrik-Codek | confidence-protocol muestra logging manual insuficiente |
| Hybrid RAG para agent memory | Fabrik-Codek | Agent memory crece a >500 entradas |
| Two-stage retrieval en /nl-query | OpenViking | NL resolution accuracy <80% en 3 sprints |
| Semantic drift detection | Fabrik-Codek | Usuarios cambian de proyecto frecuentemente |
| U-Shape prompt positioning | Fabrik-Codek | Agentes heavy ignoran constraints finales |
| Quality gate en lessons.md | Fabrik-Codek | lessons.md supera 30 entradas con ruido |

---

## Diagrama de dependencias

```
SPEC-015 (Gate) ──────────────────────────────────────┐
SPEC-012 (L0/L1/L2) ─────────────────────────────────┤
Era21-WS4 (Script fix) ──────┬───────────────────────┤
                              │                       │
SPEC-013 (Session Memory) ───┬┤  Era21-WS5 (Travel)  │  Tier 1-2
SPEC-016 (Smart Compact) ◄───┘│                       │
SPEC-010 N1 (Estabilidad) ────┤                       │
                              │                       │
SPEC-014 (Competence) ◄── SPEC-012                    │  Tier 3
Era21-WS2 (Git Persistence) ──┬───────────────────────┘
Era21-WS7 (Savia Flow) ◄──────┘
SPEC-010 N2 (Proactividad) ◄── N1

Savia Web P3 ─────────────────────────────────────────  Tier 4
SPEC-010 N3 (Voz) ◄── N2
SPEC-003 (Web Research)
Era21-WS1 (School) ◄── WS2, WS4

SPEC-010 N4-N6, SPEC-008, SPEC-009 ◄── N3            Tier 5
Robotics F3-F5 ◄── F2
```

---

## Metricas de exito globales

| Metrica | Baseline | Objetivo | Spec que lo mide |
|---------|----------|----------|-----------------|
| Tokens por sesion | ~80K | <50K | SPEC-012, 015 |
| Info perdida en /compact | ~30% | <5% | SPEC-013, 016 |
| Skills sugeridos irrelevantes | ~20% | <5% | SPEC-015 |
| Coaching accuracy | No medido | >80% | SPEC-014 |
| SaviaClaw uptime | ~80% | >99% | SPEC-010 N1 |
| Scripts sin bugs seguridad | 6 criticos | 0 | Era21-WS4 |

---

## Referencias

- [OpenViking](https://github.com/volcengine/OpenViking) — Apache 2.0, 17.5k stars
- [Fabrik-Codek](https://github.com/ikchain/Fabrik-Codek) — MIT, 1058 tests
- era21-masterplan.md, SPEC-010, robotics-roadmap.md
- Savia Web: projects/savia-web/CLAUDE.md + specs/phase*.spec.md
