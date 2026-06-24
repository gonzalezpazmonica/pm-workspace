---
name: commit-guardian-runbook
description: "Los 10 checks detallados, tabla de delegacion, formato de informe y restricciones del agente commit-guardian. Cargar cuando se necesita el detalle completo de la verificacion pre-commit."
summary: |
  Runbook auxiliar del agente commit-guardian.
  Contiene: 10 checks con criterios exactos, tabla de delegacion,
  formato de informe y restricciones absolutas.
maturity: stable
context: fork
context_cost: low
---

# Commit Guardian — Runbook Completo

## Los 10 checks en orden

### CHECK 1 — Rama

```bash
git branch --show-current
```
- OK: cualquier rama excepto `main`
- BLOQUEO ABSOLUTO si rama es `main`. Comunicar humano, NUNCA commit en main.

### CHECK 2 — Seguridad, confidencialidad y datos privados

Delegar SIEMPRE a `security-guardian` para auditar los ficheros staged.
- SECURITY: APROBADO → OK, continuar CHECK 3
- SECURITY: APROBADO_CON_ADVERTENCIAS → continuar, incluir advertencias en informe
- SECURITY: BLOQUEADO → BLOQUEO ABSOLUTO. Escalar humano. NUNCA intentar resolver.

### CHECK 3-5 — .NET (Build, Tests, Formato)

Solo si hay ficheros .cs o .csproj en staged.
Ver detalles en `docs/rules/domain/commit-checks-reference.md`.

```bash
dotnet build --configuration Release 2>&1
dotnet test --filter "Category=Unit" --no-build 2>&1
dotnet format --verify-no-changes 2>&1
```
- Build falla: delegar `dotnet-developer`
- Tests fallan: delegar `dotnet-developer`
- Formato incorrecto: delegar `dotnet-developer`

### CHECK 6 — Code Review estatico

Solo si CHECK 3 detecto cambios .NET y checks 3-5 pasaron.
Delegar a `code-reviewer` para revisar staged mas csharp-rules.md.
- APROBADO: continuar
- APROBADO_CON_CAMBIOS_MENORES: continuar con nota en informe
- RECHAZADO: max 2 intentos de correccion automatica; si no resuelve → escalar humano

### CHECK 7 — README actualizado

Si staged toca `.claude/(commands|skills|agents|rules)/` o `docs/`:
- Verificar que README.md tambien esta staged.
- Si falta → delegar `tech-writer`.

### CHECK 8 — CLAUDE.md menor de 150 lineas

Si CLAUDE.md esta staged: `wc -l CLAUDE.md`
- OK si menor o igual a 150 lineas
- Aviso si entre 130 y 150
- Bloqueo si mayor de 150 → delegar `tech-writer` para compresion con imports

### CHECK 9 — Atomicidad del commit

Verificar que los cambios representan un solo cambio logico revertible.
- Si deberia dividirse: sugerir como dividir y esperar confirmacion del humano.
- Si humano confirma que es un solo cambio: continuar.

### CHECK 10 — Mensaje de commit (Conventional Commits)

Formato: tipo(scope): descripcion
Tipos validos: feat, fix, docs, refactor, chore, test, ci
- Maximo 72 caracteres primera linea, sin punto final
- OK → hacer commit con trailer Co-Authored-By
- Incorrecto → proponer correccion y esperar confirmacion

## Tabla de delegacion

| Problema | Agente | Informacion |
|---|---|---|
| Auditoria seguridad | `security-guardian` | Auditar staged |
| Build .NET falla | `dotnet-developer` | Error build + ficheros staged |
| Tests fallan | `dotnet-developer` | Tests fallidos + error completo |
| Formato incorrecto | `dotnet-developer` | Ejecutar dotnet format |
| Code review rechazado | `dotnet-developer` | Informe completo del revisor |
| Code review rechazado 2 veces | Humano | Informe de ambos intentos |
| README no actualizado | `tech-writer` | Ficheros que requieren docs |
| CLAUDE.md excede limite | `tech-writer` | Pedir compresion con imports |
| Commit no atomico | Humano | Sugerir division — humano decide |
| Datos sensibles | Humano | NUNCA delegar — escalar siempre |
| Commit en main | Humano | NUNCA delegar — escalar siempre |

## Formato del informe pre-commit

```
PRE-COMMIT CHECK — [rama] — [tipo de cambio]

  Check 1 — Rama ......................... OK / BLOQUEADO
  Check 2 — Security audit ............... OK / AVISO / BLOQUEADO
  Check 3 — Build .NET ................... OK / no aplica
  Check 4 — Tests unitarios .............. OK / no aplica
  Check 5 — Formato ...................... OK / no aplica
  Check 6 — Code review .................. OK / AVISO / BLOQUEADO
  Check 7 — README actualizado ........... OK / BLOQUEADO
  Check 8 — CLAUDE.md menor 150 lineas ... OK / [N lineas]
  Check 9 — Atomicidad del commit ........ OK / AVISO
  Check 10 — Mensaje de commit ........... OK / AVISO

  RESULTADO: APROBADO / BLOQUEADO (N checks fallidos)
```

Solo cuando todos checks son OK o no aplica, ejecutar:
```bash
git commit -m "tipo(scope): descripcion" --trailer "Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```
