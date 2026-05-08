# Code Comprehension Report — Input/Output Schemas

## Input Schema

```yaml
task_id: "AB#1234" or "sprint-12/feature-auth"
spec_path: "projects/repo/specs/feature.spec.md"
commit: "a3f9b2c" (optional — auto-detect from spec if omitted)
code_files:
  - "src/AuthService.cs"
  - "src/AuthController.cs"
  - "tests/AuthServiceTests.cs"
test_results: "dotnet test output" (optional — extract if not provided)
agent_notes: ".claude/agent-notes/{task-id}.md" (optional)
```

## Output Schema

```
output/comprehension/
├── YYYYMMDD-{task-id}-mental-model.md    [main report, 5-8 pages]
├── YYYYMMDD-{task-id}-flow.mermaid       [diagram source]
└── YYYYMMDD-{task-id}-flow.png           [diagram PNG export]
```

## Failure Heuristic Template

```
Module: AuthService.ValidateToken()
├─ If it fails with "TokenExpired" → probably: clock skew or cert rotation
│  ├─ Look at: /var/log/auth, certctl list
│  └─ Key metric: time diff (server vs. client)
├─ If it fails with "InvalidSignature" → probably: wrong secret loaded
│  ├─ Look at: config.json, secret vault logs
│  └─ Key metric: secret version timestamp
└─ If it fails with "AccessDenied" → probably: wrong role or scope
   ├─ Look at: JWT claims, role mapping table
   └─ Key metric: user_id in claims vs. database
```
