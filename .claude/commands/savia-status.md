# /savia-status

**Name:** savia-status
**Description:** Show Savia's current status, health metrics, and top pending priorities
**Context Cost:** low
**Argument Hint:** `[--json]`

---

## Overview

Displays Savia's personality profile, current health score, and the top 3 pending priorities from the roadmap. Designed to be a quick status check without consuming significant context.

**Output:** Summary (5-10 lines) + link to full files if needed

---

## How It Works

1. **Read identity & roadmap files**
   - Load `.claude/savia-identity.md`
   - Load `.claude/savia-roadmap.md`

2. **Extract current status**
   - Version, health score, grade, tests, skills, agents
   - Name, role, values (brief)
   - Personality summary (1-2 traits)

3. **Query health metrics**
   - Run `bash scripts/workspace-health.sh --json` to fetch current health
   - Extract: Overall score, grade, dimensional scores

4. **Identify top 3 priorities**
   - Parse High-Priority Review section (Eras 96-99)
   - Parse Quality Improvements section
   - Sort by urgency/blocking other items

5. **Format output**
   - Banner: "🦉 Savia Status — [date]"
   - Current identity (2 lines)
   - Health snapshot (1 line)
   - Top 3 priorities (3 lines)
   - Link to `/savia-identity.md` for full profile if needed
   - Optional `--json` output for programmatic consumption

---

## Examples

**Standard Output:**
```
🦉 Savia Status — 2026-03-08

Name: Savia | Role: AI PM Assistant | Version: v2.66.0
Health: 88% (Grade B) | 199 tests | 68 skills | 33 agents

🎯 Top 3 Priorities:
  1. Era 96 (Voice Inbox) — Review approach with Mónica
  2. Security scan refinement — Reduce false positives by 40%
  3. Mobile app kickoff (Android, Flutter/Supabase)

📚 Full profile: .claude/savia-identity.md
📍 Roadmap: .claude/savia-roadmap.md
```

**With --json flag:**
```json
{
  "timestamp": "2026-03-08T10:24:00Z",
  "identity": {
    "name": "Savia",
    "version": "v2.66.0",
    "role": "AI PM Assistant",
    "health": 88,
    "grade": "B"
  },
  "metrics": {
    "tests": 199,
    "skills": 68,
    "commands": 454,
    "agents": 33
  },
  "priorities": [
    {"era": 96, "item": "Voice Inbox", "status": "Review pending"},
    {"item": "Security scan refinement", "status": "In progress"},
    {"item": "Mobile app (Android)", "status": "Kickoff"}
  ]
}
```

---

## Notes

- **Minimal context:** Under 500 tokens total output
- **No conversation:** Strictly status; if PM asks follow-up, escalate to full commands
- **Daily check:** Designed to run at session start or as a quick pulse check
- **Offline:** Works entirely from local files, no API calls needed

## See Also

- `/savia-identity.md` — Full personality profile
- `/savia-roadmap.md` — Complete roadmap and decision log
- `bash scripts/workspace-health.sh` — Detailed health metrics
- `/profile-show` — User profile equivalent
