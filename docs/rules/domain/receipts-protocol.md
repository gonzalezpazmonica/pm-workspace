# Receipts Protocol — SE-030

> **Receipt-first governance**: toda afirmación de un agente sobre código, spec o decisión debe incluir citas verificables. Inspirado en bytebell sub-4% hallucination paper.

## Principio

**"No proof means no answer."**

Un claim sin receipt NO cuenta como evidencia para el Code Review Court ni para propagar decisiones. Se marca automáticamente como `[UNVERIFIED]` y pierde peso en `memory-importance`.

## Formato canónico

Al final de cualquier claim relevante, bloque YAML:

```yaml
claim: "PatientService ya implementa la interfaz IEntity"
receipts:
  - file: src/Application/Patients/PatientService.cs
    line: 23
    sha: abc123de
  - spec: SPEC-120#AC-03
  - decision: decision-log.md#2026-04-15-patient-service
```

## Tipos de receipt

| Tipo | Sintaxis | Ejemplo |
|---|---|---|
| **file** | `file: path/to/file.ext` + `line: N` + `sha: SHA` | `src/Foo.cs:42@abc123` |
| **spec** | `spec: SPEC-NNN#AC-MM` | `SPEC-120#AC-03` |
| **decision** | `decision: decision-log.md#anchor` | `decision-log.md#2026-04-15-x` |
| **commit** | `commit: SHA` + optional `message` | `commit: abc123d — fix auth` |
| **pr** | `pr: NNN` | `pr: 593` |
| **test** | `test: path/to/test.ext` + optional `case` | `test: tests/foo.bats:test-01` |
| **external** | `url: https://...` + `accessed: ISO-date` | bytebell citations |

## Rules

1. **Verificabilidad**: cada receipt debe poder comprobarse sin contexto humano (open file, check line, run test).
2. **Atomicidad**: 1 claim = 1+ receipts distintos. Multi-receipt = AND.
3. **SHA cuando tocable**: file receipts incluyen sha del commit HEAD al momento del claim.
4. **Inmutabilidad**: si el archivo cambió tras el claim, el receipt queda stale — validator lo marca.
5. **Source hierarchy** (SE-030-H): weight peso por tipo de fuente (code > docs > chat > external).

## Validación

`scripts/context-receipts-validate.sh --input agent-output.md`:

```
PASS | 8 claims with valid receipts
WARN | 2 claims unverified (no receipt attached)
FAIL | 0 invalid receipts
```

Exit codes:
- `0` — todos los claims con receipts válidos
- `1` — algún claim sin receipt (warning, no bloqueante en rollout inicial)
- `2` — receipt roto (archivo no existe, SHA inválido, línea fuera de rango)

## Integración

### Con el Code Review Court

- `correctness-judge`, `security-judge`, etc. **exigen** receipts en sus findings.
- `pr-agent-judge` (SPEC-124) también.
- Un verdict sin receipts vale peso 0.3 (sólo confirmatorio, no probatorio).

### Con memory-importance

Engrams con receipts válidos se retienen con `retention_bonus = 1.5`.
Sin receipt → peso base.

### Con Knowledge Graph (SE-028, SPEC-123)

Al crear un edge temporal, el campo `evidence` ES el receipt:

```json
{
  "from": "person:laura",
  "to": "pbi:PBI-001",
  "relation": "owns",
  "valid_from": "2026-04-15T09:00Z",
  "evidence": "commit:abc123de"
}
```

## Rollout

- **Fase 1 (actual)**: Validator emite WARN. Metrics recolectadas sin bloquear.
- **Fase 2 (+2 sprints)**: Agents `correctness-judge`, `security-judge` exigen receipts en findings.
- **Fase 3 (+4 sprints)**: Hard gate — PR sin receipts en claims críticos bloquea merge.

## Anti-patterns

- ❌ "El código probablemente funciona porque vi tests similares" (sin receipt)
- ❌ "Según mi memoria, esto está en SPEC-XXX" (sin spec#AC)
- ❌ "Creo que Laura lo decidió la semana pasada" (sin decision-log anchor)
- ❌ Link a web sin `accessed: ISO-date` (el contenido cambia)

## Ejemplos buenos

```yaml
claim: "validate-handoff.sh detecta missing spec field con exit 2"
receipts:
  - file: scripts/validate-handoff.sh
    line: 106
    sha: 9e1cc6f2
  - test: tests/test-handoff-as-function.bats
    case: "negative: missing spec field rejected with exit 2"
  - spec: SPEC-121#AC-04
```

## Referencias

- [bytebell — Sub-4% Hallucination Copilot](https://bytebell.ai/blog) Oct '25
- SE-030 — `docs/propuestas/SE-030-graphrag-quality-gates.md`
- Rule #24 Radical Honesty — `docs/rules/domain/radical-honesty.md`
