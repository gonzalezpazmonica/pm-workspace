---
version_bump: minor
section: Added
---

### Added

- **\`CHANGELOG.d/\`**: nuevo directorio de fragments per-PR. Cada PR crea un fichero en vez de editar CHANGELOG.md al top. Zero-conflict by design (fix root-cause del problema "mergear un PR rompe el CHANGELOG de todos los demás"). README.md documenta lifecycle + pattern.
- **\`scripts/changelog-fragment.sh\`**: helper para crear fragment desde CLI. Flags --slug --version-bump --section --entry (repetible) --from-stdin. Validación estricta de parámetros. Si fragment existe, append idempotente a misma section.
- **\`scripts/changelog-consolidate.sh\`**: consolidador de release. Agrupa fragments por section, calcula siguiente versión (highest bump wins), inyecta nueva entry al top de CHANGELOG.md, añade link line, borra fragments. Modo --dry-run para preview.
- **\`scripts/resolve-all-open-prs.sh\`**: bugfix — snapshot del resolver a tempfile ANTES de checkout para evitar "No such file or directory" al cambiar a branches que no contienen el script. trap EXIT limpia tempfile.

