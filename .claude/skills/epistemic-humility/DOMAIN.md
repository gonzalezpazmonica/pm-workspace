# epistemic-humility — Domain knowledge

## Origin

Defensive companion to SPEC-192 (anti-adulation). Implements the active
protocol the LLM follows when the Recommendation Tribunal flags sycophancy,
concession without evidence, or illusory truth in its draft. Origin in the
behavioral science literature on illusory truth effect (Hasher 1977, Fazio
2015, Pennycook 2018) — knowledge does NOT protect against repetition
becoming truth; explicit fact-checking behavior does.

## How it differs from radical-honesty

- `radical-honesty.md` is a RULE — declarative constraint, no enforcement.
- `epistemic-humility` is a SKILL — active protocol with concrete substitutions:
  never-vs-instead table, diff-of-evidence requirement, tool verification
  gate before citing user claims as fact.

SPEC-192 connects rule and skill via the three new tribunal judges + the
Layer 1 deterministic hook. This skill is the LLM-side response when those
judges fire.

## When to load

- Tribunal emits VETO or WARN ≥ 60 from sycophancy / concession /
  repetition-truth judges.
- Self-introspection: about to write "buena pregunta", "tienes razón",
  "absolutamente", "great question", "you are right" without follow-up
  evidence.
- User has insisted N≥2 times without new evidence in transcript.

## When NOT to load

- Genuine acknowledgement of own error with substantive correction
  ("mi error en X, la fuente actual dice Y" — already epistemically humble).
- Greetings or closings (not adulation).
- Domain-specific praise with concrete grounding ("este test pasa
  98% coverage en Y módulos" — quantified, not empty).

## Three patterns covered

| Pattern | Trigger | Substitution |
|---|---|---|
| A — reflexive sycophancy | RLHF training bias | strip phrase, go to content |
| B — concession under pressure | user insistence without evidence | maintain stance OR show diff |
| C — illusory truth | user claim repeated, treated as fact | hedge or verify with tool |

## Integration with Savia

- Loaded automatically by `recommendation-tribunal-orchestrator` when
  any of the 3 SPEC-192 judges emits WARN ≥ 60.
- Loadable manually: `/skill load epistemic-humility`.
- Telemetry: each load logs to `output/anti-adulation-telemetry.jsonl`
  with `decision: "SKILL_LOADED_EPISTEMIC_HUMILITY"`.

## Anti-patterns

- Announcing "I will be epistemically humble now" — be it, do not narrate it.
- Replacing adulation with disdain ("obvious question") — the alternative
  is content, not contempt.
- Mechanical application — courtesy is not always sycophancy. The skill
  requires judgment.

## Related

- Rule: `docs/rules/domain/radical-honesty.md` (Rule #24)
- Spec: `docs/propuestas/SPEC-192-anti-adulation-illusory-truth.md`
- Tribunal: SPEC-125 (Recommendation Tribunal extended)
- Hook: `.opencode/hooks/sycophancy-strip.sh` (Layer 1 deterministic)
- Sibling skills: `caveman` (extreme brevity), `grill-me` (adversarial review)
