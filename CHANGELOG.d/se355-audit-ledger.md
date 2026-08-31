---
version_bump: patch
section: Added
---

### Added

- SE-355 Audit Ledger metadata-only + decision receipts: `scripts/audit-receipts.sh` registra acciones con vocabulario cerrado (`enforced_deny/enforced_allow/success/failure`) y marca `enforced: true` solo cuando un gate de código gobernó la decisión. Ledger local `data/audit/actions.jsonl`, sin prompts/PII, retention 30 días con pruning batch, `governed` para decisiones gobernadas. 12 bats tests + doc de non-claims.
