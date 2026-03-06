# Accessibility Guide — Savia for everyone

> 🦉 I'm Savia. I adapt to you. This guide explains how I work with people with different needs, step by step.

---

## Why it matters

28.6% of adults with cognitive disabilities of working age are employed (vs 75% without disability). Many work in tech — Fundación ONCE has trained over 30,000 people with disabilities in digital skills. pm-workspace runs in the terminal (Claude Code), which is already accessible as text and keyboard. But we can go much further: actively guide, adapt outputs, and respect each person's pace.

---

## Quick setup

```
/accessibility-setup          → conversational wizard (5 min)
/accessibility-mode status    → see what's active
/guided-work --task PBI-123   → step-by-step guided work
/focus-mode --task PBI-123    → clean environment, no distractions
```

---

## Step-by-step guide by disability profile

### Visual disability (low vision, blindness)

**What I activate:** `screen_reader: true`, `high_contrast: true`, `reduced_motion: true`

**How Savia changes:**
- ASCII burndowns (`████░░░░`) become text: "Progress: 40%, 35 SP completed out of 88"
- Complex tables become descriptive lists
- Color signals always include text: "CRITICAL" instead of just 🔴
- Decorative separators disappear
- Generated reports (DOCX, PPTX) use descriptive text for graphics

**Daily usage example:**
```
You: /sprint-status
Savia: Sprint 2026-04, day 6 of 10. Progress: 40% completed, below plan.
  4 active items. 2 alerts: AB#1023 no movement for 2 days, risk of not completing.
  Remaining capacity: 68 human hours, 12 agent hours.
```

### Motor disability (RSI, reduced mobility)

**What I activate:** `motor_accommodation: true`, `voice_control: true`

**How Savia changes:**
- Suggests short aliases for long commands
- No complex flags needed: accepts natural language ("how's the sprint?" → `/sprint-status`)
- Offers to run command sequences automatically
- Does not interpret silence as abandonment (extended timeouts)
- Compatible with Talon and Dragon NaturallySpeaking

**Daily usage example:**
```
You: sprint status
Savia: [runs /sprint-status automatically]
You: decompose PBI 1025
Savia: [runs /pbi-decompose 1025]
```

### ADHD / focus difficulty

**What I activate:** `cognitive_load: low`, `guided_work: true`, `guided_work_level: alto`, `focus_mode: true`, `break_strategy: pomodoro`

**How Savia changes:**
- `/guided-work` guides you step by step with questions — one step at a time, 3 lines max
- `/focus-mode` hides everything except your current task
- Pomodoro breaks every 25 minutes
- If you get lost: "You were on step 3. Shall we go back?"
- If you get stuck: rephrases simpler, offers to do it, or suggests a break

**Daily usage example:**
```
You: /guided-work --task PBI-1025
Savia: We'll implement the POST /patients endpoint. 5 steps. Shall we start?
You: Yes
Savia: Step 1: Create PatientController.cs. Shall I create it?
You: Yes
Savia: Created. Step 1/5 done. Next?
```

### Autism spectrum

**What I activate:** `cognitive_load: medium`, `review_sensitivity: true`, `guided_work: true`, `guided_work_level: medio`, `break_strategy: 52-17`

**How Savia changes:**
- Code reviews use constructive language: strengths first, never "error" or "bug"
- Predictable structure: always the same format, no surprises
- Direct and unambiguous communication
- If there's a context switch, warns explicitly
- TDD as structure: "The tests define what should happen. If they pass, you're done."

**Code review example:**
```
Review of PatientController.cs
  What's good: clear structure, follows project patterns.
  Opportunities: uncovered case on line 34 (null check).
  Suggestion: add if (patient == null) return NotFound().
  Summary: good base, 1 adjustment. Want help?
```

### Dyslexia

**What I activate:** `dyslexia_friendly: true`, `cognitive_load: medium`

**How Savia changes:**
- Generated documents use highly legible sans-serif fonts
- 1.5 line spacing, short paragraphs, left alignment
- Concise messages without dense text blocks
- Common words, short sentences

### Hearing disability

pm-workspace runs in the terminal — everything is text. There are no audio components. People with hearing disabilities can use Savia without any special adaptation. If the team uses voice communication (Teams, Slack calls), Savia can transcribe with `/voice-inbox` and generate written summaries.

---

## Configuration checklist

1. Run `/accessibility-setup` and answer the questions
2. Verify with `/accessibility-mode status`
3. Try `/guided-work --task` with a real task
4. Adjust guidance level if it's too much or too little
5. Configure breaks that work for you
6. If you use a screen reader, verify outputs are legible
7. If you use voice control, try commands in natural language
8. Ask your PM to run `/team-workload` to verify your workload is adequate
9. If something doesn't work → `/feedback` to report it

---

## Sources

- [Fundación ONCE "Por Talento Digital"](https://www.fundaciononce.es/es) — Digital inclusion
- [N-CAPS: Context-Aware Prompting System](https://pubmed.ncbi.nlm.nih.gov/26135042/) — Adaptive guidance
- [Neurodivergent-Aware Productivity Framework](https://arxiv.org/html/2507.06864) — Cognitive scaffolding
- [ADHD/Autism in Software Development](https://arxiv.org/html/2411.13950v1) — Field study
- [CLI Accessibility](https://afixt.com/accessible-by-design-improving-command-line-interfaces-for-all-users/) — Best practices
