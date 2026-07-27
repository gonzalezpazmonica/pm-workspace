---
version_bump: minor
section: Added
---
- **Judge wiring (S1)**: judge-routing.yaml with 28 judge rows and auto-trigger policies; judge-routing-verify.sh for parity checks; judge-trigger-detector.sh for dormant judge detection; judge-anti-fatigue.sh for fatigue scoring; judge-auto-router.sh hook for proactive firing.
- **Action shape (S2)**: action-shape-classifier.sh with novelty/impact scoring and pre-execution safety checks.
- **Egress control (S3)**: egress-gate.sh with domain whitelist, blocked-attempt logging, and operator-only expansion.
- **Unlimited auth (S4)**: unlimited-auth-detector.sh for detecting instructions missing explicit limits.
- **Source corroboration (S5)**: source-corroborator.sh with config/source-authority.yaml for external source verification.
- **Trajectory detection (S6)**: trajectory-detector.sh for behavioral deviation detection within minutes.
- **Objective contracts (S7)**: objective-contract.sh with mandatory antagonist pairs (security, confidentiality, ethics, reversibility) and automatic halt on antagonist degradation.
