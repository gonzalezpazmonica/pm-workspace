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
agent_notes: "projects/{proyecto}/agent-notes/{ticket}-*.md" (optional, docs/agent-notes-protocol.md)
```

## Output Schema

```
output/comprehension/
├── YYYYMMDD-{task-slug}-mental-model.md    [main report, 5-8 pages, max 15]
├── YYYYMMDD-{task-slug}-flow.mermaid       [diagram source]
└── YYYYMMDD-{task-slug}-flow.png           [only if mmdc is installed]
```

`{task-slug}`: task-id with every character outside `[A-Za-z0-9._-]` replaced
by `-` (`AB#1234` -> `AB-1234`, `sprint-12/feature-auth` -> `sprint-12-feature-auth`).

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
