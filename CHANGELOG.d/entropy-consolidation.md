---
bump: patch
section: Changed
---

- Consolidación de entropía (SE-380): 1647 → 1623, de vuelta en la baseline. Se retiran 22 scripts sin ningún llamador: envoltorios de savia-vaults ya cubiertos por el MCP, scripts rotos u obsoletos (`labs-self-audit`, `changelog-assemble`, `sync-tags-from-changelog`, `validate-settings-local`, `overnight-roadmap-runner`) e implementaciones de specs sin aprobar (SE-270, SE-271, SE-272, SE-347; las specs lo anotan). Se enlazan `vaults-nextcloud-setup` (desde `vaults-backup-cron`), `frontend-probe` (SE-388) y `prepare-training-data` (SPEC-080). `test-workspace` muestra el ratchet superado como FAIL, no SKIP.
