# Zero Project Leakage — Regla de Aislamiento Absoluto

> **REGLA INMUTABLE** — Complementa PII-Free (#20) y context-placement (#N4).

## Principio

Los documentos publicos (N1) se redactan como si los proyectos privados
NO EXISTIERAN. Ningun dato derivado de proyectos reales puede aparecer
en codigo, docs, CHANGELOG, releases, commits, PRs ni README del repo.

## Prohibido en artefactos N1

- Conteos derivados de proyectos reales ("95+ entidades", "104 miembros")
- Tamanos de pools calibrados con datos reales ("32 personas, 12 empresas")
- Metricas de rendimiento medidas en proyectos reales ("100ms en produccion")
- Ejemplos basados en estructura real de un proyecto (aunque anonimizados)
- Nombres de ficheros que solo existen en proyectos privados
- Cualquier numero, porcentaje o estadistica que provenga de uso real
- Conteos de vulnerabilidades, scores de seguridad o resultados de auditorias internas
- Limitaciones tecnicas descubiertas en pentests o auditorias (son vectores de ataque)
- Historico de defectos corregidos (la doc publica describe la version actual, no el pasado)

## Que usar en su lugar

| Prohibido | Alternativa |
|-----------|-------------|
| "95+ entidades mapeadas" | "Entidades del proyecto (configurable)" |
| "32 personas, 12 empresas" | "Pools de nombres ficticios configurables" |
| "~100ms en produccion" | "Latencia baja (warm start)" |
| "24 vulns encontradas, 24 resueltas" | No incluir. La doc describe el estado actual |
| "Score seguridad: 100/100" | No incluir. Resultados de auditorias son internos |
| "Sprint 2026-06 de TrazaBios" | "Sprint actual del proyecto activo" |
| Conteo exacto de tests de un proyecto | "Suite de tests automatizados" |

## Regla de redaccion

Al escribir docs publicos, preguntarse:
"Si alguien lee esto, ¿puede deducir algo sobre mis proyectos reales?"
Si la respuesta es SI → reescribir con terminos genericos.

## Aplicacion

- Docs en `docs/` (todas las traducciones)
- README.md y README.en.md
- CHANGELOG.md
- Commits y PRs
- Reglas en `docs/rules/`
- Skills en `.opencode/skills/`

## Verificacion

- `confidentiality-scan.sh` debe detectar numeros sospechosos
- Code review (E1) debe verificar que no hay datos derivados
- El agente de traducciones debe aplicar la misma regla
