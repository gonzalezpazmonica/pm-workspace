# Spec: Heavy Context Tools Criteria — "When NOT to use" matrix for ACM/HCM/Graphify

**Task ID:**        SPEC-HEAVY-CONTEXT-CRITERIA
**PBI padre:**      Context optimization discipline (research: Context vs Tokens report 2026-05)
**Sprint:**         2026-09
**Fecha creacion:** 2026-05-13
**Creado por:**     Savia

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     4.5h
**Estado:**         Pendiente
**Max turns:**      25
**Modelo:**         claude-sonnet-4-6

**Depends-on:**     SPEC-CACHE-HIT-TRACKING (must be implemented and have >=14d data; matrix tier thresholds tentative until N>=10 real Opus sessions logged)

---

## 0. Prerequisites (BLOCKING)

This spec CANNOT enter enforcing mode until:

1. SPEC-CACHE-HIT-TRACKING is implemented and `~/.savia/usage.db` exists with
   tables `turns`, `sessions`, `file_state`.
2. New table `heavy_context_invocations` is created with schema:
   ```sql
   CREATE TABLE heavy_context_invocations (
     ts          TEXT NOT NULL,
     tool        TEXT NOT NULL,  -- 'agent-code-map' | 'human-code-map' | 'graphify'
     task_scope  TEXT NOT NULL,  -- 'systemic' | 'cross-module' | 'single-file' | 'lookup'
     model_tier  TEXT NOT NULL,  -- 'heavy' | 'mid' | 'fast'
     project     TEXT,
     outcome     TEXT,           -- 'amortized' | 'wasted' | 'unknown'
     tokens_in   INTEGER,
     tokens_out  INTEGER
   );
   ```
3. At least 14 days of telemetry + at least 10 sessions on `model_tier='heavy'`
   (Opus equivalent) logged. Matrix thresholds for the Opus column remain
   marked `tentative` until N>=10.

While prerequisites are not met, `/heavy-context-recommend` runs in
`advisory` mode: shows matrix from research but does not log decisions or
compute outcomes.

---

## 1. Contexto y Objetivo

El informe "Context vs Tokens" (108 ejecuciones, 2026-05) reveló que:

- **Agent Code Map / Human Code Map / Graphify** son "heavy context tools":
  añaden 5-15K tokens al prompt para dar contexto estructural.
- **Graphify amortiza solo en tareas sistémicas** (refactor cross-cutting,
  análisis de impacto multi-módulo): +21% calidad observada.
- **En tareas single-file o lookup**, heavy context tools NO amortizan:
  baseline gana 2/3 tareas.
- **Solo deepseek-v4-pro** amortiza CAC en tareas medias. Modelos mid (Sonnet,
  DeepSeek-V3) y fast (Haiku) NO amortizan salvo en sistémico.
- **Opus NO testeado** en el informe → cualquier criterio para tier heavy es
  `tentative` hasta acumular N>=10 sesiones reales.

**Problema:** hoy los devs invocan ACM/HCM/Graphify sin criterio claro.
Las skills `agent-code-map`, `human-code-map`, `agentic-flow-graph` no
documentan "cuándo NO usarlas".

**Objetivo:**
1. Añadir cabecera **"When NOT to use"** a las 3 skills.
2. Publicar matriz `task_scope × model_tier → recommendation` en regla
   `heavy-context-tools-criteria.md`.
3. Comando `/heavy-context-recommend` que pregunta scope+tier y devuelve
   decisión + razón.
4. Log de invocaciones para refinar la matriz con datos reales.

---

## 2. Alcance

### Incluye

- Cabecera "When NOT to use" añadida a:
  - `.opencode/skills/agent-code-map/SKILL.md`
  - `.opencode/skills/human-code-map/SKILL.md`
  - Skill o doc equivalente de Graphify (verificar nombre real en el repo).
- Regla `docs/rules/domain/heavy-context-tools-criteria.md` con matriz 4×3.
- Comando `/heavy-context-recommend [scope] [tier]` que devuelve recomendación.
- Tabla `heavy_context_invocations` en `~/.savia/usage.db`.
- Suite BATS con 6+ escenarios (matriz, modo advisory, edge cases).
- Sección "Limitaciones" documentando que la fila `heavy` (Opus) es `tentative`.

### Excluye

- Modificar la lógica interna de ACM/HCM/Graphify.
- Bloquear invocaciones (siempre advisory en esta spec).
- Recalibrar la matriz automáticamente (eso es futura `SPEC-CONTEXT-METRICS-DASHBOARD`).
- Cualquier acción sobre proyectos privados.

---

## 3. Acceptance Criteria

- **AC-01**: Las 3 skills tienen cabecera `## When NOT to use` con 3+ casos
  cada una.
- **AC-02**: Regla `heavy-context-tools-criteria.md` publica la matriz 4×3
  (4 scopes × 3 tiers) con valores: `recommend` | `neutral` | `avoid`.
- **AC-03**: La fila `model_tier=heavy` lleva sufijo `(tentative, N<10)` en
  todas sus celdas mientras prereq #3 no se cumpla.
- **AC-04**: Comando `/heavy-context-recommend systemic heavy` devuelve
  recomendación + razón (1-2 frases) + flag `tentative` si aplica.
- **AC-05**: Comando registra la decisión en `heavy_context_invocations` con
  `outcome='unknown'` (refinable retroactivamente).
- **AC-06**: Si prereqs NO cumplidos, comando muestra banner `[ADVISORY MODE]`
  y omite log.
- **AC-07**: Matriz consistente con el informe Context vs Tokens (revisión
  manual: deepseek-v4-pro=mid amortiza solo `systemic` y `cross-module`).
- **AC-08**: Suite BATS pasa con score >=80 en `test-architect` auditor.

---

## 4. Matriz canónica (publicada en la regla)

| task_scope ↓ / model_tier → | fast (Haiku) | mid (Sonnet/V3) | heavy (Opus/V4-pro) |
|---|---|---|---|
| **systemic** (cross-cutting refactor, impact analysis) | neutral | recommend | recommend `(tentative, N<10)` |
| **cross-module** (touches 3+ modules) | avoid | recommend | recommend `(tentative, N<10)` |
| **single-file** (one file, <500 LOC) | avoid | avoid | neutral `(tentative, N<10)` |
| **lookup** (find symbol, read docstring) | avoid | avoid | avoid `(tentative, N<10)` |

### Definiciones de scope

- **systemic**: cambio que afecta arquitectura global, contracts, o convenciones
  cross-cutting (logging, auth, error handling).
- **cross-module**: cambio que toca 3+ módulos pero NO redefine arquitectura.
- **single-file**: edición confinada a 1 fichero (<500 LOC).
- **lookup**: consulta de símbolo, firma, docstring (sin escritura).

### Definiciones de tier (resolución vía `~/.savia/preferences.yaml`)

- **fast**: alias `model_fast` (latencia <2s, coste bajo).
- **mid**: alias `model_mid` (balanceado).
- **heavy**: alias `model_heavy` (deep reasoning).

---

## 5. Cabecera "When NOT to use" — plantilla

Cada skill afectada añade al inicio (después del frontmatter):

```markdown
## When NOT to use

- **Single-file edits (<500 LOC)**: baseline supera heavy context tools en
  2/3 de tareas según informe Context vs Tokens (2026-05, n=108).
- **Lookups simples**: si solo necesitas leer una firma o docstring, usa
  `Read` o `Grep` directo. ACM/HCM/Graphify cargan 5-15K tokens innecesarios.
- **Modelos fast (Haiku)**: el CAC no se amortiza en ningún scope salvo
  systemic, y aun así con mejora marginal. Usa `Read` selectivo.
- **Cuando el cache hit rate del proyecto está bajo 50%** (ver
  `/cache-analytics`): añadir más contexto agrava el problema.
```

---

## 6. Implementación

### Ficheros a crear

- `scripts/heavy-context-recommend.py` — lógica de matriz + logging.
- `.opencode/commands/heavy-context-recommend.md` — slash command.
- `docs/rules/domain/heavy-context-tools-criteria.md` — regla + matriz.
- `tests/test-heavy-context-recommend.bats` — 6 escenarios.

### Ficheros a editar

- `.opencode/skills/agent-code-map/SKILL.md` — añadir cabecera "When NOT to use".
- `.opencode/skills/human-code-map/SKILL.md` — idem.
- Skill o doc Graphify (verificar) — idem.

### Esquema de salida del comando

```
$ /heavy-context-recommend single-file mid

Decision: AVOID
Reason:   En tareas single-file, baseline gana 2/3 según Context vs Tokens
          (2026-05, n=108). El CAC de ~8K tokens no se amortiza para mid tier.
Logged:   heavy_context_invocations[ts=2026-05-13T18:22:00Z, outcome=unknown]
```

---

## 7. Tests (BATS)

1. **TC-01**: Matriz devuelve `recommend` para `systemic + mid`.
2. **TC-02**: Matriz devuelve `avoid` para `lookup + fast`.
3. **TC-03**: Celdas `heavy` llevan sufijo `(tentative, N<10)` mientras prereq #3 no cumplido.
4. **TC-04**: Modo advisory activo cuando `~/.savia/usage.db` no existe.
5. **TC-05**: Decisión se loguea con `outcome='unknown'`.
6. **TC-06**: Scope o tier inválido → ERROR con mensaje claro + lista de valores válidos.

---

## 8. Definition of Done

- Los 8 AC pasan en CI local.
- Suite BATS verde, auditada por `test-architect` (score >=80).
- Las 3 skills tienen cabecera "When NOT to use" visible.
- Regla publicada y referenciada desde las 3 skills.
- Tabla `heavy_context_invocations` creada en migración de `usage.db`.
- Banner `[ADVISORY MODE]` correcto cuando prereqs faltan.

---

## 9. Riesgos

- **R1**: Matriz se vuelve obsoleta cuando salen modelos nuevos.
  **Mitigación**: tier resolution se basa en alias (`model_fast/mid/heavy`),
  no nombres concretos.
- **R2**: Fila `heavy` puede ser incorrecta — Opus no fue testeado.
  **Mitigación**: sufijo `(tentative, N<10)` explícito hasta acumular datos.
- **R3**: Devs invocan ACM/HCM/Graphify directo sin pasar por
  `/heavy-context-recommend`. **Mitigación**: la cabecera "When NOT to use"
  en cada skill es la barrera principal; el comando es ayuda complementaria.
- **R4**: Outcome=`unknown` nunca se actualiza retroactivamente.
  **Mitigación**: futura `SPEC-CONTEXT-METRICS-DASHBOARD` correlaciona
  invocaciones con cache hit rate posterior para inferir `amortized/wasted`.
