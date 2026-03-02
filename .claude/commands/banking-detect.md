---
name: banking-detect
description: Auto-detectar proyecto bancario por entidades BIAN, Kafka, Snowflake, SWIFT
developer_type: all
agent: task
context_cost: medium
---

# /banking-detect [--project {nombre}] [--verbose]

> 🏦 Savia detecta si tu proyecto es bancario y sugiere herramientas especializadas.

---

## Cargar perfil

Grupo: **Verticals** — cargar `identity.md` + `projects.md` + `preferences.md`.

## Prerequisitos

- Proyecto activo o `--project` especificado
- Código fuente accesible (local o repo clonado)
- Leer `@.claude/rules/domain/banking-detection.md` para el algoritmo

## Parámetros

- `--project {nombre}` — Proyecto específico (default: proyecto activo)
- `--verbose` — Mostrar detalle por fase

## Flujo

### Paso 1 — Banner y validación

Mostrar: `🏦 Banking Detection · Analizando proyecto...`
Verificar que el proyecto existe y tiene código fuente.

### Paso 2 — Ejecutar 5 fases

Seguir algoritmo de `@.claude/rules/domain/banking-detection.md`:

1. **Domain Entities (35%)** — Buscar Account, Transaction, Settlement, KYC...
2. **Naming & Routes (25%)** — APIs /api/payments, topics Kafka, namespaces Banking.*
3. **Dependencies (15%)** — kafka, snowflake, mlflow, swift-sdk, feast...
4. **Configuration (15%)** — KAFKA_BROKER, SNOWFLAKE_*, SWIFT_*, BIAN_*
5. **Documentation (10%)** — Menciones de BIAN, TOGAF, ArchiMate, ISO 20022

### Paso 3 — Calcular score y clasificar

```
score = (fase1 × 0.35) + (fase2 × 0.25) + (fase3 × 0.15) + (fase4 × 0.15) + (fase5 × 0.10)
```

- ≥55% → `🏦 Proyecto bancario detectado (score: {n}%)`
- 25-54% → `🏦 Posible proyecto bancario (score: {n}%). ¿Confirmas?`
- <25% → `ℹ️ No se detectó perfil bancario. ¿Es un proyecto de banca?`

### Paso 4 — Sugerir herramientas

Si banking confirmado, mostrar:
```
🏦 Herramientas bancarias disponibles:
  /banking-bian            — Validar arquitectura BIAN
  /banking-eda-validate    — Validar pipelines Kafka/EDA
  /banking-data-governance — Auditar gobierno de datos
  /banking-mlops-audit     — Auditar pipeline ML/IA
  /vertical-finance        — Compliance regulatorio (SOX, Basel, PCI DSS)
```

### Paso 5 — Guardar resultado

Guardar en `projects/{proyecto}/.verticals/banking/detection.md` con score por fase.

## Output

```markdown
# 🏦 Banking Detection — {proyecto}

**Score total:** {n}% — {Banking confirmado|Probable|No detectado}

| Fase | Score | Evidencia |
|------|-------|-----------|
| Domain Entities | {n}% | Account, Transaction, Settlement... |
| Naming & Routes | {n}% | /api/payments, payments.* topic... |
| Dependencies | {n}% | kafka, snowflake, mlflow... |
| Configuration | {n}% | KAFKA_BROKER, SNOWFLAKE_ACCOUNT... |
| Documentation | {n}% | BIAN, ISO 20022, settlement... |

**Stack detectado:** {lista de tecnologías}
**Recomendación:** {siguiente comando sugerido}
```

## Restricciones

- **NUNCA** acceder a datos financieros reales
- **SIEMPRE** pedir confirmación en rango 25-54%
- La detección es heurística, no definitiva
