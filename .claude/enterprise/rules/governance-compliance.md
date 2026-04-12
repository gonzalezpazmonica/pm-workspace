# Governance & Compliance Pack (SE-006)

> Enterprise module. Requires `governance-pack: { enabled: true }` in manifest.

## Frameworks covered

| Framework | Risk tier | Key artifacts |
|-----------|-----------|---------------|
| EU AI Act | High | Model cards, risk assessment, EIPD |
| NIS2 | High | Security posture, incident log |
| DORA | High | ICT risk register, outsourcing audit |
| GDPR | Medium | DPIA, RoPA, consent log |
| CRA | Medium | SBOM, vulnerability disclosure |
| ISO 42001 | Optional | AI governance policy |

## Audit trail

Append-only JSONL with chain hash (tamper-evident):
- Each entry: timestamp, tenant, actor, action, target, hash, prev_hash
- Chain: each entry includes hash of the previous (simple blockchain)
- Script: `scripts/governance-audit-log.sh` (append/verify/export)
- Export: markdown table or raw JSON for auditor

## Compliance gates (extension point #6)

Optional validators that run in pr-plan or pre-merge:
- `compliance-gate-ai-act.sh` — blocks if spec touches high-risk without EIPD
- `compliance-gate-nis2.sh` — verifies security-review before infra merge
- `compliance-gate-dora.sh` — verifies ICT risk entry in release plans

Gates are no-op when governance-pack module is disabled.

## Model cards

`/ai-model-card AGENT` generates a compliance document per agent:
- Purpose, capabilities, limitations
- LLM model, token budget, permission level
- Bias testing via Equality Shield
- AI Act Annex III classification

## Integration

- **SE-005**: sovereign mode satisfies data residency requirements
- **SE-021**: Court verdicts feed into quality evidence
- **SE-025**: workforce analytics feed into AI transparency disclosure
- **SE-026**: compliance evidence automation consumes audit trail

## Extension point used

EP-6: Compliance Validator (from SE-001 `extension-points.md`).
