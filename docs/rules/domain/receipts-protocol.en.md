# Receipts Protocol — claims without verifiable source are marked UNVERIFIED

> **SE-030 Slice 1 — Receipts-first governance**
> Ref: ROADMAP §Tier 4.2 · adopted from bytebell.ai sub-4% hallucination pattern

Every claim an agent makes about code, specs, decisions, or workspace data **must come with a verifiable receipt**. A claim without a receipt is marked `[UNVERIFIED]` and does NOT propagate to Court, Truth Tribunal, or audit reports as evidence.

## 1. When it applies

Applies to claims about repo state: code state, spec content, decisions, test coverage, config / infra.

Does NOT apply to: agent opinions, questions, general reasoning without reference to repo artifacts.

## 2. Canonical format

Four receipt types allowed:

### 2.1 `file` (code / tests / configs)

```yaml
claim: "PatientService already implements IEntity interface"
receipts:
  - file: src/Application/Patients/PatientService.cs
    line: 23
```

Optional `sha: <commit-short>` to pin the claim to a specific commit.

### 2.2 `spec`

```yaml
claim: "The endpoint requires OAuth2 authentication"
receipts:
  - spec: SPEC-120#AC-03
```

Format: `SPEC-ID#anchor` — anchor is a heading or acceptance criterion ID within the spec.

### 2.3 `decision`

```yaml
claim: "The team decided PostgreSQL over MySQL"
receipts:
  - decision: decision-log.md#2026-04-15-postgres
```

Format: `<doc>#<anchor>`. Doc must exist in `docs/` or `projects/*/decisions/`.

### 2.4 `url` (external source)

```yaml
claim: "bytebell reports sub-4% hallucination with receipts"
receipts:
  - url: https://bytebell.ai/blog/three-layer-graphrag
    accessed: 2026-04-19
```

Only for research / references. `accessed` field is mandatory.

## 3. Validator

`scripts/context-receipts-validate.sh` parses agent output (markdown or YAML) and verifies each receipt:

| Check | Method | Severity |
|---|---|---|
| `file:` exists and has that `line` | `test -f && wc -l` | FAIL |
| `spec:` exists in `docs/propuestas/` | `ls` | FAIL |
| `spec#anchor` matches spec heading | `grep` | WARN |
| `decision:` exists | `ls` | FAIL |
| `url:` well formed | regex | WARN |
| Claim without receipts | structural detection | WARN |

Exit codes: `0` all valid · `1` WARN only · `2` FAIL (block pipeline).

## 4. Rollout — gradual

| Phase | Behavior | When |
|---|---|---|
| Phase 1 (now) | WARN on claims without receipt, no block | Slice 1 |
| Phase 2 | FAIL on claims without receipt in Court/Tribunal output | After 2 sprints |
| Phase 3 | FAIL on invalid receipts (file doesn't exist) in any output | After <5% false positives |

Final goal: ≥90% claims with valid receipt, 0% false claims propagated to human.

## 5. Exceptions

- Digest outputs (`/pdf-digest`, `/word-digest`) — full digest acts as receipt.
- Casual conversational mode — protocol applies when generating reports, commits, or PRs.
- Explicit hypotheses marked `[HYPOTHESIS]` — allowed without receipt, never count as evidence.

## 6. Integration

- **Court judges** (correctness-judge, spec-judge): consult receipts before scoring.
- **Truth Tribunal** (source-traceability-judge): vetoes on claims without valid receipt.
- **Commit guardian**: if PR body contains claims without receipt about touched files, WARN.
- **Persisted memory**: engram marked `verified: true` only if claim had receipt at save time.

## 7. Anti-patterns

```markdown
# BAD — claim without receipt
The Patients service is fully tested.

# BAD — invented receipt
Receipts:
  - file: src/Patients/Service.Tests.cs  # doesn't exist

# GOOD
Receipts:
  - file: tests/Application/PatientServiceTests.cs
    line: 1
```

## 8. References

- SE-030 spec: `docs/propuestas/SE-030-graphrag-quality-gates.md`
- Origin: bytebell.ai blog series (Dec'25–Jan'26)
- Truth Tribunal: `docs/agent-teams-sdd.md` §Truth Tribunal
- Spanish version: `docs/rules/domain/receipts-protocol.md`
