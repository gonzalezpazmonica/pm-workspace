---
name: validate-consensus
description: Lanzar panel de 3 jueces para validar specs, PRs y decisiones
argument-hint: "{spec|pr|decision} {ref} [--force] [--explain] [--judges N]"
allowed-tools: [Read, Bash, Glob, Write]
context_cost: medium
---

# /validate-consensus {type} {ref} [options]

> 🦉 Panel de 3 jueces especializados evalúa specs, PRs y decisiones.
> Cada juez independiente. Output: verdict + score + dissents.

---

## Uso

### Specs
```
/validate-consensus spec projects/proyecto/specs/FEATURE-001.spec.md
/validate-consensus spec projects/proyecto/specs/FEATURE-001.spec.md --explain
```

### PRs
```
/validate-consensus pr 42
/validate-consensus pr 42 --force --explain
```

### Decisiones Arquitectónicas
```
/validate-consensus decision docs/decisions/adr-004.md
/validate-consensus decision docs/decisions/adr-004.md --judges 2
```

---

## Opciones

### `--force`
Ejecutar incluso si no está marcada como ambigua/rechazada.
Útil para double-check preventivo.

### `--explain`
Desglose detallado:
- Puntuación por juez + razonamiento
- Cálculo ponderado paso a paso
- Qué hubiera pasado con pesos diferentes

### `--judges N`
Ejecutar solo N jueces (1, 2, o 3). Default: 3.
⚠️ Menos jueces = menor confianza.

### `--override REASON`
Log manual: "PM aprueba a pesar de CONDITIONAL porque...".
Solo auditoría, no cambia verdict.

---

## Output: APPROVED ✅

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ CONSENSUS: APPROVED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Score: 0.82/1.0

▸ reflection-validator: VALIDATED (1.0)
▸ code-reviewer: APROBADO (1.0)
▸ business-analyst: VÁLIDO (0.5)

📄 Detail: output/consensus/.../spec-FEATURE.json
✅ Proceder a implementación.
```

---

## Output: CONDITIONAL ⚠️

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  CONSENSUS: CONDITIONAL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Score: 0.62/1.0

▸ reflection-validator: VALIDATED (1.0)
▸ code-reviewer: CAMBIOS_MENORES (0.5)
▸ business-analyst: INCOMPLETO (0.5)

⚠️  Dissent: business-analyst

💡 Action: Corregir feedback, re-validar.
```

---

## Output: REJECTED ❌

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ CONSENSUS: REJECTED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Score: 0.38/1.0 | VETO: Security

▸ reflection-validator: VALIDATED (1.0)
▸ code-reviewer: RECHAZADO (0.0) — SQL injection risk
▸ business-analyst: INCOMPLETO (0.5)

🔴 SECURITY VETO — Sin merge hasta fijar.

💡 Action: Fix security findings, retry.
```

---

## Integración

**SDD:** opt-in after spec-writer → implement → test
**PR:** mandatory if code-reviewer rejects → APPROVED: merge ok
**ADR:** opt-in for decisions

---

## Restricciones

**Audit:** Cada ejecución persisted en `output/consensus/TIMESTAMP-type-ref.json`

**NUNCA:**
- Override veto manualmente
- Ignorar dissents en CONDITIONAL
- Usar --judges N < 2
- Timeout: máximo 120s

---

## Troubleshooting

| Problema | Solución |
|---|---|
| Spec not found | Verificar path relativo |
| PR not found | Verificar número existe |
| Timeout | Reintentar o --judges 2 |
| Veto triggered | Fix + retry |
