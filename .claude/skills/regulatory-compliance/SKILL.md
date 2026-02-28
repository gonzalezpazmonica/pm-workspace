---
name: regulatory-compliance
description: Validación de marcos regulatorios por sector — detección automática, compliance checks y corrección
developer_type: all
context_cost: medium
references:
  - references/sector-healthcare.md
  - references/sector-finance.md
  - references/sector-food-agriculture.md
  - references/sector-justice-legal.md
  - references/sector-public-admin.md
  - references/sector-insurance.md
  - references/sector-pharma.md
  - references/sector-energy-utilities.md
  - references/sector-telecom.md
  - references/sector-education.md
  - references/sector-defense-military.md
  - references/sector-transport-automotive.md
---

# Regulatory Compliance Intelligence

## Sector Detection Algorithm (4 fases)

### Fase 1 — File Patterns (40% peso)
Buscar en estructura del proyecto: modelos de dominio, schemas DB, migraciones, DTOs.
Cada sector tiene entidades clave (Patient, Transaction, Product, Case, Citizen, Policy, Batch, GridNode, Subscriber, Student, Asset, Vehicle).

### Fase 2 — Dependencies (30% peso)
Analizar package.json, requirements.txt, .csproj, pom.xml, go.mod, Cargo.toml, composer.json, Gemfile.
Cada sector tiene packages específicos (hl7-fhir, stripe/braintree, food-traceability, etc.).

### Fase 3 — Naming Conventions (20% peso)
Buscar en rutas de API, nombres de controladores, servicios, tablas DB.
Patrones: /api/patients, /api/transactions, /api/products, /api/cases, etc.

### Fase 4 — Configuration (10% peso)
Buscar en .env, config/, appsettings.json: claves específicas de sector.
Ejemplo: HIPAA_MODE, PCI_DSS_ENABLED, FHIR_SERVER_URL, ENS_LEVEL, etc.

## Scoring y Decisión

```
score ≥ 60%  → Sector detectado con confianza → proceder automáticamente
score 30-59% → Sector ambiguo → preguntar usuario con opciones detectadas
score < 30%  → No detectado → preguntar usuario con opción "No regulado (saltar)"
```

Si múltiples sectores puntúan >60%, considerar multi-sector (ej: pharma+food).

## Framework de Compliance Check

Para cada regulación del sector, verificar estas categorías:

### 1. Cifrado y protección de datos
- Datos sensibles cifrados at-rest (AES-256 o superior)
- Transmisión cifrada (TLS 1.2+)
- Gestión de claves documentada

### 2. Audit trails
- Logging de accesos a datos sensibles (quién, cuándo, qué)
- Logs inmutables (append-only)
- Retención según normativa

### 3. Control de acceso
- RBAC o ABAC implementado
- Autenticación multi-factor donde aplique
- Segregación de duties

### 4. Trazabilidad
- Cadena de custodia de datos
- Versionado de registros
- Capacidad de recall/rollback

### 5. Consentimiento y privacidad
- Gestión de consentimiento explícito
- Derecho al olvido implementable
- Minimización de datos

### 6. Interoperabilidad y formatos
- Formatos estándar del sector (FHIR, ISO 20022, XBRL, etc.)
- APIs documentadas según estándar
- Exportación en formatos regulados

## Clasificación de Severidad

| Severidad | Criterio | Acción |
|-----------|----------|--------|
| CRITICAL | Riesgo de breach, multa regulatoria, ilegalidad | Bloquear hasta corregir |
| HIGH | Control de seguridad/auditoría ausente | Corregir en siguiente sprint |
| MEDIUM | Mejora recomendada por la normativa | Backlog |
| LOW | Best practice del sector | Nice to have |

## Auto-Fix Templates

Los fixes automáticos están disponibles para:
- **Cifrado**: Añadir cifrado at-rest/in-transit a campos sensibles
- **Audit log**: Añadir middleware/interceptor de auditoría
- **RBAC**: Scaffolding de roles y permisos
- **Consentimiento**: Modelo de consentimiento + API endpoints
- **Formatos**: Conversión a formato estándar del sector

Fixes que requieren Task manual:
- Cambios arquitectónicos (separación de capas, microservicios)
- Migración de datos existentes
- Integración con sistemas externos (eIDAS, FHIR servers)
- Certificaciones (Common Criteria, ENS nivel alto)

## Integración

- Usa `references/sector-{name}.md` bajo demanda (se carga solo el sector detectado)
- Compatible con regla `ai-governance` existente (añade capa regulatoria)
- Output en `output/compliance/` para histórico y comparación
- Re-verificación tras auto-fix para confirmar corrección
