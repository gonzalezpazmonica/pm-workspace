# Self-Improvement Loop (Rule #21)

## Trigger

After ANY user correction or discovered bug pattern:

1. **Capture**: Add entry to `tasks/lessons.md` with date, category, lesson, source
2. **Deduplicate**: If lesson already exists, update date and source
3. **Max entries**: Keep ≤50 entries. Archive oldest to `tasks/lessons-archive.md`

## Session Start

At the beginning of each session:

1. Read `tasks/lessons.md`
2. Keep top patterns in working memory
3. Actively avoid repeating documented mistakes

## Entry Format

```
| YYYY-MM-DD | category | Concise lesson (1-2 sentences) | Source (user correction, test failure, review) |
```

## Categories

- `PII` — Personal data leaks
- `Git` — Git command errors or workflow issues
- `Testing` — Test pattern mistakes
- `Bash` — Shell scripting gotchas
- `Architecture` — Design decisions and trade-offs
- `Docs` — Documentation errors or omissions
- `Security` — Security-related lessons
- `Performance` — Performance insights

## Anti-Patterns

- NEVER delete lessons without archiving
- NEVER ignore a lesson that matches current context
- NEVER rationalize repeating a documented mistake
