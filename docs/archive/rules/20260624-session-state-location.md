---
archived_at: "20260624"
archived_by: SE-096
reason: "Zero functional consumers (agents/hooks/skills/commands). INDEX.md reference only."
---

---
context_tier: L2
token_budget: 535
---

# Session State — Ubicación canónica

> **Rule** — El estado de sesión (RESUME, handoffs entre turnos largos, memoria
> operacional del PM activo) vive en `output/session-state/`. Nunca en raíz del
> repo, nunca en `docs/`, nunca trackeado por git.

## Por qué

El estado de sesión es **operacional**, no documental:

- Cambia cada turno (commits, ramas, decisiones in-flight).
- Cita datos privados como prosa explicativa (nombres de cliente,
  vulnerabilidades en curso, decisiones de RR.HH.) — viola Rule #20/20b
  si se commitea.
- Es útil solo para *este* humano + *esta* sesión.

## Ubicación canónica

```
output/session-state/
├── RESUME.md              # estado al cerrar una sesión larga
├── handoff-{date}.md      # handoff cross-turn cuando supera 1 turno
└── decisions-pending.md   # decisiones abiertas
```

`output/` ya está en `.gitignore` (línea 48). Cualquier fichero bajo
`output/session-state/` es invisible para git por defecto.

## Convención de nombres

- `RESUME.md` — fichero singular, sobrescribible. El estado más reciente.
- `RESUME-{YYYYMMDD}.md` — snapshot opcional si se quiere histórico.
- `handoff-{topic}-{YYYYMMDD}.md` — handoffs específicos.

## Prohibido

```
NUNCA → commitear RESUME.md (ni en raíz, ni en docs/, ni en .claude/)
NUNCA → escribir estado de sesión en ficheros del repo público
NUNCA → citar términos del blocklist como prosa explicativa en ficheros trackeados
```

## Permitido

```
SIEMPRE → `output/session-state/RESUME.md` para estado vivo
SIEMPRE → ~/.savia/ para preferencias persistentes del PM
SIEMPRE → ~/.claude/external-memory/ para auto-memoria del usuario activo
```

## Migración (un solo evento, 2026-05-23)

RESUME.md previamente vivía en raíz del repo (commit 797d4d20).
Movido a output/session-state/RESUME.md el 2026-05-23 al detectar que
contenía PII operacional (Rule #20) y al fallar confidentiality-scan.sh.
El histórico git original se conserva.

## Referencias

- `docs/rules/domain/pii-sanitization.md` (Rule #20)
- `docs/rules/domain/zero-project-leakage.md`
- `.gitignore` línea 48 (`output/`)
