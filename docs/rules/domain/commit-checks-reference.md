---
globs: [".claude/hooks/**", ".claude/agents/commit-guardian.md"]
---

# Commit Guardian: Checks de Referencia Detallados

> Referencia extraída de `commit-guardian.md`. Contiene implementaciones, verificaciones específicas y ejemplos para cada check.

## CHECK 3 — Build .NET | CHECK 4 — Tests | CHECK 5 — Formato

Detectar cambios: `git diff --cached --name-only | grep -E "\.(cs|csproj)$"`

**Build:** `dotnet build --configuration Release` → Si falla: delegar a `dotnet-developer`
**Tests:** `dotnet test --filter "Category=Unit" --no-build` → Si fallan: delegar a `dotnet-developer`
**Formato:** `dotnet format --verify-no-changes` → Si incorrecto: delegar a `dotnet-developer`

## CHECK 6 — Code Review estático (`.cs`)

Delegar a `code-reviewer` (csharp-rules.md): reportar solo Blocker + Critical.
Veredicto: APROBADO | APROBADO_CON_CAMBIOS_MENORES | RECHAZADO

**Ciclo corrección (máx 2 intentos):**
- RECHAZADO → dotnet-developer → re-run checks 3-5 → re-review
- Si 2do review es RECHAZADO → escalar humano; si APROBADO → continuar

## CHECK 7 — README actualizado

Leer `readme-update.md`. Verificar si staged tocan:
`git diff --cached --name-only | grep -E "^\.claude/(commands|skills|agents|rules)/|^docs/"`

- ✅ README staged o no requería actualización → continuar
- 🔴 Falta README → delegar a `tech-writer` con cambios detectados

## CHECK 8 — CLAUDE.md ≤ 150 líneas

Si `CLAUDE.md` en staged: `wc -l CLAUDE.md`
- ✅ ≤ 150 líneas → continuar
- 🔴 > 150 líneas → delegar a `tech-writer` para comprimir

## CHECK 9 — Atomicidad del commit

Verificar: `git diff --cached --stat` | `git diff --cached --name-only | sed 's|/.*||' | sort -u`

Señales para dividir: > 3 directorios raíz no relacionados | Tipos dispares | > 300 líneas | Propósitos diferentes

Excepciones (NO dividir): Comando + README + pm-workflow | Fix + test | Refactor de módulo

Si debería dividirse: sugerir división, esperar confirmación humano → continuar

## CHECK 10 — Mensaje de commit

Formato: `tipo(scope): descripción`
- Tipo: feat | fix | docs | refactor | chore | test | ci
- Descripción: inglés o español | ≤ 72 caracteres | sin punto final

✅ Correcto → hacer commit | 🟡 Incorrecto → proponer corrección

## TABLA DE DELEGACIÓN

| Problema | Agente a llamar | Información |
|---|---|---|
| Build .NET falla | `dotnet-developer` | Error build + ficheros afectados |
| Tests unitarios fallan | `dotnet-developer` | Nombres tests + error message |
| Formato .NET incorrecto | `dotnet-developer` | Ejecutar `dotnet format` |
| Code review rechazado | `dotnet-developer` | Informe code-reviewer |
| Code review rechazado 2 veces | ❌ Humano | Informe ambos intentos |
| README no actualizado | `tech-writer` | Lista ficheros que requieren update |
| CLAUDE.md > 150 líneas | `tech-writer` | Pedir compresión (preferir @imports) |
| Commit no atómico | ❌ Humano | Sugerencia división — humano decide |
| Secrets/datos privados | ❌ Humano | NUNCA delegar — escalar siempre |
| Commit en main | ❌ Humano | NUNCA delegar — escalar siempre |

## FLUJO DE DELEGACIÓN

Cuando delegas a subagente, usa `Task`:
1. Tipo agente correcto
2. Descripción clara del problema
3. Ficheros afectados
4. Contexto necesario para corregir sin preguntas

Tras corrección: **re-ejecutar el check fallido** para confirmar.
- Si check pasa → continúa con resto
- Si tras 2 intentos sigue fallando → escalar humano
