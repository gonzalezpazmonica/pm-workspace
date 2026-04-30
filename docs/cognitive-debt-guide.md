# Cognitive Debt — guide

> **SPEC**: SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`)
> **Phase**: 1 (measurement + opt-in). Phases 2 (friction hooks) y 3 (retrieval drill) follow-up.
> **Status**: opt-in por defecto (CD-04). No se activa sin decisión explícita.

---

## Tesis (one paragraph)

Trabajar 8h/día con Claude Code degrada la memoria episódica, la conectividad neural alpha/beta/theta/delta, la capacidad de síntesis original y el sentido de autoría — y la deuda **persiste cuando se quita la herramienta** (MIT Media Lab, Kosmyna et al. 2025; Microsoft + CMU CHI 2025; CMU ICER 2025). SPEC-107 implementa 5 intervenciones medibles validadas por evidencia. Phase 1 ships measurement + opt-in: telemetría conductual + warning-only hypothesis-first hook + comando `/cognitive-status`. Sin LLM-judge (evita dependencia circular), sin métricas que se puedan exfiltrar a manager (CD-03 inviolable).

---

## Activar / desactivar

```bash
# Activar (opt-in)
bash scripts/cognitive-debt.sh enable

# Ver estado + telemetría reciente
bash scripts/cognitive-debt.sh status

# Resumen agregado de la última semana
bash scripts/cognitive-debt.sh summary

# Desactivar (preserva telemetría)
bash scripts/cognitive-debt.sh disable

# Borrado total irreversible
bash scripts/cognitive-debt.sh forget --confirm
```

---

## Qué entrega Phase 1

| Componente | Qué hace | Estado |
|---|---|---|
| `scripts/cognitive-debt.sh` | enable / disable / status / summary / forget | Listo |
| `.claude/hooks/cognitive-debt-telemetry.sh` (PostToolUse) | Async append a `~/.savia/cognitive-load/{user}.jsonl` por cada Edit/Write/Task | Listo, dormant hasta `enable` |
| `.claude/hooks/cognitive-debt-hypothesis-first.sh` (PreToolUse) | Nudge stderr si los últimos 5 commits no tienen trailer `Hypothesis:` | Listo, **warning-only** (Phase 1) |
| `/cognitive-status` command | Wrapper de `cognitive-debt.sh status + summary` | Listo |
| `~/.savia/cognitive-load/` | Directorio per-user N3 (gitignored, mode 0700) | Creado en `enable` |

---

## Métricas que se computan en Phase 1

Sobre la telemetría JSONL (cada línea = 1 invocación de tool):

- **Total events / día**: cuántas veces invocaste Edit / Write / Task.
- **Fast-accept ratio**: % de tool calls con `duration_ms < 5000` — proxy de "skip-verification" (Microsoft + CMU 2025).
- **Distribución por día** (últimos 7 días): histograma simple en terminal.

NO se computa: "calidad" del código, "deuda cognitiva real" (eso requeriría EEG), juicios de comportamiento. Solo proxies conductuales con interpretación documentada.

---

## Restricciones inviolables (CD-01 a CD-04)

- **CD-01**: ningún hook ejecuta código del usuario ni invoca LLM. Solo lee strings y archivos.
- **CD-02**: bloqueos siempre tienen escape (`--skip-cognitive`). Friction, no firewall. Phase 1: solo warnings, no bloqueos en absoluto.
- **CD-03**: telemetría es **N3** — `~/.savia/`, gitignored, mode 0700. Ni manager, ni equipo, ni reportes corporativos pueden leerla. Usar fatiga cognitiva como criterio de evaluación viola Rule #23 (Equality Shield).
- **CD-04**: opt-in en Phase 1. Por defecto NO se activa. La usuaria decide explícitamente con `enable`.

---

## Pase a Phase 2 (futuro batch)

Phase 2 escala el hypothesis-first hook a modo bloqueante con escape `--skip-cognitive`. También añade:
- I2 teach-back gate (Stop hook al cerrar spec)
- I3 critical-evaluation checklist en `/pr-plan`

Phase 2 requiere **30 días de telemetría real** + greenlight de la usuaria. Sin datos no hay calibración.

---

## Pase a Phase 3 (futuro batch)

Phase 3 añade I5 weekly retrieval drill (`/retrieval-drill` command sugerido los lunes). Calibra umbrales con datos reales de Phases 1 + 2. Integra bidireccional con `wellbeing-guardian` (suma `cognitive_load_score` a su modelo).

---

## Qué NO hace SPEC-107 (por diseño)

- NO mide la calidad del pensamiento — eso requiere LLM-judge y reintroduce el problema.
- NO bloquea trabajo en Phase 1 — solo nudges.
- NO reemplaza `wellbeing-guardian` — añade dimensión cognitiva sobre la dimensión de horario/break que ya existe.
- NO predice burnout — eso es `burnout-radar`. Mide degradación cognitiva, no estado emocional.
- NO promete reducción de "AI brain fry" como tal. Promete: visibilidad + friction validada por evidencia.

---

## Evidencia académica (no opinión)

- **Kosmyna et al. 2025** "Your Brain on ChatGPT" — arxiv.org/abs/2506.08872 — 32-channel EEG, 54 participantes, dosis-respuesta clara.
- **Lee et al. CHI 2025** — Microsoft Research + CMU, 319 trabajadores del conocimiento. Mayor confianza GenAI ↔ menos pensamiento crítico.
- **CMU ICER 2025** — arxiv.org/pdf/2509.20353 — Copilot longitudinal en estudiantes; metacognición débil rinde **peor con Copilot**.
- **Roediger & Karpicke 2006** — base de retrieval practice (+50% retención a 1 semana vs re-lectura).

---

## Cross-refs

- SPEC-106 Truth Tribunal (verifica fiabilidad del output IA — complementario)
- SPEC-125 Recommendation Tribunal (audita recomendaciones IA en tiempo real)
- SPEC-061 neurodivergent integration (wellbeing baseline)
- `docs/rules/domain/code-comprehension.md` (3AM debuggability)
- `docs/rules/domain/dev-session-protocol.md` (Phase 1 spec load)
- `docs/rules/domain/emotional-regulation.md` (tono UI sin pánico)
- `docs/rules/domain/verification-before-done.md` (Rule #22)

---

## Referencias

SPEC-107 (`docs/propuestas/SPEC-107-ai-cognitive-debt-mitigation.md`) Phase 1 IMPLEMENTED.
