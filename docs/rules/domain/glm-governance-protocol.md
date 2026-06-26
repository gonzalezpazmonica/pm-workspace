---
context_tier: L3
token_budget: 800
resource: internal://docs/rules/domain/glm-governance-protocol.md
se: SE-105
status: IMPLEMENTED
implemented_at: "2026-06-24"
---

# Governance Layer Manifest (GLM v1.0) — Protocol

## What

GLM (Governance Layer Manifest) is a machine-readable declaration format for
AI governance systems. Savia adopts GLM v1.0 to expose its governance
boundaries to external consumers (auditors, procurement, enterprise compliance)
without requiring them to read dispersed markdown documentation.

The canonical manifest lives at `.well-known/governance-layer-manifest.json`.
The operational workspace view is `.opencode/governance-manifest.yaml`.

**Important**: GLM v1.0 is a proposed standard (EVIDE Governance Lab, May 2026),
not yet adopted by a standards body. Drift risk is low but review semiannually.

## Why

Savia has mature governance (75 agents, 81 hooks, 5-layer tribunals, verification
lattice) but no formal machine-readable external declaration. External reviewers
cannot programmatically determine what Savia claims and explicitly does not claim.
GLM closes this gap without replacing existing internal docs.

## Manifest structure

| Field | Purpose |
|---|---|
| `layer.layer_type` | `cross_cutting` — spans all SDD pipeline stages |
| `timing_axis.surfaces` | 5 governance surfaces: substrate/witness/boundary/closure/reviewability |
| `operational_scope.does` | Explicit capability claims |
| `operational_scope.does_not` | Non-claims — prevents misinterpretation |
| `claims_boundary` | Authoritative claim + consumer constraints |
| `composition` | Composable layer types declared |
| `manifest_digest` | SHA-256 tamper evidence |

## When to update the manifest

Update `.well-known/governance-layer-manifest.json` when:

1. A new capability is added (new agent type, new tribunal, new hook)
2. A constraint changes (new enforcement script, rule reference updated)
3. `last_reviewed` is approaching 90 days
4. A new surface is added to `timing_axis.surfaces`
5. Red lines count in `savia-ethical-principles.md` changes

After editing: run `bash scripts/glm-compute-digest.sh` to recompute the digest.
Validate with `bash scripts/glm-validate.sh`.

## How to add a new capability

```yaml
# In .opencode/governance-manifest.yaml
capabilities:
  - id: "my-new-capability"
    description: "What it does"
    audit_trail: true          # true if an audit hook exists
    human_approval_required:   # true if a human gate is required
```

Add the corresponding entry to `operational_scope.does` in the JSON manifest.
If it involves a new non-claim, add to `operational_scope.does_not`.

## How to add a new constraint

```yaml
# In .opencode/governance-manifest.yaml
constraints:
  - id: "my-constraint-id"
    rule: "Rule N CLAUDE.md or spec reference"
    type: "hard"    # hard | soft
    enforcement: "scripts/my-script.sh or hook:my-hook.sh"
```

The `enforcement` path must exist in the repo. `glm-validate.sh` will WARN if
it does not.

## Validation

```bash
# Recompute digest after edits
bash scripts/glm-compute-digest.sh

# Verify digest matches content
bash scripts/glm-verify.sh

# Full manifest validation (paths, recency, JSON validity)
bash scripts/glm-validate.sh
```

## Relationship to existing governance docs

GLM is **descriptive**, not a replacement:

| Existing doc | GLM relationship |
|---|---|
| `docs/rules/domain/ai-governance.md` | Internal canonical — GLM is the external view |
| `docs/rules/domain/audit-trail-schema.md` | GLM references as `substrate` surface |
| `docs/savia-shield.md` | GLM references as `witness` surface |
| `docs/rules/domain/verification-policy.md` | GLM references as `boundary` surface |
| `docs/rules/domain/pr-signing-protocol.md` | GLM references as `closure` surface |
| `.opencode/skills/verification-lattice/SKILL.md` | GLM references as `reviewability` surface |

## Non-claims (AC-2)

GLM requires explicit non-claims to prevent downstream misinterpretation:

- Savia does NOT certify legal validity of outputs
- Savia does NOT substitute human E1 review gate
- Savia does NOT guarantee hallucination absence
- Savia does NOT act as GDPR/EU AI Act authority
- Savia does NOT process confidential data in cloud without Shield
- Savia does NOT provide forensic evidence for legal proceedings
- Savia does NOT issue professional advice (financial/legal/medical)

## References

- Manifest: `.well-known/governance-layer-manifest.json`
- Operational YAML: `.opencode/governance-manifest.yaml`
- Validate: `scripts/glm-validate.sh`
- Compute digest: `scripts/glm-compute-digest.sh`
- Verify digest: `scripts/glm-verify.sh`
- Tests: `tests/bats/test-se-105-glm.bats`
