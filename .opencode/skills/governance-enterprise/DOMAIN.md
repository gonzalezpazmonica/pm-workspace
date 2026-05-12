# Governance Enterprise -- Dominio

## Por que existe esta skill

Los sistemas de IA agentica requieren gobierno visible y auditable. Sin controles formales, no se puede demostrar cumplimiento de GDPR, ISO 27001, EU AI Act ni AEPD. Esta skill centraliza audit trail, verificacion de controles, registro de decisiones y certificacion.

## Conceptos de dominio

- **Audit Trail**: log JSONL append-only de todas las acciones (usuario, accion, target, resultado) con retencion de 4 anos.
- **Matriz de controles**: 28 controles distribuidos en GDPR (9), ISO 27001 (6), EU AI Act (8) y AEPD (5).
- **Decision Registry**: registro inmutable de decisiones significativas con evidencia, participantes y estado.
- **Score de compliance**: 0-100 por control basado en frescura de evidencia (Fresh <30d=100, Missing >180d=0).
- **Certificacion**: documento generado solo si todos los controles >=80%.

## Reglas de negocio que implementa

- governance-enterprise.md: calendario de cumplimiento (quarterly, monthly, weekly, annual, continuous).
- audit-trail-schema.md: formato JSONL con campos obligatorios, rotacion mensual, anonimizacion a 4 anos.
- Certificacion bloqueada si algun control <80%; se genera remediation plan.
- Audit trail nunca se expone en reports publicos.

## Relacion con otras skills

- **Upstream**: rbac-management (control de acceso auditado), regulatory-compliance (deteccion sectorial).
- **Downstream**: executive-reporting (scores de compliance en informes), adversarial-security (hallazgos alimentan controles).
- **Paralelo**: audit-export (exportar trail en JSON/CSV/PDF para auditores externos).

## Decisiones clave

- JSONL sobre base de datos: coherente con .md-is-truth; legible sin herramientas especiales.
- Score por frescura sobre score por profundidad: prioriza controles ejecutados recientemente.
- Certificacion automatica con gate humano: Savia genera, humano firma.
