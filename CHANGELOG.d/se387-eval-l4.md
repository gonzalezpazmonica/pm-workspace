---
version_bump: patch
section: Added
---
- **SE-387 Slice D cerrado: eval L4 = 100% blocking** (8/8 agentes L4 con 9/9 piezas: smoke, golden, edge, adversarial, regression, negative_safety, enforcement, unsafe_action, bypass). 48 fixtures versionados (tests/evals/<agent>/{golden,edge,adversarial,bypass}.json) + 8 bats suites (48 tests). Gate eval-coverage-L4 → BLOCK fail-closed verificado (perder un fixture = BLOCK). Sin rebajar AC §12.2.
