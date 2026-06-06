---
name: vertical-detection
description: Algoritmo de detección de verticales no-software para proponer extensiones a pm-workspace
auto_load: false
paths: []
context_tier: L3
token_budget: 1036
---

# Detección de Verticales — Algoritmo 5 Fases

> 🦉 Savia detecta cuándo un proyecto pertenece a una vertical específica y propone extensiones.

---

## Concepto

pm-workspace está diseñado para gestión de proyectos de software, pero puede detectar cuando un usuario trabaja en verticales no-software (sanidad, legal, industrial, agrícola, educación, etc.) y proponer extensiones especializadas.

---

## Algoritmo de 5 Fases

Reutiliza el modelo de `regulatory-compliance` pero para verticales de industria.

### Fase 1 — Entidades de dominio (peso: 35%)

Buscar entidades clave en el código, specs y documentación:

Vertical | Entidades señal
---|---
Healthcare | Patient, Diagnosis, Treatment, Prescription, Medical, Clinical, FHIR
Legal | Case, Contract, Clause, Court, Filing, Litigation, Verdict
Industrial | Machine, Equipment, Maintenance, SCADA, PLC, Sensor, Calibration
Agriculture | Crop, Harvest, Irrigation, Soil, Fertilizer, Livestock, Yield
Education | Student, Course, Enrollment, Curriculum, Grade, Teacher, Syllabus
Finance | Portfolio, Transaction, Ledger, Compliance, KYC, AML, Settlement
Logistics | Shipment, Warehouse, Route, Tracking, Inventory, Freight
Real Estate | Property, Lease, Tenant, Appraisal, Mortgage, Listing
Energy | Grid, Turbine, Solar, Emission, Meter, Consumption, Tariff
Hospitality | Reservation, Guest, Room, Booking, Check-in, Menu, Service

### Fase 2 — Naming y rutas API (peso: 25%)

Patrones en rutas, endpoints y naming:

- `/api/patients`, `/api/cases`, `/api/equipment`
- Modelos: `PatientModel`, `CaseRecord`, `MachineLog`
- Tablas: `patients`, `legal_cases`, `maintenance_orders`
- Servicios: `DiagnosisService`, `ContractService`, `HarvestService`

### Fase 3 — Dependencias sectoriales (peso: 15%)

Paquetes y librerías específicas del sector:

Vertical | Dependencias señal
---|---
Healthcare | hl7-fhir, dicom, openehr, medplum
Legal | docassemble, clio-api, legal-nlp
Industrial | opc-ua, mqtt, modbus, scada-tools
Agriculture | agro-api, soil-sensor, farm-management
Finance | plaid, stripe-treasury, bloomberg-api

### Fase 4 — Configuración especializada (peso: 15%)

Variables de entorno y config que delatan vertical:

- `HIPAA_MODE`, `GDPR_HEALTH`, `HL7_ENDPOINT`
- `LEGAL_DISCOVERY_PATH`, `COURT_API_KEY`
- `SCADA_HOST`, `PLC_PROTOCOL`, `MAINTENANCE_SCHEDULE`
- `CROP_REGION`, `IRRIGATION_SYSTEM`

### Fase 5 — Documentación y README (peso: 10%)

Menciones del sector en documentación:

- README con "hospital", "clínica", "paciente"
- Docs con "contrato", "demanda", "juzgado"
- Specs con "planta", "mantenimiento", "producción"

---

## Scoring y Decisión

Score | Acción
---|---
≥ 55% | Auto-detectar vertical, informar al usuario, proponer extensión
25–54% | Preguntar al usuario si es correcto el sector detectado
< 25% | Ignorar, asumir proyecto de software genérico

---

## Estructura de Extensión Vertical

Cuando se detecta o confirma una vertical, Savia propone crear:

```
projects/{proyecto}/.verticals/{nombre}/
├── rules.md          — Reglas específicas del sector
├── workflows.md      — Flujos de trabajo especializados
├── entities.md       — Entidades de dominio del sector
├── compliance.md     — Requisitos regulatorios del sector
└── examples/         — Ejemplos y plantillas
```

---

## Integración con Perfil

Durante `/profile-setup`, si el usuario describe su rol y no es software:

1. Detectar vertical del rol descrito
2. Preguntar al usuario si quiere habilitar extensión vertical
3. Si acepta → generar estructura en el proyecto
4. Opción de contribuir al repo: `/contribute pr "Vertical: {nombre}"`

---

## Privacidad

- **NUNCA** incluir datos del proyecto del usuario en la propuesta de vertical
- **NUNCA** enviar información del sector sin consentimiento
- Solo proponer extensiones genéricas basadas en patrones detectados
- Reutilizar `validate_privacy()` de `scripts/contribute.sh`
