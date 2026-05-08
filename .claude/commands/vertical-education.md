---
name: vertical-education
description: Extensión compliance para educación — FERPA, accesibilidad educativa, COPPA
developer_type: all
agent: task
context_cost: high
---

# /vertical-education [--analyze] [--fix] [--lang es|en]

> 🎓 Extensión de cumplimiento normativo para proyectos del sector educativo.

Verifica conformidad con regulaciones clave de educación: FERPA (Family Educational Rights and Privacy Act) para protección de registros de estudiantes, accesibilidad educativa (Section 508, WCAG 2.1), COPPA para menores de 13 años.

---

## Parámetros

- `--analyze` — Solo análisis, no modificaciones (default)
- `--fix` — Generar correcciones automáticas para hallazgos
- `--lang` — Idioma del informe: `es` (default) o `en`

---

## Flujo

### Pasos 1-2 — Cargar contexto y verificar sector
Leer `company/vertical.md`, cargar skill de compliance. Detectar automáticamente modelos educativos (Student, Course, Grade, Enrollment, Teacher, Curriculum). Si score ≥55% → education confirmado.

### Paso 3 — Escanear código y generar checklist

**Regulaciones a verificar:**

1. **FERPA** (USA): Acceso restringido, derechos estudiante, documentación, breach < 60 días
2. **Accesibilidad**: Section 508, WCAG 2.1 AA (contraste, teclado, ARIA, subtítulos)
3. **COPPA** (si aplica): Edad <13, consentimiento parental, no marketing, privacidad clara
4. **LMS**: OAuth 2.0, SSO, logging de acceso, exportación cumpliendo FERPA

Marcar cada requisito: ✅ cumplido | ❌ no cumplido | ⚠️ parcial

### Paso 4 — Generar informe

Guardar en: `output/education-compliance-{fecha}.md` con tabla de hallazgos, scores por regulación y acciones de remedición.

---

## Restricciones

- **NUNCA** dar consejo legal — solo asistencia técnica
- **NUNCA** acceder a datos reales de estudiantes sin autorización
- FERPA es USA — en UE aplica GDPR + protecciones extra para menores
- Accesibilidad es obligatoria, no opcional
- COPPA aplica a servicios dirigidos a menores, no siempre a LMS institucionales

---

## Integración

- Skill: `@.opencode/skills/regulatory-compliance/SKILL.md`
- Regla: `@docs/rules/domain/regulatory-compliance.md`
- Comando relacionado: `/compliance-scan --sector education`

