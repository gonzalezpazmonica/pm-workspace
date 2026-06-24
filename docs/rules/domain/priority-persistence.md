---
context_tier: L2
token_budget: 800
resource: internal://docs/rules/domain/priority-persistence.md
spec: SPEC-154
---

# Regla: Persistencia de los 4 Campos de Priorización

> Contrato de persistencia para V/U/E/score en todo artefacto de trabajo de Savia.

## Los 4 campos obligatorios

```yaml
value: 78           # 1-100 — impacto absoluto. Ver priority-canonical-formula.md.
urgency: 65         # 1-100 — pendiente de degradación temporal. NO ansiedad.
effort_score: 45    # 1-100 — esfuerzo normalizado (4 sub-factores ponderados).
priority_score: 113.3  # = (value × urgency) / effort_score. CALCULADO, no manual.
```

**`priority_score` es siempre calculado por `scripts/priority/score.py`. Nunca se escribe a mano.**

---

## Fuente de verdad por tipo de artefacto

| Artefacto | Fuente de verdad | Campos |
|---|---|---|
| Specs (`docs/propuestas/SPEC-*.md`) | Frontmatter YAML | Los 4 campos en YAML |
| SE entries (`docs/propuestas/SE-*.md`) | Frontmatter YAML | Los 4 campos en YAML |
| Azure DevOps Work Items | ADO custom fields | `Custom.SaviaValue`, etc. (`sync-ado.py` propaga) |
| ToDos de sesión (TodoWrite) | Efímero / en-sesión | Opcional; si presentes, score se computa |
| Debt items | `output/priority-decisions/` | JSON con los 4 campos + trail |

**Bidireccionalidad**: frontmatter → ADO (unidireccional en esta spec). La sincronización inversa ADO → frontmatter es futura.

---

## Política de backfill

### Qué añadir (backfill-specs.py)

1. **Spec con `value`+`urgency`+`effort_score` pero sin `priority_score`**: calcular y añadir.
2. **Spec con campo `priority` (alta/media/baja/P0..P3)**: mapear con tabla heurística y añadir los 4 campos.
3. **Spec sin ninguna metadata de priorización**: añadir `needs-triage: true`. **Nunca inventar números.**

### Qué NO tocar (inmutabilidad)

- Campos `priority` y `effort` narrativos (texto) existentes: **nunca modificar**.
- `priority_score` ya calculado y consistente (±5%): **no reescribir**.
- Specs con `status: IMPLEMENTED` o `archived: true`: **excluir del ranking activo**.

### Validación CI (AC-02, AC-03)

`scripts/priority/validate-spec-frontmatter.sh` verifica:
- Toda spec activa (APPROVED|PROPOSED|IN_PROGRESS|DRAFT|ACCEPTED) tiene los 4 campos **o** `needs-triage: true`.
- `priority_score` = `(value × urgency) / effort_score` con tolerancia ±5%.
- Exit 1 si hay inconsistencias (bloquea CI).

---

## needs-triage

`needs-triage: true` es el único estado válido para specs sin metadata numérica.

- **No bloquea CI** — es un estado reconocido, no un error.
- **El humano debe asignar V/U/E** antes de que la spec entre al ranking activo.
- Un agente NUNCA convierte `needs-triage` a valores numéricos sin confirmación humana (AC-07).

---

## Backfill idempotente (AC: backfill idempotente)

`python3 scripts/priority/backfill-specs.py` es seguro de ejecutar N veces:
- Si los 4 campos ya están y son consistentes: no modifica nada.
- Si `needs-triage: true` ya está: no modifica nada.
- Solo actúa cuando hay algo que añadir y no hay riesgo de sobrescribir datos existentes.

```bash
# Preview sin escribir
python3 scripts/priority/backfill-specs.py --dry-run

# Solo verificar consistencia
python3 scripts/priority/backfill-specs.py --validate

# Validación CI
scripts/priority/validate-spec-frontmatter.sh
```
