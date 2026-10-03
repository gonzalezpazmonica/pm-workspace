---
version_bump: patch
section: Fixed
---

### Fixed

- ast-quality-gate: sin linter ni semgrep (o con la herramienta rota) daba PASS 100; ahora UNVERIFIED (exit 3) y cada capa declara su estado en `meta.tool_chain`. Los hallazgos de ruff/eslint ya no se descartan cuando la herramienta sale con 1, los gates bloqueantes (QG-01/03/05/09/12) bloquean de verdad, el target inexistente o un flag desconocido da exit 2, `LANG` deja de pisarse con el lenguaje detectado, dotnet/cargo/golangci-lint/tflint/eslint corren dentro del proyecto, los proyectos JavaScript sin tsconfig se detectan, y Java, COBOL y los lenguajes sin reglas Semgrep se marcan `unsupported` en lugar de pasar limpios.
