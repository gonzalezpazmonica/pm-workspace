---
id: SE-079
title: SE-079 — pr-plan G13 scope-trace gate (anti scope-creep)
status: APPROVED
origin: Karpathy "Surgical Changes" principle (forrestchang/andrej-karpathy-skills) — review 2026-04-26
author: Savia
priority: media
effort: S 3h
related: pr-plan, code-reviewer, SE-058 (G11 PR summary)
approved_at: "2026-04-26"
applied_at: null
expires: "2026-06-26"
era: 189
---

# SE-079 — pr-plan G13 scope-trace gate

## Why

Cada PR debería poder contestar a una pregunta simple: **"¿qué línea cambiada justifica qué línea del spec?"**. Hoy ningún gate fuerza esa correspondencia. El `code-reviewer` la mira post-hoc, el revisor humano la coge a ojo, y el resultado es scope-creep silencioso — refactors colaterales, comentarios añadidos "ya que estaba", edits en archivos que el spec no toca.

El review del repo `forrestchang/andrej-karpathy-skills` (sub-agente, 2026-04-26) destacó el principio de Karpathy "Surgical Changes": cada hunk del diff debe trazar a una línea del request. La política ya existe implícitamente en `radical-honesty.md` ("don't add features beyond what the task requires"), pero NO está enforced — y todo lo que no se mide se erosiona.

Cost of inaction: revisor humano sigue siendo el firewall contra scope-creep, lo cual es exactamente lo opuesto a la dirección de SE-074 (paralelismo) — más PRs simultáneos, más fatiga, más leakage.

Cost of action: ~3h. Reusa plumbing existente (`gate "G13"`), no requiere cambios fuera de `pr-plan`.

## Scope (Slice único, S 3h)

`scripts/pr-plan-gates.sh` — añadir función `g13_scope_trace`:

1. **Detectar el spec referenciado** en el PR — primero busca `Spec ref:` en `.pr-summary.md` (G11), luego en mensajes de commit, luego en el branch name (`agent/se074-...` → `SE-074`).
   - Si no encuentra spec → **skip con warning** (no fail; hay PRs legítimos sin spec: docs, hooks tooling, regenerated indices).

2. **Listar los archivos cambiados** del PR (`git diff --name-only main...HEAD`).

3. **Cargar acceptance criteria** del spec encontrado (líneas con `- [ ] AC-XX` o `- [x] AC-XX`).

4. **Verificar trazabilidad por hunk**:
   - Cada archivo cambiado debe matchear contra **al menos uno** de:
     - El path del spec (`docs/propuestas/SE-079-*.md` — el propio spec)
     - Un AC explícito que mencione el path o el componente (heurística: tokenizar AC, buscar overlap con basename del archivo)
     - Un fragment de CHANGELOG.d/ (siempre permitido)
     - Una whitelist de paths de soporte (`.scm/`, `.confidentiality-signature`)
   - Si ≥1 archivo no matchea → fail con tabla `archivo → AC sugerido | NO MATCH`.

5. **Override opt-in** vía `.pr-summary.md`: una línea `Scope-trace: skip — <razón>` desactiva el gate para ese PR (registrada en audit, requiere razón ≥10 chars).

## Acceptance criteria

- [ ] AC-01 `g13_scope_trace` función existe en `scripts/pr-plan-gates.sh`
- [ ] AC-02 `gate "G13" "Scope-trace audit" g13_scope_trace` registrado en `pr-plan.sh`
- [ ] AC-03 PR con archivo no cubierto por ningún AC → exit 1, output muestra tabla `archivo → NO MATCH`
- [ ] AC-04 PR sin spec ref detectable → skip con warning, no fail
- [ ] AC-05 `Scope-trace: skip — <razón ≥10 chars>` en .pr-summary.md desactiva el gate y queda registrado
- [ ] AC-06 CHANGELOG.d/ fragments y .scm/ paths son siempre aceptados (whitelist hard-coded)
- [ ] AC-07 Tests BATS ≥10 score ≥80 — golden tests con un PR sintético "trazable" y otro "scope-creep"
- [ ] AC-08 Doc en `docs/rules/domain/pr-plan-gates.md` (sección nueva) o creación de `pr-plan-scope-trace.md`
- [ ] AC-09 CHANGELOG entry

## No hace

- NO bloquea PRs sin spec — sólo PRs CON spec donde el diff diverge (autonomous-safety: no-op fallback, never silent corruption)
- NO interpreta semánticamente los AC (zero LLM calls — match heurístico determinístico)
- NO enforced en branches `chore/*` o commits con tag `[skip-scope]` (existing pattern)
- NO bloquea por archivos AÑADIDOS sin AC explícito (sólo "no matchea ningún AC" — añadir un fichero nuevo está cubierto si su path aparece o si pertenece al componente del spec)

## Heurística de matching (concreta)

Para cada archivo cambiado, marcar como "matched" si CUALQUIERA de estas condiciones se cumple:

1. **Whitelist hard-coded** (siempre permitido):
   - `CHANGELOG.d/*`, `CHANGELOG.md`
   - `.scm/*`, `.confidentiality-signature`
   - `.pr-summary.md`

2. **Spec self-reference**: el archivo ES el spec o un test que cita el spec en su header.

3. **Token overlap**: tokenizar el `basename` del archivo (sin extensión, split por `-` y `_`) y los AC del spec. Match si comparten ≥1 token de longitud ≥4 caracteres (filtra ruido como "the", "and").
   - Ejemplo: `parallel-specs-merge-queue.sh` ↔ AC-10 "PR queue manager" → match por "queue".

4. **Path prefix match**: si un AC menciona explícitamente un path (`scripts/foo.sh`, `tests/structure/`, `docs/rules/domain/`), prefix-match contra el archivo.

Si ningún archivo falla las 4 reglas → gate PASS. Si ≥1 archivo falla → gate FAIL con tabla.

## Riesgos

| Riesgo | Prob | Impacto | Mitigación |
|---|---|---|---|
| Falsos positivos por basename mal tokenizado | Media | Bajo | Mecanismo `Scope-trace: skip` con razón |
| AC con typos no matchean nunca | Baja | Medio | El gate es informativo en primer pase; tras 2 sprints, escalar a hard-fail |
| PRs grandes (50+ archivos) → output ilegible | Media | Bajo | Limitar tabla a 10 primeras filas + `... (N más)` |
| Gate añade ~2s a cada `pr-plan` | Alta | Bajo | Heurística pure-bash, sin LLM, target <1s |

## Dependencias y pre-requisitos

- ✅ G11 `.pr-summary.md` natural-language summary obligatorio (batch 58)
- ✅ Spec frontmatter convention (`id: SE-XXX`) estable
- ✅ AC format `- [ ] AC-XX` consistente en specs nuevos (post Era 187)
- ⚠️ Specs antiguos pueden tener AC con formato heterogéneo → soft-fail en transición

## Slicing approval gate

Slice único S 3h NO arranca hasta que:
1. La usuaria apruebe explícitamente el spec (este doc en status APPROVED ya cumple)
2. Pre-flight contra los 5 PRs más recientes mergeados — verificar que el gate hubiera sido "PASS" en todos (calibración: si genera ruido sobre PRs limpios reales, ajustar heurística antes de mergear).

## Comparativa vs status quo

| Métrica | Hoy | Con G13 |
|---|---|---|
| Detección scope-creep | Manual en code review humano | Automática pre-push |
| Tiempo extra `pr-plan` | 0 | <1s |
| Falsos positivos esperados | n/a | ~5% (mitigado por skip + whitelist) |
| PRs paralelos seguros (SE-074) | Bottleneck en revisor | Detección temprana, revisor más rápido |

## Referencias

- **Pattern alignment**: implementa Genesis **B9 GOAL STEWARD** + el output emite **B8 ATTENTION ANCHOR** — ver `docs/rules/domain/attention-anchor.md` (SE-080)
- forrestchang/andrej-karpathy-skills — review sub-agente 2026-04-26 (origen del principio "Surgical Changes")
- Andrej Karpathy LLM coding pitfalls (tweet original referenciado en repo upstream)
- `docs/rules/domain/radical-honesty.md` — Rule #24, "don't add features beyond what the task requires"
- `docs/rules/domain/autonomous-safety.md` — gates inviolables (referencia para tono del fail mode)
- `scripts/pr-plan-gates.sh` — plumbing existente (G0–G12)
- `.opencode/commands/pr-plan.md` — comando público
- SE-058 batch 58 — G11 `.pr-summary.md` natural-language summary (gate del que parte la detección de spec ref)

## OpenCode Implementation Plan

### Bindings touched

| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| pr-plan gates | `scripts/pr-plan-gates.sh` (puro bash) | idéntico, ambos frontends invocan el mismo script |
| Spec referencia | `Spec ref:` line in `.pr-summary.md` o commit msg | idéntico, convención compartida |
| AC parsing | regex `^- \[[ x]\] AC-` | idéntico |
| Whitelist | hard-coded array bash | idéntico |
| Skip override | `Scope-trace: skip — <reason>` line | idéntico |

### Verification protocol

- [ ] Smoke test: ejecutar `pr-plan` desde Claude Code y desde OpenCode v1.14 sobre la misma branch — output del gate debe ser byte-idéntico
- [ ] Tests BATS no requieren frontend (puro bash + git)
- [ ] Heurística de matching no usa ninguna API LLM — verificación: `grep -E "claude|opencode|api\.anthropic" scripts/pr-plan-gates.sh` retorna 0 líneas en la sección de g13

### Portability classification

- [x] **PURE_BASH**: gate es 100% bash + git + grep. Indiferente al motor LLM. La detección de spec ref usa convenciones de archivos y paths, no contenido generado.
