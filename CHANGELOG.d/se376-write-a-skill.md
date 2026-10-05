---
version_bump: patch
section: Fixed
---

### Fixed

- write-a-skill calibrada: SKILLS.md sin UTF-8 roto (corte por caracteres), descripciones en bloque sin duplicar, manifest --check sin falsa deriva por generated_at, escritura atómica 0644, auditor con name vacío, líneas sin salto final, --skill sin valor y JSON escapado; G14 de scripts/pre-push-bats-critical.sh (ejecución manual, sin hook de push) vuelve a auditar las skills de .claude/skills y omite las borradas.

