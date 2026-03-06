# Accessibility in PM-Workspace

> 🦉 I'm Savia. I adapt to how you work, not the other way around. If you need me to communicate differently, guide you step by step, or adapt my output for your screen reader — just configure it.

---

## Quick setup

```
/accessibility-setup
```

A 5-minute wizard that asks what you need. Saves your preferences across sessions.

```
/accessibility-mode status
```

See which adaptations are active.

---

## Main features

**Guided work** (`/guided-work`) — Savia walks you through tasks step by step with questions. One step at a time, at your pace. If you're stuck, I rephrase. If you need a break, I save progress. Three guidance levels: high (closed questions), medium (step blocks), low (checklist).

**Focus mode** (`/focus-mode`) — Loads a single task and hides everything else. No sprint board, no backlog, no distractions. Combinable with guided work.

**Adapted output** — If you use a screen reader, Savia replaces ASCII diagrams with text. If you need high contrast, output doesn't depend on colors. If you prefer short messages, output is limited to 5 lines.

**Constructive reviews** — Code reviews use strengths-first language, avoiding rejection-triggering words. Configured with `review_sensitivity: true`.

**Breaks** — Integration with the wellbeing system. Pomodoro, 52-17, or any interval you prefer.

---

## Common configurations

| Need | What to activate |
|---|---|
| Screen reader user | `screen_reader: true`, `high_contrast: true` |
| Reduced mobility / RSI | `motor_accommodation: true` |
| ADHD / focus | `guided_work: true`, `focus_mode: true`, `cognitive_load: low` |
| Autism | `review_sensitivity: true`, `guided_work: true` |
| Dyslexia | `dyslexia_friendly: true` |

---

## FAQ

**Can I disable it temporarily?** Yes: `/accessibility-mode off`. Reactivate with `on`.

**Does it affect performance?** No. Adaptations are formatting instructions, not extra processing.

**Can my teammates see it?** No. Your accessibility profile is local, only affects your session.

**Does it work with screen reader X?** Savia generates plain text compatible with NVDA, JAWS, and VoiceOver. If something doesn't work, report with `/feedback`.

---

Full guide: [guide-accessibility.md](guides/guide-accessibility.md)
