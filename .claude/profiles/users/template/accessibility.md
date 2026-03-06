---
# Accessibility preferences — Loaded on demand when formatting output or adapting workflows.
# All settings are opt-in. Default values = zero impact on existing behavior.
# Configure with /accessibility-setup or edit manually.

# === Vision ===
screen_reader: false           # Replace ASCII art with text descriptions, structured output
high_contrast: false           # No color-dependent information, text+symbol only
reduced_motion: false          # No spinners, no animations, no progress bars

# === Motor ===
motor_accommodation: false     # Enable command aliases, extended timeouts
voice_control: false           # Optimize output for voice-controlled workflows

# === Cognitive ===
cognitive_load: medium         # low = minimal output, one step at a time
                               # medium = standard (default)
                               # high = full detail, all options visible
focus_mode: false              # Single-task mode, hide distractions
guided_work: false             # Savia guides step by step with questions
guided_work_level: medio       # alto = one step, closed questions, max 3 lines
                               # medio = 2-3 steps, open questions
                               # bajo = full checklist, user marks progress

# === Communication & Review ===
review_sensitivity: false      # Strengths-first code review language
dyslexia_friendly: false       # Adapted fonts in generated documents (OpenDyslexic)

# === Wellbeing ===
break_strategy: standard       # standard | pomodoro | 52-17 | custom
break_interval_min: 25         # Minutes between break suggestions
---

## Notes

This fragment is optional. If it doesn't exist, Savia uses default behavior.
Configure interactively with `/accessibility-setup` or toggle with `/accessibility-mode`.
