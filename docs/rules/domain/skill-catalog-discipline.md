# Regla: Skill Catalog Discipline

> Vocabulario y disciplina obligatorios para CADA skill nuevo o modificado en `.opencode/skills/`. Enforced by pr-plan G14 (SE-084 Slice 2). Pattern source: `mattpocock/skills/write-a-skill/SKILL.md` (MIT, clean-room).

## Por qué

pm-workspace tiene 89+ skills. El LLM lee SOLO el campo `description` del frontmatter al decidir qué skill cargar — sin un trigger explícito ("Use when X"), el agente no distingue entre skills similares y el catálogo entero pierde señal. Skills monolíticos (>200 LOC) cargan completos cada turno → coste recurrente de tokens.

Sin disciplina enforced, el catálogo deriva con cada skill nuevo. Esta regla baja el "tax" recurrente: cada PR que añade o modifica skills pasa por el gate G14 y verifica que el skill cumple criterios mínimos. La regla NO reescribe skills antiguos; aplica only-going-forward.

## Reglas

### 1. Frontmatter obligatorio

Todo `SKILL.md` debe abrir con frontmatter YAML válido:

```yaml
---
name: skill-name        # mismo nombre que el directorio
description: "Capability sentence. Use when [specific triggers]."
---
```

Campos requeridos:

- `name:` — identificador kebab-case del skill (mismo que el directorio)
- `description:` — descripción ≥30 caracteres con patrón `Use when ...` (o equivalente: "Activa cuando", "Trigger when", "use ... when", "when user")

Campos opcionales pero recomendados (convención pm-workspace):

- `summary:` — resumen multi-línea de 2-4 líneas
- `maturity:` — `stable` / `beta` / `experimental`
- `context:` — `fork` / `team` / `enterprise`
- `agent:` — `any` o nombre de agent específico

### 2. Tamaño

- **WARN** si `SKILL.md` > 100 LOC
- **FAIL** si `SKILL.md` > 200 LOC

Skills > 100 LOC deben usar progressive disclosure: SKILL.md como índice/quick-start, contenido extra en ficheros separados linkados (`REFERENCE.md`, `EXAMPLES.md`, `DOMAIN.md`).

### 3. Description trigger discipline

El `description` debe contener:

1. **Capability sentence**: qué hace el skill (1ª frase)
2. **Use-when trigger**: cuándo invocarlo (2ª frase, con la frase literal "Use when ...")

Ejemplo bueno:
```
description: "Spanish-aware sentence splitter for long-form TTS. Use when generating audio from long text, when user mentions 'narrate', 'read aloud', or invokes /tts."
```

Ejemplo malo (sin trigger):
```
description: "Helps with text processing"
```

### 4. Atribución upstream (cuando aplica)

Si el skill adopta un pattern de un repo externo (MIT/permisivo), atribución obligatoria en el cuerpo del SKILL.md:

```markdown
## Atribución
`upstream/repo/path/SKILL.md` — MIT — pattern only, prosa propia.
```

NUNCA copiar texto literal del upstream — clean-room re-implementation.

### 5. Cross-references

Skills que dependen de otra regla canónica deben enlazarla:

- Si usa Module/Interface/Seam vocab → cita `docs/rules/domain/architectural-vocabulary.md` (SE-082)
- Si invoca disciplina TDD → cita `.opencode/skills/tdd-vertical-slices/SKILL.md` (SE-083)
- Si requiere supervisión humana → cita `docs/rules/domain/autonomous-safety.md`

## Enforcement

### Auditor

`scripts/skill-catalog-audit.sh` — modo `--gate --skill <path>` aplicado por pr-plan G14 SOLO sobre skills modificados en el PR (no full catalog). Detecta:

- `missing-frontmatter` (FAIL)
- `missing-name-field` (FAIL)
- `missing-description-field` (FAIL)
- `description-too-short` (FAIL — < 30 chars)
- `description-missing-use-when` (WARN)
- `skill-overlong` (FAIL — > 200 LOC)
- `skill-long` (WARN — > 100 LOC)

### G14 gate (pr-plan)

- Mode `--gate` filtrado a skills modificados en el PR
- Skipped si no hay SKILL.md modificado en el diff
- FAIL si algún skill modificado tiene severity FAIL
- WARN solo se reporta, no bloquea (ratchet only-going-forward)

### Baseline

`.ci-baseline/skill-quality-violations.count` — contador total de violations en el catálogo. NO usado por G14 (que solo evalúa modificados), pero tracker `scripts/baseline-tighten.sh` puede actualizar cuando catálogo mejora.

## Skills problemáticos hoy (NO se reescriben automáticamente)

Skills con `description: >` folded scalar vacía documentados en SE-084 baseline. Se irán arreglando cuando alguien los toque (mismo patrón que agent-size-violations).

## Cross-references

- SE-084 spec — `docs/propuestas/SE-084-skill-catalog-quality-audit.md`
- `scripts/skill-catalog-audit.sh` — auditor (Slice 1, batch 75)
- `.ci-baseline/skill-quality-violations.count` — baseline tracker
- `mattpocock/skills/write-a-skill/SKILL.md` — pattern source (MIT)

## Referencias

- pr-plan gates → `scripts/pr-plan-gates.sh:g14_skill_catalog`
- Auditor → `scripts/skill-catalog-audit.sh`
- Tests → `tests/structure/test-skill-catalog-g14.bats`
