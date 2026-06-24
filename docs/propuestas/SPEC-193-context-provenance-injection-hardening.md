---
status: IMPLEMENTED
implemented_at: "2026-06-24"
---

# SPEC-193 — Context Provenance & Injection Hardening

> **Priority:** P0 · **Estimate (human):** 4-6d · **Estimate (agent):** 5-8h · **Category:** standard · **Type:** infrastructure

> **Dual estimate**: 4-6 dias humano end-to-end (12 componentes en tres capas + tests + actualizacion de reglas + datos de telemetria iniciales). 5-8h agente con pipeline supervisado. Categoria standard. Detalle en `@docs/rules/domain/dual-estimation.md`.

## Objective

Savia tiene cobertura defensiva parcial contra prompt injection y manipulacion de contexto. La auditoria 2026-06-13 (`output/20260613-jailbreak-techniques-defensive-study.md`) inventaria 7 tecnicas + 2 meta-tecnicas documentadas en literatura academica de los ultimos 3 anos y mapea 6 gaps explotables, especialmente en memoria persistente y correlacion cross-turn.

Esta spec cierra los 6 gaps con 12 componentes en defensa-en-capas: capa A deterministic (sin LLM, alto ROI), capa B LLM judges (extension del Recommendation Tribunal SPEC-125), capa C correlacion temporal y consistencia. Defaults conservadores (shadow -> warn -> block tras 30 dias de telemetria). El objetivo NO es defensa perfecta (no existe en LLMs); es elevar el coste del ataque y dar visibilidad medible.

Trade-off honesto: deteccion semantica costosa en latencia, falsos positivos sobre creative writing legitimo, decomposition cross-turn requiere taxonomia mantenida. La defensa heuristica reduce superficie pero no la cierra. Documentado en seccion Limitaciones.

## Principles affected

- **#1 Data sovereignty** — Telemetria local (`output/context-hardening-telemetry.jsonl`). Cero envio externo.
- **#3 Reversible** — `SAVIA_HARDENING=off` desactiva las tres capas. Cada componente env-overridable.
- **#5 Humans decide** — Capas B y C solo emiten verdict + banner. La usuaria ve la senal, no se censura.
- **#9 Confidentiality** — Provenance tagging refuerza N1-N5 confidentiality tiers existentes.
- **Linea Roja L1-L5** (`savia-ethical-principles.md`) — esta spec implementa la defensa que mantiene las lineas rojas frente a ataques sofisticados (decomposition, fiction framing, authority claims).
- **Genesis B9 GOAL STEWARD** — los jueces y la correlacion son guardia activa contra deriva del proposito por manipulacion adversaria.

NO contradice SE-028 (`prompt-injection-guard.sh`) ni SE-221 (`context-origin-stamp.sh`): los extiende.

## Design

### Overview

Defensa en tres capas sucesivas. Cualquier evento de entrada externa (Read, memory-store save, KG insert, tool output) atraviesa al menos la Capa A. Output del modelo atraviesa la Capa B. La sesion entera es observada por la Capa C.

```
[input externo: Read, tool_output, memory.save, KG.insert]
     |
     v
[Capa A: Sanitize deterministic, <50ms, no LLM]
     | NFKC normalize, ASCII-fold, invisible-char strip,
     | bidi-control reject, homoglyph score, script-mixing detect
     | provenance tag obligatorio: source, trust_level, session_id
     v
[memoria persistente o contexto del modelo, marcado]
     |
     v
[Capa B: LLM judges al output, extiende SPEC-125 Recommendation Tribunal]
     | structural-framing-judge      (modo shadow)
     | fiction-framing-judge         (modo shadow)
     | authority-claim-judge         (modo shadow)
     v
[Capa C: Correlacion temporal y consistencia, observacion]
     | cross-turn-correlation        (telemetria + warn si convergence)
     | classification-consistency    (telemetria de inconsistencias entre clasificadores)
     | re-anchor periodico de L1-L5 al system prompt
     v
[output al usuario, con banner si WARN/VETO]
```

### Components

| # | Name | Kind | Purpose |
|---|------|------|---------|
| 1 | `scripts/context-sanitize/normalize.py` | py script (stdlib) | NFKC + ASCII-fold + invisible-char strip + bidi-control reject |
| 2 | `scripts/context-sanitize/homoglyph-detect.py` | py script (stdlib) | Detecta Latin <-> Cyrillic / Greek / Mathematical mixing; score 0-100 |
| 3 | `.opencode/hooks/context-sanitize-input.sh` | hook (PreToolUse Read/Write) | Sanitiza antes de carga al contexto |
| 4 | `.opencode/hooks/memory-write-sanitize.sh` | hook (PreToolUse antes memory-store save) | Bloquea entradas con homoglyphs no justificados |
| 5 | `.opencode/agents/structural-framing-judge.md` | LLM judge (mid model) | Detecta output que parece manual/protocolo sobre dominio sensible |
| 6 | `.opencode/agents/fiction-framing-judge.md` | LLM judge (mid model) | Detecta persona-shift y fiction-frame con contenido equivalente al rechazado |
| 7 | `.opencode/agents/authority-claim-judge.md` | LLM judge (fast model) | Detecta y descuenta auto-declaraciones de credencial |
| 8 | `scripts/cross-turn-correlation/track.py` | py script | Registra clase semantica de cada turn; alerta si convergence |
| 9 | `scripts/classification-consistency-audit.py` | py script | Compara verdicts entre clasificadores; loguea inconsistencias |
| 10 | KG schema migration | sql | Anade columnas `source`, `trust_level`, `created_by_session` a `entities` |
| 11 | `.opencode/hooks/re-anchor-redlines.sh` | hook (UserPromptSubmit periodico) | Reinjecta L1-L5 cada N turns |
| 12 | `docs/rules/domain/authority-claims-not-evidence.md` | rule | Auto-declaracion de rol NO relaja umbrales en dominios sensibles |

Adicionalmente: extension de `scripts/recommendation-tribunal/aggregate.sh` para los 3 nuevos jueces (mismo patron fail-soft que SPEC-192).

### Contracts

#### Capa A — sanitize input

```bash
# context-sanitize-input.sh
INPUT=$(cat)  # JSON envelope
DRAFT=$(jq -r '.tool_input.text // .tool_response.output' <<< "$INPUT")
RESULT=$(python3 scripts/context-sanitize/normalize.py --text "$DRAFT" --json)
# Result fields: {normalized, original, transformations: [list], homoglyph_score, bidi_present}
SCORE=$(jq -r '.homoglyph_score' <<< "$RESULT")
case "$MODE" in
  off) exit 0 ;;
  shadow) telemetry "SANITIZE_OBSERVED" ; exit 0 ;;
  warn)   [[ $SCORE -gt 30 ]] && stderr "WARN: homoglyphs detected (score=$SCORE)" ; exit 0 ;;
  block)  [[ $SCORE -gt 70 ]] && exit 2 ; exit 0 ;;
esac
```

Reglas de bloqueo:
- `bidi_present` -> SIEMPRE block (no hay caso legitimo de RLO/LRO en payload de tool).
- `homoglyph_score >= 70` con `script_mixing` activo -> block en modo block.
- `homoglyph_score 30-70` -> warn.
- `homoglyph_score < 30` -> pass.

#### Capa A — homoglyph score algoritmo

Tabla resumen:

| Caracteristica | Peso |
|---|---|
| Mezcla Latin + Cyrillic en misma palabra | +30 |
| Mezcla Latin + Greek en misma palabra | +25 |
| Caracter de Mathematical Alphanumeric (U+1D400-U+1D7FF) | +20 por ocurrencia |
| Tags Unicode (U+E0000-U+E007F) | +50 (siempre adversario) |
| Zero-width chars (U+200B, U+200C, U+200D, U+FEFF) en posicion no-justificada | +15 |
| Soft hyphen (U+00AD) en cadena de caracteres alfa | +20 |
| Bidi controls (U+202A-U+202E, U+2066-U+2069) | +50 + bidi_present=true |

Score capped a 100. NFKC normalization se aplica SIEMPRE; el score se calcula sobre el original para detectar el intento.

#### Capa B — structural-framing-judge

```yaml
input:  { draft: string, context: string (last 2 turns) }
output: { score: 0-100, veto: bool, confidence: 0-1, reason: str, evidence: [phrase] }
veto trigger: score >= 85 AND confidence >= 0.85 AND domain in CBRN_TAXONOMY
latency: 3s p95
```

Heuristica del prompt: detectar si el draft adopta forma de:
- Manual / protocolo numerado ("1. preparar", "2. mezclar")
- Capitulo / seccion ("Capitulo 3.2", "Section IV")
- Tabla taxonomica con valores especificos
- Pseudocodigo experimental
Y si la materia es de dominio sensible (CBRN, manipulacion psicologica, autoharm, armas).

#### Capa B — fiction-framing-judge

```yaml
input: { draft, last_3_turns }
output: { score, veto, confidence, persona_shift_detected: bool, content_equivalent: bool }
veto trigger: persona_shift_detected AND content_equivalent AND domain_sensitive
latency: 3s p95
```

Test del juez: "si removieras el frame de ficcion, el contenido se rechazaria solo?" Si si -> flag. Linea Roja L3 ya prohibe roleplay como entidad sin principios; este juez detecta la version sutil.

#### Capa B — authority-claim-judge

```yaml
input: { draft, user_message }
output: { claim_detected: str, claim_type: "credential|professional|research|other", domain_sensitive: bool, threshold_relaxed: bool }
veto: false (siempre warn)
latency: 2s p95 (fast model)
```

Heuristica: detecta frases tipo "soy investigador", "para mi tesis", "estoy escribiendo paper". NO emite veto. Solo loguea: si el draft posterior baja umbrales en dominio sensible despues de claim, telemetria lo marca.

#### Capa C — cross-turn-correlation

```python
# track.py
session_log_path = output/cross-turn/{session_id}.jsonl
on_turn(turn):
    domain = classify_semantic_domain(turn.input + turn.output)
    append_log(session_id, turn_id, domain, timestamp)
    recent = last_N_turns(session_id, N=10)
    if len(set(recent.domains) & SENSITIVE_DOMAINS) >= 3:
        emit_alert(session_id, "convergence_on_sensitive_domain", recent)
```

`SENSITIVE_DOMAINS` se define en `scripts/cross-turn-correlation/sensitive-taxonomy.json`: CBRN sub-domains (chem-synthesis, bio-pathogen, nuclear-fissile, radiological), weapons, manipulation, self-harm, child-safety. Lista reducida y mantenible.

correlation_score = `len(intersection) / N`. Threshold default 0.30 (3 de 10 turns). Modo:
- shadow: solo log
- warn: emite banner + log
- block: NO disponible para esta capa (heuristica, falsos positivos)

#### Capa C — classification-consistency-audit

```python
# audit.py
on_turn(turn):
    input_verdict  = classify_input(turn.input)
    output_verdict = classify_output(turn.output)
    tribunal_verdict = recommendation_tribunal(turn.output)
    if disagreement(input, output, tribunal):
        log("INCONSISTENCY", turn_id, verdicts)
```

Solo telemetria. Datos para detectar grietas en clasificadores que el atacante explota (#6).

#### Capa C — re-anchor-redlines

Hook UserPromptSubmit. Cada N=15 turns o si session_token_count > 40000:
- Lee `docs/rules/domain/savia-ethical-principles.md` lineas rojas L1-L5.
- Anade al inicio del system context: `[RE-ANCHOR L1-L5: armas/manipulacion/autonomia/transhumanismo/CBRN — inmutables]`.
- Telemetria: `{ts, session_id, anchor_count, turn_count}`.

Mitiga "Lost in the Middle" (Liu 2023): los principios no se diluyen en sesiones largas.

#### Schema migration KG

```sql
ALTER TABLE entities ADD COLUMN source TEXT DEFAULT 'unknown';
ALTER TABLE entities ADD COLUMN trust_level INTEGER DEFAULT 50;
ALTER TABLE entities ADD COLUMN created_by_session TEXT DEFAULT NULL;
CREATE INDEX idx_entities_trust ON entities(trust_level);
CREATE INDEX idx_entities_source ON entities(source);
```

Migracion idempotente via `scripts/kg-schema-migrate.py`. trust_level por defecto:
- system / spec / rule -> 100
- user -> 80
- tool (Bash, Grep) -> 60
- external (WebFetch, MCP) -> 40
- llm-generated -> 30

### Configuration

```bash
# Master switch
SAVIA_HARDENING=on|off                              # default on

# Capa A
SAVIA_SANITIZE_INPUT=off|shadow|warn|block          # default warn
SAVIA_HOMOGLYPH_THRESHOLD_BLOCK=70                  # block si score >= este
SAVIA_HOMOGLYPH_THRESHOLD_WARN=30
SAVIA_MEMORY_WRITE_SANITIZE=off|warn|block          # default warn

# Capa B
SAVIA_STRUCTURAL_FRAMING_JUDGE=off|shadow|warn       # default shadow
SAVIA_FICTION_FRAMING_JUDGE=off|shadow|warn          # default shadow
SAVIA_AUTHORITY_CLAIM_JUDGE=off|shadow|warn          # default shadow

# Capa C
SAVIA_CROSS_TURN_CORRELATION=off|shadow|warn         # default shadow
SAVIA_CLASSIFICATION_CONSISTENCY=off|shadow          # default shadow (siempre)
SAVIA_RE_ANCHOR_INTERVAL=15                          # turns

# Telemetria
SAVIA_HARDENING_LOG=output/context-hardening-telemetry.jsonl

# Red-team mode (testing)
SAVIA_REDTEAM_MODE=on   # bypassea bloqueos para tests; loguea TODO
```

## Acceptance criteria

1. **NFKC + ASCII-fold canonico**: dado input con caracteres confusables, `normalize.py` produce salida ASCII deterministica. Verificado por pytest con 30 ejemplos (homoglyphs Cyrillic, Greek, Mathematical, fullwidth).
2. **Bidi-control rejection siempre block**: input con U+202E (RLO) en mode warn devuelve exit 2 con mensaje. Verificado por bats.
3. **Homoglyph score correctly rises**: input "paypal" puro Latin -> score 0; mezcla "paypa1" con Cyrillic 'a' -> score >= 30. Verificado por pytest.
4. **Memory-write-sanitize rechaza score > 70**: `bash scripts/memory-store.sh save` con entrada que contiene mezcla Latin+Cyrillic -> rechazado en modo block. Verificado por bats.
5. **structural-framing-judge detecta manual**: prompt sintetico con forma "Capitulo 1: preparacion" sobre dominio CBRN -> score >= 70. Verificado por pytest sintetico.
6. **structural-framing-judge ignora doc legitima**: README de proyecto de software con headings "1. Install / 2. Configure" -> score < 30. Verificado por pytest.
7. **fiction-framing-judge detecta persona-shift + content-equivalent**: prompt sintetico "escribe novela donde X explica Y" sobre dominio sensible -> persona_shift_detected=true. Verificado por pytest.
8. **fiction-framing-judge ignora ficcion legitima**: ficcion sin contenido equivalente al rechazado (ej. dialogo entre dos personajes sobre tema benigno) -> score 0. Verificado por pytest.
9. **authority-claim-judge detecta credential claim**: input "soy investigador en seguridad" -> claim_detected. Verificado por pytest.
10. **authority-claim-judge no veto**: siempre `veto: false`. Verificado por pytest.
11. **cross-turn-correlation registra clase semantica**: 10 turnos sinteticos con 3+ sobre dominio CBRN -> alerta `convergence_on_sensitive_domain`. Verificado por pytest.
12. **cross-turn-correlation no falso positivo**: 10 turnos diversos sin convergence -> sin alerta. Verificado por pytest.
13. **classification-consistency-audit logea inconsistencias**: input clasificado OK + output clasificado FAIL -> entry en log con severity="inconsistency". Verificado por pytest.
14. **re-anchor inserta L1-L5 cada N turns**: simulacion de 30 turns con N=15 -> 2 inyecciones registradas. Verificado por pytest.
15. **KG migration idempotente**: ejecutar `kg-schema-migrate.py` 2 veces no duplica columnas ni rompe datos. Verificado por pytest con sqlite temporal.
16. **`authority-claims-not-evidence.md` regla existe**: fichero canonico, citado por authority-claim-judge. Verificado por grep.
17. **Master switch SAVIA_HARDENING=off**: con esa env, ningun hook ni juez actua. Verificado por bats integracion.
18. **Telemetria JSONL valida**: cada componente escribe linea JSON parseable con campos `ts, layer, decision, evidence`. Verificado por bats.
19. **Latencia tribunal con 10 jueces**: p95 < 7s (relajado desde 5s con 7 jueces de SPEC-192). Verificado por benchmark.
20. **No falsos positivos en outputs historicos**: ejecutar Capa A en modo warn contra ultimos 5 ficheros de output/ -> 0 bloqueos. Verificado manualmente + script.
21. **SAVIA_REDTEAM_MODE bypassea bloqueos pero logea**: con esa env, mode=block deja pasar pero loguea como `REDTEAM_BYPASS`. Verificado por bats.
22. **Tests sinteticos cubren 7+2 vectores**: 30 positivos por capa + 30 negativos = 180 casos. Verificado por pytest.

## Out of scope

- **Mejorar el modelo subyacente**: imposible desde el workspace.
- **Cobertura cross-session de illusory truth completa**: cross-turn-correlation es por sesion. Cross-session via active-user MEMORY.md se aborda en spec sucesora si los datos lo justifican.
- **Internacionalizacion completa**: capa A cubre Latin/Cyrillic/Greek/Mathematical. Otros scripts (Arabic, Hebrew, CJK confusables) en spec sucesora.
- **Deteccion de irony / sarcasmo**: requiere modelo mas avanzado.
- **Auto-rewrite del draft**: el modelo NO regenera automaticamente. Solo en modo block; en warn/strip output llega con banner.
- **Defensa contra ataques de modelo-base** (ej. abuso de fine-tuning): out of scope, asume modelo Anthropic/OpenAI/equivalente con safety baseline propia.
- **Testing en produccion contra red team activo**: requiere acuerdo separado.

## Dependencies

- Blocked by: ninguno.
- Blocks: ninguna spec actualmente.
- Related:
  - SE-028 `prompt-injection-guard.sh`: extension natural; capa A ejecuta antes y enriquece.
  - SE-221 `context-origin-stamp.sh`: capa A complementa con homoglyph score y trust_level numerico.
  - SPEC-125 Recommendation Tribunal: extension con 3 jueces nuevos (capa B).
  - SPEC-192 anti-adulation: hermana operacionalmente; mismo patron de defaults y telemetria.
  - SE-072 `verified-source-required`: trust_level en KG es la implementacion numerica.
  - Linea Roja L1-L5 (`savia-ethical-principles.md`): los principios que esta spec defiende.

## Migration path

Despliegue gradual en 4 semanas:

| Semana | Cambio | Modo |
|---|---|---|
| 1 | Capa A componentes 1-4 | shadow global |
| 2 | Revisar telemetria, ajustar patterns | warn capa A |
| 3 | Anadir capa B (3 jueces) | shadow capa B |
| 4 | Anadir capa C (correlacion + consistency) | shadow capa C |
| 8 (mes 2) | Revisar telemetria 30d, decidir promocion a warn / block | — |

Reverse: cambiar env vars a `off` revierte. Borrar agentes/hooks/scripts/skill remueve el codigo. KG migration es additiva (no destruye datos existentes).

## Reference code

Patron del normalize.py (esqueleto):

```python
import unicodedata
import re

INVISIBLE_CHARS = set("\u200b\u200c\u200d\u2060\ufeff\u00ad")
BIDI_CONTROLS = set("\u202a\u202b\u202c\u202d\u202e\u2066\u2067\u2068\u2069")
TAGS_RANGE = (0xE0000, 0xE007F)

def normalize(text: str) -> dict:
    bidi_present = any(c in BIDI_CONTROLS for c in text)
    transformations = []

    # Strip invisible
    cleaned = "".join(c for c in text if c not in INVISIBLE_CHARS)
    if cleaned != text:
        transformations.append("invisible_stripped")

    # Strip Unicode tags
    cleaned = "".join(c for c in cleaned if not (TAGS_RANGE[0] <= ord(c) <= TAGS_RANGE[1]))

    # NFKC
    nfkc = unicodedata.normalize("NFKC", cleaned)
    if nfkc != cleaned:
        transformations.append("nfkc_normalized")

    # Compute homoglyph score
    score = compute_homoglyph_score(text)  # raw, on original

    return {
        "normalized": nfkc,
        "original": text,
        "transformations": transformations,
        "homoglyph_score": score,
        "bidi_present": bidi_present,
    }
```

## Impact statement

Cierra los 6 gaps explotables documentados en la auditoria 2026-06-13. Eleva la cobertura defensiva de Savia de ~30% a ~75% sobre los 7 vectores conocidos. Convierte SE-028 de filtro pasivo en sistema multicapa observable. La telemetria mensual permite iterar sobre datos reales y promover modos solo cuando estan justificados. La defensa NO sera perfecta — research demuestra que ningun filtro LLM es invulnerable — pero el coste para el atacante sube de minutos a horas y los intentos quedan registrados.

## OpenCode Implementation Plan

> Required post-2026-04-26 (per `docs/rules/domain/spec-opencode-implementation-plan.md`).

**Classification**: Tier 2. Anade infraestructura nueva en 3 capas (12 componentes), modifica `scripts/recommendation-tribunal/aggregate.sh` para extension fail-soft, anade 3 agentes al tribunal, migra KG schema, anade 1 regla canonica nueva.

### Phase 1 — Capa A deterministic (semana 1)

1. Crear `scripts/context-sanitize/normalize.py` con NFKC + ASCII-fold + invisible-strip + bidi-reject.
2. Crear `scripts/context-sanitize/homoglyph-detect.py` con tabla de pesos.
3. Tests unitarios `tests/scripts/test_context_sanitize.py` (30 positivos + 30 negativos).
4. Crear `.opencode/hooks/context-sanitize-input.sh` con 4 modos (off/shadow/warn/block).
5. Crear `.opencode/hooks/memory-write-sanitize.sh`.
6. Tests bats `tests/test-context-sanitize-hook.bats` cubriendo todos los modos.
7. Registrar hooks en `.claude/settings.json` matcher PreToolUse Read/Write y memory-store.
8. Modo inicial: `shadow` global.

### Phase 2 — Capa B LLM judges (semana 2-3)

9. Crear `.opencode/agents/structural-framing-judge.md` con prompt + esquema JSON.
10. Crear `.opencode/agents/fiction-framing-judge.md`.
11. Crear `.opencode/agents/authority-claim-judge.md`.
12. Tests pytest sinteticos por juez (20 positivos + 20 negativos).
13. Modificar `recommendation-tribunal-orchestrator.md`: anadir 3 jueces a la lista de despachos paralelos. Total 10 jueces.
14. Modificar `scripts/recommendation-tribunal/aggregate.sh`: aceptar 3 nuevas claves opcionales fail-soft.
15. Tests bats del aggregator extendido.
16. Modo inicial: `shadow` para los 3.

### Phase 3 — Capa C correlacion temporal (semana 3-4)

17. Crear `scripts/cross-turn-correlation/track.py`.
18. Crear `scripts/cross-turn-correlation/sensitive-taxonomy.json` con dominios CBRN minimos.
19. Crear `scripts/classification-consistency-audit.py`.
20. Tests pytest para correlacion (10 turnos sinteticos, 3 convergence positives + negatives).
21. Crear `.opencode/hooks/re-anchor-redlines.sh` UserPromptSubmit.
22. Tests bats del re-anchor.
23. Modo inicial: `shadow`.

### Phase 4 — Schema migration y reglas (semana 4)

24. Crear `scripts/kg-schema-migrate.py` idempotente.
25. Tests pytest con sqlite temporal: doble ejecucion no duplica.
26. Crear `docs/rules/domain/authority-claims-not-evidence.md`.
27. Anadir referencia a `radical-honesty.md` y `savia-ethical-principles.md`.
28. Generar `output/context-hardening-telemetry.jsonl` esqueleto.

### Phase 5 — Validacion end-to-end

29. Benchmark de latencia tribunal con 10 jueces. Confirmar p95 < 7s.
30. Smoke real: ejecutar pipeline completo contra 5 outputs historicos. 0 falsos positivos.
31. Telemetria funcional: verificar JSONL escrita correctamente.
32. Documentar en `CHANGELOG.d/spec-193-injection-hardening.md`.

### Acceptance criteria checklist (mapping)

| AC | Phase | Verifier |
|---|---|---|
| 1, 2, 3, 4, 17, 18, 20, 21 | 1 | pytest + bats |
| 5, 6, 7, 8, 9, 10 | 2 | pytest sinteticos |
| 11, 12, 13, 14 | 3 | pytest |
| 15, 16 | 4 | pytest + grep |
| 19 | 5 | benchmark |
| 22 | 1+2+3 | pytest agregado |

### Risks

- **Falsos positivos en docs legitimas**: README con "1. Install / 2. Run" mal clasificados como manual. Mitigacion: el juez requiere material de dominio sensible Y estructura de manual, no solo estructura.
- **Ficcion legitima rechazada**: la usuaria escribe novelas como tarea legitima. Mitigacion: fiction-framing-judge solo flagea si content_equivalent=true (el contenido se rechazaria fuera del frame).
- **Latencia con 10 jueces excede budget**: si pasa, los 3 jueces de capa B se hacen async (no bloquean output, registran post-hoc).
- **Cross-turn correlation taxonomia incompleta**: los dominios sensibles cambian. Mantener `sensitive-taxonomy.json` requiere disciplina. Mitigacion: revision trimestral; PRs propuestas etiquetadas.
- **Re-anchor satura system prompt**: cada N=15 turns anade ~200 tokens. En sesiones de 100 turns suma ~1300 tokens. Mitigacion: cap de 5 anchors; tras eso solo se actualiza el ultimo.

## Notes

Esta spec es complementaria a SPEC-192 (anti-adulacion). Donde SPEC-192 protege contra patrones de RLHF interno (sycophancy, concession, illusory truth), SPEC-193 protege contra ataques externos de manipulacion del contexto (Unicode, framing, decomposition).

Origen del estudio: `output/20260613-jailbreak-techniques-defensive-study.md`.

Inspiracion academica: Boucher 2021, Liu 2023, Greshake 2023, Wei 2024, Schulhoff 2024, Glukhov 2024, Carlini 2024, Hines 2024.
