---
context_tier: L2
token_budget: 700
---

# Changed-Line Coverage — el gate real

> El % global de cobertura es baseline, no el gate. No detecta líneas nuevas
> sin test: un PR puede bajar 2% global y aun así no tocar código nuevo. La
> restricción real es **toda línea cambiada/añadida ejercitada por un test**.

## Comandos

```
# .NET: gatear SOLO las líneas tocadas en el diff
dotnet test *.sln --collect "XPlat Code Coverage" --results-directory ./output/test-results
reportgenerator -reports:"./output/test-results/**/coverage.cobertura.xml" -targetdir:"./output/coverage-report" -reporttypes:Cobertura

# python: diff-cover gates changed lines sobre el XML de coverage
diff-cover coverage.xml --fail-under=100 --compare-branch=origin/main
```

## Reglas

- **exit-nonzero obligatorio** cuando se pierde el umbral (`--fail-under`,
  `diff-cover --fail-under`, equivalente). Una capa que imprime un porcentaje
  y sale 0 es un informe, no un gate — se queda verde mientras la cobertura cae.
- La cobertura changed-line se computa contra `origin/main` (o el base branch
  del proyecto), no contra el estado previo del working tree.
- Líneas marcadas como `# pragma: no cover` o equivalentes = decisión explícita,
  registrarla en el informe, no silenciarla.

## Referencias

- Rule: `docs/rules/domain/coverage-scripts.md` (global % = baseline)
- Rule: `docs/rules/domain/checker-fail-closed.md` (checkers caseros fail-closed)
- Ref: AmazingAng/old-coder (MIT) — "Changed-line coverage is the constraint, not global %"
