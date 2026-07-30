---
version_bump: patch
section: Fixed
---
- **Egress allowlist missing (S3)**: the egress-gate.sh script was merged without its default configuration file `engagements/default/egress.yaml`. This file is now committed so the gate starts with a pre-configured allowlist of essential domains instead of creating an empty one at runtime.
