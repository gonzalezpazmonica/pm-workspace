---
name: governance-certify
description: Checklist de certificación — ISO 42001, EU AI Act, documentación de modelo
developer_type: all
agent: task
context_cost: high
---

# /governance-certify

> 🦉 Preparar certificación de gobernanza de IA.

Validar requisitos, identificar gaps, generar roadmap de certificación.

---

## Flujo

1. **Paso 1** — Cargar marcos aplicables desde `company/vertical.md`
2. **Paso 2** — Verificar requisitos de cada marco
3. **Paso 3** — Ejecutar checklists:
   - Documentación de modelo
   - Políticas de gobernanza
   - Auditoría completada
   - Aprobaciones registradas
4. **Paso 4** — Puntuar readiness (0-100%)
5. **Paso 5** — Identificar gaps y generar roadmap

---

## Marcos de Certificación

### ISO/IEC 42001
- [ ] Política de gobernanza de IA documentada
- [ ] Procesos de evaluación de riesgo
- [ ] Procedimientos de aprobación y control
- [ ] Auditoría interna completada
- [ ] Revisión de dirección
- [ ] Plan de mejora continua

### EU AI Act (Nivel Alto/Crítico)
- [ ] Evaluación de conformidad
- [ ] Documentación de requerimientos
- [ ] Testing y validación
- [ ] Documentación de seguridad y privacidad
- [ ] Plan de monitoreo post-implementación
- [ ] Registro en NFIA (si aplica)

### SOC 2 Type II (AI Controls)
- [ ] Segregación de funciones (quién autoriza qué)
- [ ] Pista de auditoría de acciones
- [ ] Validación de cambios
- [ ] Recuperación ante incidentes
- [ ] Testing de controles

---

## Checklist Detallado

**Documentación** (20 puntos):
- Model card disponible
- Risk assessment documentado
- Governance policy escrita
- Escalation paths claros

**Procesos** (30 puntos):
- Aprobaciones registradas
- Auditoría completada
- Incidentes documentados
- Plan de mejora

**Técnica** (20 puntos):
- Logs de acciones persistentes
- Versioning de políticas
- Testing de controles
- Backup y recuperación

**Mejora Continua** (30 puntos):
- Revisión trimestral de política
- Feedback de usuarios
- Benchmarking vs mejores prácticas
- Formación en gobernanza

---

## Output

Fichero: `output/certification-YYYYMMDD-readiness.md`

Secciones:
- Score de readiness por marco (%)
- Checklist detallado (✓/✗ comentado)
- Gaps identificados (criticidad)
- Roadmap de certificación (hitos, fechas, responsables)
- Estimación de esfuerzo

**Integración**: Output de `/governance-report` y guía para `/governance-policy` revisión.

---

## Recomendación Final

- **> 90%**: Candidato a certificación inmediata
- **70-90%**: 1-2 meses de work para certificación
- **< 70%**: Revisar `/governance-policy` y `/governance-audit` antes
