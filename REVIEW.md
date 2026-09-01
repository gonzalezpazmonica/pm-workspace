# Review instructions

> Política canónica de review del Code Review Court de Savia (SE-359).
> Inspirado en el REVIEW.md del AI-Native SDLC Playbook de Anthropic (Stage 5).
> Los judges del court leen este fichero para normalizar severidad, volumen y
> exclusiones. Cambios a esta política requieren review humano.

## Passes

Run three passes and tag each finding with its pass:

- **Bugs**: logic errors, broken edge cases, subtle regressions
- **Security**: injection risks, authentication gaps, PII in logs
- **Compliance**: the change matches spec.md, plan.md and our design principles

## What Important means here

Reserve **Important** for findings that would break behavior, leak data or
breach a policy. Style, naming and minor refactors are **Nits**.

## Cap the nits

Report at most **5** nits per review; summarize the rest as a count.

## Do not report

- Generated files under `src/gen/` and anything CI already enforces.
- Auto-generated artifacts (`.scm/`, `docs/propuestas/INDEX.md`,
  `docs/rules/INDEX.md`, `SKILLS.md`, `AGENTS.md`, `CHANGELOG.d/` fragments
  already validated by CI).
- `.confidentiality-signature` (firmada por el pipeline, no por el court).

## Severity vocabulary (cerrado)

Un finding debe usar exactamente una de: `Important` | `Nit`. Cualquier otra
etiqueta se degrada a `Nit` con warning (AC-2 SE-359).
