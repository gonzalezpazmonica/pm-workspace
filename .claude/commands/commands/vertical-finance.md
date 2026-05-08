---
name: vertical-finance
description: Extensión compliance para finanzas — SOX, Basel III, MiFID II, PCI DSS
developer_type: all
agent: task
context_cost: high
---

# /vertical-finance [--analyze] [--fix] [--lang es|en]

> 💰 Extensión de cumplimiento normativo para proyectos del sector financiero.

Verifica conformidad con regulaciones clave de finanzas: SOX (Sarbanes-Oxley) para control interno, Basel III para gestión de riesgos, MiFID II para mercados de valores, PCI DSS para pagos.

---

## Parámetros

- `--analyze` — Solo análisis, no modificaciones (default)
- `--fix` — Generar correcciones automáticas para hallazgos
- `--lang` — Idioma del informe: `es` (default) o `en`

---

## Flujo

### Pasos 1-2 — Cargar contexto y verificar sector
Leer `company/vertical.md`, cargar skill de compliance. Detectar automáticamente modelos financieros (Account, Transaction, Payment, Portfolio, Ledger, KYC, AML). Si score ≥55% → finance confirmado.

### Paso 3 — Escanear código y generar checklist

**Regulaciones a verificar:**

1. **SOX** (Sarbanes-Oxley): Control interno, audit trails, segregación de duties
2. **Basel III**: Capital mínimo, gestión de riesgos, stress testing
3. **MiFID II**: KYC, conflictos de interés, best execution (si aplica)
4. **PCI DSS**: No almacenar PAN, tokenización, TLS 1.2+, audit trails

Marcar cada requisito: ✅ cumplido | ❌ no cumplido | ⚠️ parcial

### Paso 4 — Generar informe

Guardar en: `output/finance-compliance-{fecha}.md` con tabla de hallazgos, scores por regulación y acciones de remedición.

---

## Restricciones

- **NUNCA** dar consejo legal o de cumplimiento normativo
- **NUNCA** acceder a datos financieros reales sin autorización
- Las regulaciones varían por país (SOX USA, MiFID II UE)
- Cumplimiento de PCI DSS requiere terceros certificados

---

## Integración

- Skill: `@.opencode/skills/regulatory-compliance/SKILL.md`
- Regla: `@docs/rules/domain/regulatory-compliance.md`
- Comando relacionado: `/compliance-scan --sector finance`

