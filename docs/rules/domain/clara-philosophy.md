---
globs: [".opencode/skills/**"]
---

# Clara Philosophy — Multi-Level Documentation Standard

Every skill MUST have dual documentation: **SKILL.md** (HOW) + **DOMAIN.md** (WHY & WHAT).

## The Three Layers

```
ARCHITECTURE.md (why the skill exists within pm-workspace)
        ↓
DOMAIN.md (domain concepts, business rules, relationships)
        ↓
Code / SKILL.md (how to use the skill, implementation details)
```

## DOMAIN.md Specification

**Max 60 lines.** Required sections:

1. **Why this skill exists** (2-3 sentences)
   - Business problem it solves
   - Value proposition to team

2. **Domain concepts** (key terms in this context)
   - 3-5 items with 1-line definitions
   - Use terminology consistently with reglas-negocio.md

3. **Business rules it implements** (RN-XXX references)
   - Which rules this skill enforces
   - Link to traceability matrix

4. **Relationship to other skills** (workflow position)
   - What comes before (Upstream)
   - What comes after (Downstream)
   - Parallel dependencies

5. **Key decisions** (why this approach vs. alternatives)
   - Design choices made
   - Trade-offs accepted

## Validation

`/plugin-validate` checks for:
- ✅ SKILL.md exists in every skill directory
- ✅ DOMAIN.md exists in every skill directory
- ✅ DOMAIN.md ≤ 60 lines
- ✅ Required sections present
- ✅ No orphaned domains (domain skills not in skills/)

## Spanish Content

All DOMAIN.md files MUST be in Spanish (matching pm-workspace language standard).
Section headers: "Por qué existe esta skill", "Conceptos de dominio", etc.

## Rollout

Applied to top 10 skills (Era 58):
- pbi-decomposition, product-discovery, rules-traceability
- spec-driven-development, capacity-planning, sprint-management
- azure-devops-queries, scheduled-messaging, context-caching
- code-comprehension-report

Extend to all skills in future releases as documentation is backfilled.
