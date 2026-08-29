---
version_bump: patch
section: Changed
---

### Changed (saneo de hooks — nombres propios en N3/N4)

- `data-sovereignty-gate.sh`: en destinos **N3/N4 locales** (paths `vaults/`/
  `labs/` o tools MCP de vault) los **nombres propios** (PERSON/ORG/LOC/DATE…)
  ya no bloquean la escritura (override `n3n4_names`, WARN + audit). Las
  credenciales/identificadores (CREDIT_CARD, EMAIL, PHONE, NATIONAL_ID, keys…)
  siguen bloqueadas en todo destino. CRIT-001: los datos N3+ siguen sin salir
  del workspace; escribirlos localmente es el uso previsto.
- 2 tests de integración en `tests/test-data-sovereignty-gate.bats` (override
  con nombres + credencial aún bloqueada).
