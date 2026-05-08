# Savia's AST Strategy — Code Comprehension and Quality

> Technical document: how Savia uses Abstract Syntax Trees to understand legacy code
> and guarantee the quality of agent-generated code.

---

## The problem it solves

AI agents generate code at high speed. Without structural validation, that code can:
- Introduce blocking async patterns that crash in production
- Create N+1 queries that degrade performance to 10% under real load
- Silence exceptions in empty `catch {}` blocks that hide critical failures
- Modify a 300-line file without understanding its internal dependencies

Savia solves both problems with the same technology: AST.

---

## Quadruple architecture: four purposes, one tree

```
Source code
     │
     ▼
Abstract Syntax Tree (AST)
     │
     ├──► Comprehension (BEFORE editing)          ← PreToolUse hook
     │         Understands what already exists
     │         Does not modify anything
     │         Pre-edit context injection
     │
     ├──► Quality (AFTER generating)              ← PostToolUse async hook
     │         Validates what was just written
     │         12 universal Quality Gates
     │         Report with score 0-100
     │
     ├──► Code Maps (.acm)                        ← Persistent context across sessions
     │         Pre-generated before the session
     │         150 lines max per .acm file
     │         Progressive loading with @include
     │
     └──► Human Maps (.hcm)                       ← Active fight against cognitive debt
               Narrative in natural language
               Validated by humans, not by CI
               Why the code exists, not just what it does
```

The key design decision: the same tree serves four phases of the code lifecycle,
with different tools at different moments in the hook pipeline.

---

## Part 1 — Legacy code comprehension

### The principle

Before an agent edits a file, Savia extracts its structural map.
The agent receives that map in its context, as if it had already read the code.

### Extraction pipeline (3 layers)

```
Target file
      │
      ▼
Layer 1: Tree-sitter (universal, 0 runtime dependencies)
  • All Language Pack languages
  • Classes, functions, methods, enums
  • Import declarations
  • ~1-3s, 95% semantic coverage

      │ (if unavailable)
      ▼
Layer 2: Native semantic language tool
  • Python: ast.walk() (built-in module, 100% precision)
  • TypeScript: ts-morph (full Compiler API)
  • Go: gopls symbols
  • C#: Roslyn SyntaxWalker
  • Rust: cargo check + rustfmt AST
  • Java: javap -c, semgrep
  • ~2-10s, 100% semantic coverage

      │ (if unavailable)
      ▼
Layer 3: Grep-structural (zero absolute dependencies)
  • Universal regex for all 16 languages
  • Extracts classes, functions, imports by pattern
  • <500ms, ~70% semantic coverage
  • Always available — never fails
```

**Guaranteed degradation rule**: if all advanced tools fail, grep-structural always works.
No edit is ever blocked due to a missing tool.

### Automatic trigger: PreToolUse hook

```
User requests file edit
         │
         ▼
Hook: ast-comprehend-hook.sh (PreToolUse, matcher: Edit)
  • Reads file_path from hook's input JSON
  • Checks: does file have ≥50 lines?
  • If yes: runs ast-comprehend.sh --surface-only (15s timeout)
  • Extracts: classes, functions, cyclomatic complexity
  • If complexity > 15: emits visible warning
         │
         ▼
Agent receives in its context:
  ╔══════════════════════════════════════════════════╗
  ║  AST Comprehension — Pre-edit context           ║
  ╚══════════════════════════════════════════════════╝
  File: src/Services/AuthService.cs
  Lines: 248  |  Classes: 1  |  Functions: 12
  Complexity: 42 decision points  ⚠️  Proceed carefully

  Structural map:
  { "classes": [{ "name": "AuthService", "line": 12 }],
    "functions": [{ "name": "ValidateToken", "line": 45 },
                  { "name": "RefreshSession", "line": 120 }] }
         │
         ▼
Agent edits with full context of the file
```

The hook is **non-async** because it must complete BEFORE the agent edits.
The hook always does `exit 0` — comprehension is advisory, never blocks.

### Output: Comprehension Report

Unified JSON format for all languages:

```json
{
  "meta": {
    "file": "src/Services/AuthService.cs",
    "language": "csharp",
    "lines": 248,
    "tool": "roslyn"
  },
  "structure": {
    "classes": [{ "name": "AuthService", "line": 12, "methods": [...] }],
    "functions": [{ "name": "ParseJwt", "line": 300 }],
    "enums": [{ "name": "TokenStatus", "line": 400 }]
  },
  "imports": {
    "external": ["Microsoft.IdentityModel.Tokens"],
    "standard": ["System.Threading.Tasks"]
  },
  "complexity": {
    "total_decision_points": 42,
    "hotspots": [{ "name": "RefreshSession", "complexity": 14, "warn": true }]
  },
  "api_surface": { "public": ["ValidateToken", "RefreshSession"] },
  "summary": "JWT service. 1 class, 12 methods. Hotspot: RefreshSession (CC=14)."
}
```

### Legacy mode usage (`--legacy-mode`)

For inherited projects, the direct command maps everything without thresholds:

```bash
# Map a full legacy project directory
bash scripts/ast-comprehend.sh src/Legacy/ --legacy-mode --output output/legacy-map.json

# Specific file with full report
bash scripts/ast-comprehend.sh src/OldModule.cs --output output/old-module-map.json
```

In legacy mode, neither the 50-line threshold nor the complexity warning applies.
The goal is to document everything, without filters.

---

## Part 2 — Quality of generated code

### The 12 universal Quality Gates

Each gate applies to all languages. Implementation varies; the criterion does not.

| Gate | Name | Classification | Languages |
|------|------|----------------|-----------|
| QG-01 | Blocking async/concurrency | BLOCKER | .NET, TypeScript, Python, Rust |
| QG-02 | N+1 queries | ERROR | .NET, Java, Python, Ruby |
| QG-03 | Null dereference without guard | BLOCKER | .NET, Go, Java, Swift/Kotlin |
| QG-04 | Magic numbers without constant | WARNING | All languages |
| QG-05 | Empty catch / swallowed exceptions | BLOCKER | .NET, Java, TypeScript, Go |
| QG-06 | Cyclomatic complexity >15 | WARNING | All languages |
| QG-07 | Methods >50 lines | INFO | All languages |
| QG-08 | Duplication >15% | WARNING | All languages |
| QG-09 | Hardcoded secrets | BLOCKER | All languages |
| QG-10 | Excessive logging in production | INFO | All languages |
| QG-11 | Dead code | INFO | All languages |
| QG-12 | Business logic without tests | BLOCKER | All languages |

**Blocking gates** (QG-01, QG-03, QG-05, QG-09, QG-12): score drops 10 points per instance.
**Error gates** (QG-02): 10 points per instance.
**Warning gates** (QG-04, QG-06, QG-08): 3 points per instance.
**Info gates** (QG-07, QG-10, QG-11): 1 point per instance.

```
score = 100 - (BLOCKER × 10) - (WARNING × 3) - (INFO × 1)
```

### Validation architecture (3 layers)

```
Generated code
      │
      ▼
Layer 1: Native language linter
  • ESLint (TypeScript/JavaScript) → JSON
  • Ruff (Python) → JSON
  • golangci-lint (Go) → JSON
  • cargo clippy (Rust) → JSON
  • php-cs-fixer + phpstan (PHP) → JSON
  • RuboCop (Ruby) → JSON
  • Fast, integrated, zero-config

      │ (in parallel or as second layer)
      ▼
Layer 2: Semgrep (universal semantic analysis)
  • One YAML file covers 8+ languages
  • 20 custom rules for the 12 Quality Gates
  • Detects: blocking async, N+1, null unsafe, empty catch, secrets
  • Portable across projects and languages

      │ (for .NET, TypeScript with LSP available)
      ▼
Layer 3: LSP / native semantic tool
  • C#: Roslyn, OmniSharp
  • TypeScript: tsserver (deep type checking)
  • Go: gopls
  • More precise, slower, for complex issues
```

### Automatic trigger: PostToolUse async hook

```
Agent writes/edits file
         │
         ▼
Hook: ast-quality-gate-hook.sh (PostToolUse, async, matcher: Edit|Write)
  • Runs in background — does not block the agent
  • Detects language by extension
  • Runs ast-quality-gate.sh on the file
  • Normalizes output to Unified JSON Schema
  • Calculates score (0-100) and grade (A-F)
  • If score < 60 (grade D or F): emits visible alert
  • Saves report to output/ast-quality/
```

The hook is **async** because it runs after writing and must not block the flow.
Timeout is 60s to allow for slow tools (Roslyn, TypeScript LSP).

### Unified JSON Schema

All outputs normalize to the same contract:

```json
{
  "meta": {
    "file": "src/Services/OrderService.cs",
    "language": "csharp",
    "tool_chain": ["dotnet-build", "semgrep"],
    "timestamp": "2026-03-29T10:00:00Z"
  },
  "score": 73,
  "grade": "C",
  "verdict": "ADVISORY",
  "issues": [
    {
      "gate": "QG-01",
      "name": "Blocking async",
      "severity": "BLOCKER",
      "file": "src/Services/OrderService.cs",
      "line": 47,
      "message": "Task.Result can cause deadlock in ASP.NET context",
      "fix": "Use await order.GetAsync() instead of .Result"
    }
  ],
  "summary": {
    "total_issues": 3,
    "blockers": 1,
    "warnings": 2,
    "infos": 0
  }
}
```

---

## Integration in the agent lifecycle

```
Feature development cycle:

[1] EXPLORE — /comprehension-report src/Module/
    └─► Full module map before touching anything
    └─► Identifies hotspots, dependencies, API surface

[2] PLAN — Agent receives spec + structural map
    └─► Informed planning over real code

[3] IMPLEMENT — Agent edits files
    └─► PreToolUse: ast-comprehend-hook.sh
        ├─► Structural map injected into context
        └─► Automatic warning if complexity >15

[4] VALIDATE — Immediately after each write
    └─► PostToolUse: ast-quality-gate-hook.sh (async)
        ├─► 12 Quality Gates executed
        ├─► Score calculated
        └─► Alert if grade < B (score < 80)

[5] REVIEW — code-reviewer evaluates PRs
    └─► Reads ast-quality reports from output/ast-quality/
    └─► Includes findings in code review E1
```

---

## Language Pack support

| Language Pack | Comprehension | Quality Gate | Primary tool |
|---|---|---|---|
| C#/.NET | Roslyn SyntaxWalker | dotnet build + Semgrep | Roslyn |
| TypeScript | ts-morph | ESLint + tsserver | ts-morph |
| Angular/React | ts-morph | ESLint + Semgrep | ts-morph |
| Java/Spring | javap + semgrep | checkstyle + Semgrep | Semgrep |
| Python | ast.walk() built-in | Ruff + Semgrep | ast module |
| Go | gopls symbols | golangci-lint | gopls |
| Rust | cargo check | cargo clippy | Clippy |
| PHP/Laravel | php-parser | php-cs-fixer + phpstan | PHPStan |
| Ruby/Rails | RuboCop AST | RuboCop | RuboCop |
| Swift/iOS | sourcekitten | swiftlint | SwiftLint |
| Kotlin/Android | detekt | detekt | Detekt |
| Flutter/Dart | dart analyze | dart analyze | Dart SDK |
| Terraform/IaC | tflint | tflint + checkov | Checkov |
| COBOL | grep-structural | grep-structural | Grep |
| VB.NET | Roslyn SyntaxWalker | dotnet build + Semgrep | Roslyn |

**Universal fallback**: grep-structural covers all 16 languages when the primary tool
is unavailable. Agents never run out of structural information.

---

## Part 3 — Code Maps for agents (.acm)

### The problem

Every agent session starts from scratch. Without pre-generated context, the agent
consumes 30–60% of its context window exploring the architecture before writing
a single line of code.

Agent Code Maps (.acm) are structural maps persistent across sessions, stored in
`.agent-maps/` and optimized for direct agent consumption.

### Disk structure

```
.agent-maps/
├── INDEX.acm              ← Root navigation entry point
├── domain/
│   ├── entities.acm       ← Domain entities
│   └── services.acm       ← Business services
├── infrastructure/
│   └── repositories.acm   ← Repositories and data access
└── api/
    └── controllers.acm    ← Controllers and endpoints
```

### INDEX.acm — root navigation table

```markdown
---
acm-version: "1.0"
scope: "project-root"
generated: "2026-03-29T10:00:00Z"
stack: "C#/.NET 8 + Azure"
---

| Layer | .acm file | Elements | Priority |
|-------|-----------|----------|----------|
| Domain | domain/entities.acm | 18 entities | 🔴 Critical |
| Application | domain/services.acm | 12 services | 🔴 Critical |
| Infrastructure | infrastructure/repositories.acm | 8 repos | 🟡 High |
| API | api/controllers.acm | 24 endpoints | 🟢 Normal |

@include domain/entities.acm
@include domain/services.acm
```

### .acm frontmatter YAML

```yaml
---
acm-version: "1.0"
scope: "domain/entities"
generated: "2026-03-29T10:00:00Z"
source-hash: "sha256:a3f2c1..."
includes:
  - infrastructure/repositories.acm
depends-on:
  - src/Domain/Entities/
---
```

**150-line limit per .acm**: if it grows, it is automatically split into subdirectories.
**@include system**: progressive on-demand loading — the agent loads only what it needs.

### Freshness model

| State | Condition | Agent action |
|-------|-----------|--------------|
| `fresh` | .acm hash matches source code | Use directly |
| `stale` | Internal changes but structure intact | Use with warning |
| `broken` | Files deleted or public signatures changed | Regenerate before using |

### Integration in the SDD pipeline

.acm files are loaded BEFORE `/spec:generate`. The agent knows the real project
architecture from the first token, without blind exploration.

```
[0] LOAD — /codemap:check && /codemap:load <scope>
    └─► Agent receives pre-generated map of the relevant layer
    └─► Context tokens: exploration → pure reasoning

[1-5] SDD pipeline unchanged
    └─► PreToolUse: ast-comprehend-hook.sh (granular comprehension)
    └─► PostToolUse: ast-quality-gate-hook.sh (async validation)

[post-SDD] UPDATE — /codemap:refresh --incremental
    └─► Only regenerates .acm for modified files
    └─► .dependency-graph.json tracks which .acm cover which sources
```

---

## Part 4 — Human Code Maps (.hcm)

### The problem

Developers spend 58% of their time reading code vs. 42% writing it (Addy Osmani, 2024).
That 58% multiplies in areas with **cognitive debt**: subsystems that someone has to
re-learn every time they touch them because there is no narrative map that pre-digests
the mental journey.

`.hcm` files fight cognitive debt actively: they are the human twin of `.acm` files.
While `.acm` tells an agent "what exists and where", `.hcm` tells a developer
"why it exists and how to think about it".

### .hcm format

```markdown
# {Component} — Human Map (.hcm)
> version: 1.0 | last-walk: YYYY-MM-DD | walk-time: Xmin | debt-score: N/10
> acm-sync: .agent-maps/{component}.acm

## The story (1 paragraph)
What problem it solves, in human language.

## The mental model
How to think about this component. Analogies if they help.

## Entry points (task → where to start)
- To add X → start in {file}:{section}
- If Y fails → entry point is {hook/script}

## Gotchas (non-obvious behaviors)
- What surprises devs who arrive new
- Documented traps in this subsystem

## Why it's built this way
- Design decisions with their motivation
- Trade-offs consciously accepted

## Debt indicators
- Known areas of confusion or pending refactor
```

### Debt Score (0–10)

```
debt_score =
  min((days_since_last_walk / 30) * 2, 4)   # Stale penalty (max 4)
  + complexity_indicator                      # 0-3 (coupling)
  + (1 - test_coverage_ratio) * 3             # Coverage gap (max 3)

0-3: Fresh map
4-6: Review soon
7-10: Active debt — costing money now
```

### Location per project

Each project manages its own maps within its folder:

```
projects/{project}/
├── CLAUDE.md
├── .human-maps/               ← Narrative maps for developers
│   ├── {project}.hcm          ← General project map
│   └── _archived/             ← Deleted or merged components
└── .agent-maps/               ← Structural maps for agents
    ├── {project}.acm
    └── INDEX.acm
```

The root `.human-maps/` directory of the workspace contains only the maps
of pm-workspace itself as a product (not of the managed projects).

### Lifecycle

```
Creation (/codemap:generate-human) → Human validation → Active
         ↓ code changes
      .acm regenerates → .hcm marked stale → Refresh (/codemap:walk)
```

**Immutable rule:** A `.hcm` can never have `last-walk` more recent than its `.acm`.
If the `.acm` is stale, the `.hcm` is too regardless of its own date.

### Commands

```bash
# Generate .hcm draft from .acm + code
/codemap:generate-human projects/my-project/

# Guided re-reading session (refresh)
/codemap:walk my-module

# View debt-scores for all .hcm in the project
/codemap:debt-report

# Force refresh of indicated .hcm
/codemap:refresh-human projects/my-project/.human-maps/my-module.hcm
```

---

## Available commands

```bash
# Comprehend a file
bash scripts/ast-comprehend.sh src/Services/AuthService.cs

# Comprehend a full directory
bash scripts/ast-comprehend.sh src/Module/ --output output/map.json

# Surface-only mode (fast, for hook)
bash scripts/ast-comprehend.sh src/File.cs --surface-only

# Legacy mode (no thresholds, documents everything)
bash scripts/ast-comprehend.sh src/Legacy/ --legacy-mode --output output/legacy.json

# Quality Gate on a file
bash scripts/ast-quality-gate.sh src/Services/OrderService.cs

# Quality Gate on a directory (verifies the full module)
bash scripts/ast-quality-gate.sh src/Module/
```

---

## System guarantees

1. **Never blocks an edit**: RN-COMP-02 — if comprehension fails, exit 0 always
2. **Never destroys code**: RN-COMP-02 — comprehension is read-only
3. **Always has a fallback**: RN-COMP-05 — grep-structural guarantees minimum coverage
4. **Language-agnostic criteria**: the 12 QGs apply equally to all languages
5. **Unified schema**: all outputs are comparable across languages

---

## References

- Comprehension skill: `.opencode/skills/ast-comprehension/SKILL.md`
- Quality skill: `.opencode/skills/ast-quality-gate/SKILL.md`
- Comprehension hook: `.opencode/hooks/ast-comprehend-hook.sh`
- Quality hook: `.opencode/hooks/ast-quality-gate-hook.sh`
- Comprehension script: `scripts/ast-comprehend.sh`
- Quality script: `scripts/ast-quality-gate.sh`
- Semgrep rules: `.opencode/skills/ast-quality-gate/references/semgrep-rules.yaml`
- Comprehension schema: `.opencode/skills/ast-comprehension/references/comprehension-schema.md`
- Quality schema: `.opencode/skills/ast-quality-gate/references/unified-schema.md`
- Code map skill: `.opencode/skills/agent-code-map/SKILL.md`
- Human map rule: `docs/rules/domain/hcm-maps.md`
- Human map skill: `.opencode/skills/human-code-map/SKILL.md`
- Workspace maps: `.human-maps/`
- Project maps: `projects/*/.human-maps/*.hcm`
