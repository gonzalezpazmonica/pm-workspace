---
version_bump: patch
section: Fixed
---

### Fixed

- context-dome-generate: ya no usa el scan de otro proyecto (aislamiento N4), extrae de verdad las decisiones (grep -E, solo HEAD), no pisa cúpulas editadas a mano ni reescribe sin cambios, frontmatter YAML válido con owners/rutas arbitrarios, --module sin inyección de código, rutas inseguras y symlinks rechazados, exit 1 ante scan corrupto, --min-risk inválido o proyecto inexistente; nuevo --redact-owners y --force

