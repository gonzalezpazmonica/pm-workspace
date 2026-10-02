---
version_bump: patch
section: Security
---

### Security

- SE-426 paso 3: la CI verifica la firma de confidencialidad con el secreto CONFIDENTIALITY_HMAC_KEY y la exige (CONFIDENTIALITY_REQUIRE_HMAC=1); el auto-rebase y la consolidación del CHANGELOG re-firman con la clave real, no con una efímera.

