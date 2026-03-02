---
name: vertical-legal
description: Extensión compliance para legal — GDPR, eDiscovery, contract lifecycle
developer_type: all
agent: task
context_cost: high
---

# /vertical-legal [--analyze] [--fix] [--lang es|en]

> ⚖️ Extensión de cumplimiento normativo para proyectos del sector legal.

Verifica conformidad con regulaciones clave de legal: GDPR (Reglamento General de Protección de Datos), eDiscovery para litigios, contract lifecycle management, data retention y legal hold.

---

## Parámetros

- `--analyze` — Solo análisis, no modificaciones (default)
- `--fix` — Generar correcciones automáticas para hallazgos
- `--lang` — Idioma del informe: `es` (default) o `en`

---

## Flujo

### Pasos 1-2 — Cargar contexto y verificar sector
Leer `company/vertical.md`, cargar skill de compliance. Detectar automáticamente modelos legales (Case, Contract, Evidence, Party, Filing). Si score ≥55% → legal confirmado.

### Paso 3 — Escanear código y generar checklist

**Regulaciones a verificar:**

1. **GDPR**: Base legal, DPIA, derechos interesado, breach < 72h
2. **eDiscovery**: Legal hold, cadena custodia, privilege log, OCR
3. **Contract Lifecycle**: Versionado, aprobaciones, renovación, almacenamiento auditable
4. **Data Retention**: Política documentada, destrucción automática, excepciones legal hold

Marcar cada requisito: ✅ cumplido | ❌ no cumplido | ⚠️ parcial

### Paso 4 — Generar informe

Guardar en: `output/legal-compliance-{fecha}.md` con tabla de hallazgos, scores por regulación y acciones de remedición.

---

## Restricciones

- **NUNCA** dar consejo legal — solo asistencia técnica
- **NUNCA** acceder a contenido confidencial de casos sin autorización
- GDPR se aplica en UE/EEE, CCPA en California, etc. — adaptar según jurisdicción
- Privilege attorney-client no debe procesarse automáticamente

---

## Integración

- Skill: `@.claude/skills/regulatory-compliance/SKILL.md`
- Regla: `@.claude/rules/domain/regulatory-compliance.md`
- Comando relacionado: `/compliance-scan --sector justice`

