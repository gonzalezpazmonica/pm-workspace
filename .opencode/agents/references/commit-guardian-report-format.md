# Commit Guardian — Pre-Commit Report Format Reference

## Standard pre-commit check format

Header: PRE-COMMIT CHECK [branch] → [change type]

  Check 1 — Rama ......................... ok / branch-name
  Check 2 — Security audit ............... ok / warn / blocked
  Check 3 — Build .NET ................... ok / not-applicable
  Check 4 — Tests unitarios .............. ok / not-applicable
  Check 5 — Formato ...................... ok / not-applicable
  Check 6 — Code review .................. ok / warn / blocked
  Check 7 — README actualizado ........... ok / blocked
  Check 8 — CLAUDE.md <= 150 líneas ....... ok / XXX lines
  Check 9 — Atomicidad del commit ........ ok / warn
  Check 10 — Mensaje de commit ........... ok / warn

Footer: APROBADO / BLOQUEADO (N checks fallidos)

When all checks are ok or not-applicable, execute:
  git commit -m "mensaje convencional" --trailer "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
