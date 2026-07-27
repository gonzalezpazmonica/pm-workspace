---
version_bump: minor
section: Added
---
- **CAPEX/OPEX**: capex-classify.sh with hash-chained ledger; evidence-package.sh with SHA256 integrity; phase-gate.sh for dated+signed transitions; capitalization.rules.yaml (IAS 38 rules).
- **Contractual KPIs**: kpi-catalog-validate.sh rejects self-declared sources; kpi-compute.sh from verifiable artifacts only; custody-chain.sh with hash-chaining; antagonist-gate.sh (anti-Goodhart); review-report.sh with dual-signature amendments.
- **Agent-originated support**: agent-request-validate.sh (human/agent origin); budget-check.sh with enqueue+notify; sla-router.sh (differentiated SLA); escalation-gate.sh (irreversible→human); effort-meter.sh (work not tickets); recurrence-report.sh (automation candidates).
- **External platform interop**: ext-platform-card-validate.sh; gate.sh with deny-by-default; export-gate.sh with client wall; resilience.sh (never blocks).
- **Exit guarantee**: exit-package-generate.sh (7 sections); independence-verify.sh; drill-execute.sh (quarterly); purge-verify.sh (grep=0); dependencies-declare.sh.
