---
id: SE-065
title: SE-065 — responsibility-judge S-06 false positives on Spanish prose
status: PROPOSED
origin: batch 30 friction encounter 2026-04-22
author: Savia
priority: Baja
effort: XS 1-2h
gap_link: Spanish prose in CHANGELOG fragments triggers code-shortcut detector
approved_at: null
applied_at: null
expires: "2026-05-22"
---

# SE-065 — responsibility-judge S-06 false positives on Spanish prose

## Purpose

`.claude/hooks/responsibility-judge.sh` S-06 rule detects `\b(TODO|FIXME|HACK)\b` with grep `-i` (case-insensitive) to catch code-shortcut comments. In Spanish prose (CHANGELOG fragments, docs) the standalone quantifier t-o-d-o (meaning "everything") triggers the rule as a false positive.

Observed during batch 30: writing a CHANGELOG fragment with the phrase "salta la lista completa" was only possible after rewording from "salta todo" — the judge blocked the Write because the standalone Spanish quantifier matched the pattern.

## Root cause

Two design choices compound:
1. Case-insensitive match on English code-comment keywords
2. No file-type narrowing (markdown is scanned like shell/python)

In code, T-O-D-O as a comment is overwhelmingly uppercase by convention (IDEs, editorconfig, linters all enforce this). Lowercase Spanish prose using the same letter sequence is common and unrelated.

## Scope (Slice 1)

Minimal surgical fix: narrow S-06 to case-sensitive uppercase match AND exempt markdown/docs:

```bash
# S-06: TODO without ticket reference (case-sensitive, code files only)
if [[ -z "$PATTERN" ]]; then
  # Skip markdown/docs: Spanish prose legitimately uses common words matching these
  if ! echo "$FILE_PATH" | grep -qiE '\.(md|mdx|txt|rst)$|CHANGELOG\.d/|/docs/'; then
    # Case-sensitive: code-comment convention is uppercase
    if echo "$CONTENT" | grep -qE '\b(TODO|FIXME|HACK)\b' && \
       ! echo "$CONTENT" | grep -qE '\b(TODO|FIXME|HACK)\s*[\(\[]\s*(AB#|@|#[0-9])'; then
      PATTERN="S-06"
      DETAIL="TODO/FIXME without ticket reference"
    fi
  fi
fi
```

Changes:
- Drop `-i` flag → uppercase required (matches code convention, skips Spanish prose)
- Add markdown/docs path exclusion (prose does not ship runtime logic)

## Acceptance criteria

- `responsibility-judge.sh` S-06 no longer blocks CHANGELOG.d fragments that contain standalone Spanish quantifier words
- S-06 still blocks `TODO` (uppercase) in `.sh`, `.py`, `.ts`, `.cs`, `.java`, `.go`, `.rs`, `.rb`, `.php`, `.kt`, `.swift`, `.cpp`, `.c` files
- Tests: BATS cases for positive (uppercase in code blocks) and negative (lowercase Spanish in markdown) cases
- Zero regression in existing S-06 detection on actual code shortcuts

## Risks

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Lowercase t-o-d-o in code (rare) escapes detection | Baja | Bajo | Linters/style tools catch this upstream |
| Dev writes uppercase keyword in markdown docs legitimately | Media | Bajo | Exempt by file-type; intentional annotations use `TODO(AB#123)` pattern |
| Breaks existing tests of responsibility-judge | Baja | Medio | Run `tests/test-responsibility-judge.bats` before merge |

## No hacen

- No elimina la regla S-06, solo la hace case-sensitive + file-type aware
- No afecta S-01..S-05 (thresholds, skip annotations, empty handlers, gate bypass flags, coverage config)
- No exempta agents/skills markdown — esos sí pueden llevar directivas ocultas

## Referencias

- Hook: `.claude/hooks/responsibility-judge.sh` líneas 109-115
- Memory `feedback_no_overrides_no_bypasses`: este fix NO es un override, es calibración de precisión de la regla para evitar falsos positivos en prose i18n
- Batch 30 friction log: CHANGELOG fragment rewrite forzado por "salta todo" → "salta la lista completa"
- Rule #24 Radical Honesty: el hook debe detectar shortcuts reales, no palabras comunes en español
