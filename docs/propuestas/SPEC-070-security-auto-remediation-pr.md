---
id: SPEC-070
title: SPEC-070: Security Auto-Remediation PRs
status: Proposed
origin_date: "2026-03-23"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-070: Security Auto-Remediation PRs

> Status: **DRAFT** · Fecha: 2026-03-23 · Score: 4.60
> Origen: Análisis de usestrix/strix — remediación automática
> Impacto: Cierra el gap entre detectar vulnerabilidades y corregirlas

---

## Problema

El pipeline adversarial (security-attacker -> security-defender -> security-auditor)
detecta vulnerabilidades y propone fixes, pero el output se queda en un informe
markdown. El humano debe aplicar los patches manualmente. Strix genera PRs
automáticos con fixes listos para mergear.

La infraestructura ya existe en pm-workspace: ramas `agent/*`, PR Draft,
`AUTONOMOUS_REVIEWER`. Solo falta conectar el output de security-defender
con la creación del PR.

## Solución

Extender el flujo post-security-defender para que, opcionalmente, materialice
los fixes propuestos en un PR Draft.

## Flujo

```
1. /security-pipeline ejecuta el pipeline completo
2. security-attacker encuentra vulnerabilidades
3. security-defender propone fixes con diff/patch
4. security-auditor valida que los fixes son correctos
5. NUEVO: Savia pregunta "He encontrado N fixes validados. Quieres que cree un PR?"
6. Si afirmativo:
   a. Crear rama: agent/security-fix-{YYYYMMDD}-{vuln-summary}
   b. Aplicar patches propuestos por security-defender
   c. Ejecutar tests (dotnet test / npm test / pytest segun language pack)
   d. Si tests pasan: crear PR Draft
   e. Si tests fallan: informar, no crear PR
   f. PR body incluye: hallazgos, fixes aplicados, score antes/después
   g. Asignar AUTONOMOUS_REVIEWER como reviewer
```

## Restricciones (autonomous-safety.md)

- NUNCA auto-mergear — siempre PR Draft
- NUNCA aplicar fixes sin validacion del auditor
- NUNCA crear PR si tests fallan
- SIEMPRE asignar reviewer humano
- SIEMPRE incluir diff detallado en el body del PR

## Formato del PR

```markdown
## Security Fixes — {fecha}

### Hallazgos corregidos
| # | Severidad | Vulnerabilidad | Fichero | Línea |
|---|-----------|---------------|---------|-------|

### Score de seguridad
- Antes: {score_antes}/100
- Después: {score_despues}/100

### Tests
- Suite: {test_command}
- Resultado: {passed}/{total} passed

### Pipeline
security-attacker -> security-defender -> security-auditor -> PR
```

## Implementación

1. Modificar `.claude/commands/security-pipeline.md` para incluir paso 5-6
2. Reutilizar patron de `autonomous-safety.md` para ramas agent/*
3. El PR se crea con `gh pr create --draft`
4. No requiere nuevo agente — Savia orquesta directamente

## Métricas de éxito

- Tiempo medio entre detección y fix disponible: <5 min (vs horas manual)
- % de PRs de seguridad que pasan tests al primer intento: >80%
- % de PRs aprobados por reviewer sin cambios: >60%

## Dependencias

- `autonomous-safety.md` (existente)
- `adversarial-security.md` (existente)
- `AUTONOMOUS_REVIEWER` configurado en pm-config

## Esfuerzo estimado

Bajo — 1 tarde. Toda la infraestructura existe.
