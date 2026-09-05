# Privacy Laws

## LAW-PRIV-001 — Data sovereignty
Data classified N3+ MUST NOT leave owned infrastructure (CRIT-001), even temporarily or anonymized.
- Verificación: egress-gate, sovereign gating, confidentiality-sign audit.

## LAW-PRIV-002 — No secrets in repo
Credentials MUST NOT be stored in the repository (Rule #1/#9; PAT via file, PII-free repo).
- Verificación: block-credential-leak + block-pat-file-write (SE-374 negative tests).
