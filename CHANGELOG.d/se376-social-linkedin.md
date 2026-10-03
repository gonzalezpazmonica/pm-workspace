---
version_bump: patch
section: Fixed
---

### Fixed

- social-linkedin: el import reconoce Shares.csv/Shares_<id>.csv y Comments.csv reales (Message, comillas \"), BOM y saltos de línea; respeta SOCIAL_STORE; rechaza almacenes dentro de un repo git y protege la copia raw (0700/0600); ZIP inválido sale con exit 1 sin traceback; los tests ya no escriben en el almacén real.

