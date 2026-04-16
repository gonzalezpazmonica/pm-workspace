---
name: vertical-healthcare
description: Extensión compliance para healthcare — HIPAA, HL7 FHIR, FDA 21 CFR Part 11
developer_type: all
agent: task
context_cost: high
---

# /vertical-healthcare [--analyze] [--fix] [--lang es|en]

> 🏥 Extensión de cumplimiento normativo para proyectos del sector sanitario.

Verifica conformidad con regulaciones clave de healthcare: HIPAA (Privacy Rule, Security Rule, Breach Notification), HL7 FHIR para intercambio de datos, FDA 21 CFR Part 11 para registros electrónicos.

---

## Parámetros

- `--analyze` — Solo análisis, no modificaciones (default)
- `--fix` — Generar correcciones automáticas para hallazgos
- `--lang` — Idioma del informe: `es` (default) o `en`

---

## Flujo

### Paso 1 — Cargar vertical y contexto

1. Leer `company/vertical.md` y verificar que el sector es healthcare
2. Cargar reglas del skill: `@.claude/skills/regulatory-compliance/references/sector-healthcare.md`
3. Detectar lenguaje principal del proyecto (C#, Python, TypeScript, Java, etc.)
4. Localizar áreas con manipulación de PHI (Protected Health Information)

### Paso 2 — Verificar sector healthcare

Si `company/vertical.md` no marca healthcare:
- Ejecutar detección automática (buscar Patient, MedicalRecord, Diagnosis, etc.)
- Si confidence ≥ 55% → confirmar healthcare
- Si < 25% → avisar que no se detectó healthcare

### Paso 3 — Escanear código para PHI

Buscar patrones que indiquen manejo de datos sensibles:
- Modelos: Patient, MedicalRecord, Prescription, Diagnosis, Treatment
- APIs: `/patients`, `/medical-records`, `/diagnoses`
- Bases de datos: campos `patient_id`, `diagnosis_code`, `ssn`, `mrn`
- Archivos: HL7 messages, FHIR resources, DICOM images
- Logs: acceso a datos de pacientes

### Paso 4 — Verificar HIPAA Privacy Rule

- [ ] Datos PII/PHI clasificados y documentados
- [ ] Mecanismo de consentimiento para procesamiento
- [ ] Política de retención documentada
- [ ] Derechos del paciente: acceso, rectificación, portabilidad
- [ ] Notificación de breach definida (< 60 días)

### Paso 5 — Verificar HIPAA Security Rule

- [ ] Cifrado at-rest (AES-256 mínimo)
- [ ] Cifrado en tránsito (TLS 1.2+)
- [ ] Control de acceso (RBAC con roles médicos)
- [ ] Audit trails (quién accedió a qué, cuándo)
- [ ] Gestión de claves (rotación, almacenamiento seguro)
- [ ] Copias de seguridad (encriptadas, replicadas)

### Paso 6 — Verificar HL7 FHIR

Si el proyecto intercambia datos con otros sistemas sanitarios:
- [ ] Recursos FHIR R4 o R5 bien formados
- [ ] Validación de schemas
- [ ] Seguridad de endpoints (OAuth 2.0)
- [ ] Versionado de API

### Paso 7 — Verificar FDA 21 CFR Part 11

Para sistemas de registros electrónicos:
- [ ] Audit trails inmutables
- [ ] Trazabilidad de cambios (quién, qué, cuándo)
- [ ] Firmas electrónicas (certificados digitales)
- [ ] Validaciones de integridad de datos
- [ ] Gestión de roles con autenticación fuerte

### Paso 8 — Generar informe

Guardar en: `output/healthcare-compliance-{fecha}.md`

```markdown
# Healthcare Compliance — {proyecto}

**Fecha**: {ISO date}
**Regulaciones**: HIPAA, HL7 FHIR, FDA 21 CFR Part 11

## Detección
- Sector: healthcare (confianza {X}%)
- PHI detectada: {sí/no}
- Sistemas afectados: {lista}

## Hallazgos HIPAA Privacy Rule
| Requisito | Estado | Notas |
|---|---|---|
| Consentimiento | ✅/❌ | |
| Retención | ✅/❌ | |
| Derechos paciente | ✅/❌ | |

## Hallazgos HIPAA Security Rule
| Requisito | Estado | Notas |
|---|---|---|
| Cifrado at-rest | ✅/❌ | |
| Audit trails | ✅/❌ | |

## Hallazgos HL7 FHIR
| Requisito | Estado | Notas |
|---|---|---|
| Schemas válidos | ✅/❌ | |
| OAuth 2.0 | ✅/❌ | |

## Score Overall
- HIPAA Privacy: {X}%
- HIPAA Security: {X}%
- HL7 FHIR: {X}%
- FDA 21 CFR Part 11: {X}%
- **Compliance Score**: {X}%

## Acciones requeridas
[listado de fixes]

## Siguientes pasos
- `/compliance-fix` para correcciones automáticas
- Validación con equipo legal
- Auditoría externa trimestral
```

---

## Restricciones

- **NUNCA** dar consejo legal — solo asistencia técnica
- **NUNCA** garantizar compliance 100% — recomendar validación con legal
- Las regulaciones se actualizan frecuentemente — sugerir revisión anual
- HIPAA se aplica en USA, GDPR Art. 9 en UE (salud especialmente protegida)

---

## Integración

- Skill: `@.claude/skills/regulatory-compliance/SKILL.md`
- Regla: `@docs/rules/domain/regulatory-compliance.md`
- Comando relacionado: `/compliance-scan --sector healthcare`

