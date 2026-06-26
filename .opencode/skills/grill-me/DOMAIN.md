# grill-me — Domain knowledge

## Origin

Pattern from `mattpocock/skills` (26.4k stars GitHub). The grill-me
skill is adversarial testing in natural language — it stress-tests
designs and implementations by hunting weaknesses before they reach
production.

## How it differs from code-review

- `code-reviewer` agent evaluates COMPLETENESS (Does it meet the spec?
  Is it well-structured? SOLID?)
- `grill-me` hunts WEAKNESSES (What will break? What is unstated?
  What edge cases are missed?)

The code-reviewer is a judge. Grill-me is a prosecutor. Different roles,
complementary outputs.

## How it differs from security-guardian

- `security-guardian` hunts SECURITY issues (OWASP, CWE, credentials,
  injection, auth bypass)
- `grill-me` hunts ALL weakness types (security + reliability + edge
  cases + assumptions + error handling)

Grill-me is broader but less specialized on security.

## Integration with Savia

- Works as `/grill-me` command
- Can be invoked as `@grill-me` in sub-agent contexts
- Output can feed into security-guardian for focused security deep-dive
- Effective as pre-merge gate: "Did grill-me pass?"
