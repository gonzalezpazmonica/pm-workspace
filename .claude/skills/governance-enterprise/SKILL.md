---
layer: peripheral
name: governance-enterprise
description: "Revisa governance enterprise. Usar cuando se audita compliance o se registran decisiones; nunca emite certificaciones."
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.agent: architect
  savia.maturity: stable
  savia.category: governance
  savia.context: fork
  savia.context_cost: medium
  savia.dependencies: 
  savia.maturity: stable
  savia.memory: project
  savia.priority: high
  savia.summary: "Gobernanza empresarial: audit trail, revisión preliminar de compliance y registro de decisiones."
  savia.tags: "governance, audit-trail, certification, enterprise"
---

# Skill: Enterprise Governance

> Prerequisito: @docs/rules/domain/governance-enterprise.md, @docs/rules/domain/audit-trail-schema.md

Orquesta audit trail, revisión preliminar de cumplimiento y registro de decisiones. Para evaluaciones basadas en evidencia, usar `grc-auditor`.

## Flujo 1 — Audit Trail (`audit-trail`)

1. Leer `.audit-trail/actions.jsonl` (activo) + archive/YYYY-MM.jsonl (histórico)
2. Permitir queries por: usuario, rango fechas, tipo acción, target
3. Generar resumen: total acciones, distribution por tipo, failures
4. Output: tabla de acciones + query stats

**Query examples**:
```
/governance-enterprise audit-trail --user @monica --since 2026-02-01
/governance-enterprise audit-trail --action delete --from 2026-01 --to 2026-03
/governance-enterprise audit-trail --target pbi --result failure
```

## Flujo 2 — Compliance Check (`compliance-check`)

1. Leer governance-enterprise.md (matriz de controles)
2. Por cada control: verificar evidencia más reciente
3. Calcular score por control (0-100 basado en fecha de última ejecución):
   - Fresh (< 30 días) = 100
   - Valid (31-90 días) = 75
   - Stale (91-180 días) = 50
   - Missing (> 180 días) = 0
4. Agregar por categoría (GDPR, ISO, AI, AEPD)
5. Generar `output/governance/compliance-check-YYYYMMDD.md`
6. Output: tabla scores + recomendaciones + remediation plan si needed

## Flujo 3 — Decision Registry (`decision-registry`)

1. Leer decision-registry.md
2. Por cada decisión: validar que tiene evidencia en file system
3. Listar decisiones activas + superseded + revoked
4. Detectar decisiones sin evidencia (gap warning)
5. Generar resumen: total decisiones, distribution por status
6. Output: registry formatted + gaps + next decisions needed

## Flujo 4 — Solicitud de certificación (`certify`)

No emitir certificados ni declaraciones de conformidad, con independencia del score. Responder con un paquete de preparación: alcance, marcos y versiones, controles, evidencias trazadas, brechas y decisiones pendientes. Remitir la certificación formal a la entidad competente. Un umbral numérico interno no prueba eficacia operativa ni otorga autoridad certificadora.

## Errores

| Error | Acción |
|---|---|
| Audit trail no encontrado | Crear `.audit-trail/actions.jsonl` vacío |
| Control sin evidencia | Marcar como gap; no bloquear certificación si ≥ 80% |
| Decision registry corrupto | Validar YAML; mostrar errores |
| Solicitud de certificado oficial | Preparar dossier de evidencias; no certificar |

## Seguridad

- NUNCA exponér audit trail en reports públicos
- Los informes preliminares no se presentan como certificaciones
- Decision registry puede ser compartida (referencias a evidencia, no datos)
- Respect user privacy: después 4 años, anonimizar user field en audit trail
