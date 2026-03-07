# Code Comprehension Report — Domain Context

## Why this skill exists

AI-generated code can be technically correct but opaque to on-call engineers debugging at 3AM. Comprehension reports generate a "mental model" of the code: architecture, key decisions, failure modes, diagnostic heuristics. Reduces MTTR (mean time to repair) from hours to minutes.

## Domain concepts

- **Mental Model** — Structured document: architecture diagram, key algorithms, failure scenarios, diagnostic checklist
- **3AM Test** — Can an on-call engineer diagnose and fix the code without source, in 15 minutes?
- **Failure Scenario** — "If X happens, look for Y in logs Z"
- **Diagnostic Heuristic** — Rules to diagnose: "Timeout = check certificate refresh cycle"
- **Runbook** — Step-by-step for on-call; generated from mental model

## Business rules it implements

- **RN-COMP-01**: Comprehension report required for security/critical code after implementation
- **RN-COMP-02**: Report includes: architecture, algorithms, failure scenarios, diagnostics
- **RN-COMP-03**: Report must be updateable (add findings from incidents)
- **RN-COMP-04**: Code review evaluates "debuggable at 3AM" using report as evidence

## Relationship to other skills

**Upstream:** `spec-driven-development` generates specs that become code; spec is input to comprehension analysis
**Downstream:** `code-review-rules` uses comprehension report to evaluate debuggability
**Parallel:** `dev-session-protocol` completion suggests generating comprehension report

## Key decisions

- **Automated generation** — Parse code + spec → identify architecture, key paths, failure scenarios
- **Incident feedback loop** — When prod incident occurs, update report with new failure modes found
- **Living document** — Report versioned in git alongside code; updated when code changes >20%
