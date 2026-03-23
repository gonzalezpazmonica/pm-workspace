---
name: security-auto-remediation
description: >
  Flujo de auto-remediacion post-pipeline: aplica fixes validados por el auditor,
  ejecuta tests y crea PR Draft en rama agent/security-fix-*. Invocado por
  security-pipeline Fase 4 (SPEC-029). No invocar directamente.
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# Flujo de Auto-Remediacion — security-pipeline Fase 4

Invocado internamente por `/security-pipeline` tras Fase 3 (Auditor).

## Gate de arranque

Verificar TODOS antes de proceder:

- AUTONOMOUS_REVIEWER configurado → si no: error, salir
- `fixes-{fecha}.md` existe → si no: error, no hay fixes
- Audit muestra fixes con estado `verified` → si no: "Auditor no valido ningun fix"
- `git status` limpio → si no: "Cambios sin commitear, limpia antes"

Si alguno falla: informar y salir. No crear rama ni PR.

## Paso 1 — Recopilar fixes verificados

Leer `projects/{proyecto}/security/audit-{fecha}.md`.
Extraer fixes con estado `verified`. Contar N.
Si N == 0: informar y salir.

## Paso 2 — Confirmar con el PM

```
He encontrado {N} fix(es) validados por el auditor:
  - [CRITICAL] SQL injection en AuthController.cs:47
  - [HIGH] Insecure deserialization en PayloadParser.cs:12

Reviewer: {AUTONOMOUS_REVIEWER}
Rama: agent/security-fix-{YYYYMMDD}-{resumen}

Crear PR Draft? [s/n]
```

Si rechaza: salir sin cambios.

## Paso 3 — Crear rama y aplicar patches

```bash
FECHA=$(date +%Y%m%d)
RAMA="agent/security-fix-${FECHA}-$(echo '{resumen}' | tr ' ' '-')"
git checkout -b "${RAMA}"
```

Aplicar cada patch del `fixes-{fecha}.md`.
Si un patch no aplica: registrar, continuar con el siguiente.
Si ningun patch aplica: abortar, volver a rama original, informar.

## Paso 4 — Ejecutar tests

Detectar language pack y ejecutar:

| Stack | Comando |
|-------|---------|
| .NET | `dotnet test --configuration Release` |
| Node/TS | `npm test` |
| Python | `pytest` |
| Java | `mvn test -q` |
| Go | `go test ./...` |

Si tests fallan: NO crear PR. Volver a rama original.
Borrar rama: `git branch -D "${RAMA}"`. Informar con output del fallo.

## Paso 5 — Commit y PR Draft

```bash
git add -A
git commit -m "agent(security): apply ${N} validated fixes [${FECHA}]"
git push -u origin "${RAMA}"
gh pr create --draft \
  --title "Security: ${N} validated fixes [${FECHA}]" \
  --body "## Security Fixes
| # | Severidad | Vulnerabilidad | Fichero |
|---|-----------|---------------|---------|
{tabla}

Score: {antes}/100 -> {despues}/100
Tests: {passed}/{total} passed

> PR automatico via /security-pipeline [SPEC-029]
> Revision humana obligatoria." \
  --reviewer "${AUTONOMOUS_REVIEWER}"
```

## Paso 6 — Informar resultado

```
━━ Auto-Remediacion completada ━━
Rama:     {RAMA}
PR:       {URL} (Draft)
Reviewer: {AUTONOMOUS_REVIEWER}
Fixes:    {N} aplicados
Tests:    {passed}/{total} passed
⚡ /compact
```

## Restricciones (autonomous-safety.md)

- NUNCA auto-mergear ni aprobar
- NUNCA crear PR si tests fallan
- NUNCA aplicar fixes sin validacion del auditor
- SIEMPRE rama agent/* (nunca main/develop/ramas humanas)
- SIEMPRE PR Draft con reviewer humano asignado
