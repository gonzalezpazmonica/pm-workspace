# BIAN Framework — Reference para pm-workspace

> Banking Industry Architecture Network: estándar de arquitectura empresarial para banca.

---

## Qué es BIAN

Framework de referencia que define cómo estructurar los servicios de un banco en dominios estandarizados. Cada banco mapea sus sistemas a BIAN Service Domains para garantizar interoperabilidad, reutilización y gobierno.

## Service Landscape (dominios principales)

### Business Area: Sales & Service
- **Customer Offer** — Gestión de ofertas y propuestas comerciales
- **Party Authentication** — Verificación de identidad (KYC)
- **Customer Relationship Management** — Ciclo de vida del cliente

### Business Area: Operations & Execution
- **Payment Initiation** — Inicio de transferencias y pagos
- **Payment Execution** — Procesamiento SWIFT, SEPA, doméstico
- **Settlement** — Liquidación de operaciones (T+0, T+1, T+2)
- **Current Account** — Cuentas corrientes y movimientos
- **Deposits** — Depósitos a plazo, cuentas de ahorro
- **Card Transaction** — Procesamiento de tarjetas y TPV

### Business Area: Risk & Compliance
- **Credit Risk** — Scoring, rating, provisiones
- **Market Risk** — VaR, stress testing, escenarios
- **Operational Risk** — Pérdidas operacionales, KRI
- **Regulatory Compliance** — Basel III/IV, MiFID II, PSD2
- **Fraud Detection** — Detección de fraude en tiempo real

### Business Area: Data & Analytics
- **Customer Analytics** — Segmentación, propensión, churn
- **Financial Analytics** — P&L, balance, liquidez
- **Regulatory Reporting** — FINREP, COREP, XBRL

## Mapeo BIAN → Microservicios

```
BIAN Service Domain    → Microservicio típico
──────────────────────────────────────────────
Payment Initiation     → payment-service
Payment Execution      → swift-gateway, sepa-processor
Settlement             → settlement-engine
Current Account        → account-service
Deposits               → deposit-service
Credit Risk            → scoring-service
Fraud Detection        → fraud-detector
Regulatory Compliance  → compliance-service
Customer Analytics     → analytics-service
```

## ArchiMate Viewpoints para banca

### Application Cooperation Viewpoint
Muestra cómo cooperan las aplicaciones (microservicios) entre sí. Esencial para identificar dependencias entre service domains.

### Technology Usage Viewpoint
Mapea servicios a infraestructura: qué corre en Kubernetes, qué usa Kafka, qué consulta Snowflake.

### Business Process Viewpoint
Flujos de negocio: apertura de cuenta, transferencia, scoring crediticio. Cada paso mapeado a un service domain.

## Validación de adherencia

**Nivel 1 — Naming:** ¿Los servicios usan nomenclatura BIAN?
**Nivel 2 — Boundaries:** ¿Cada servicio respeta los límites del service domain?
**Nivel 3 — APIs:** ¿Las APIs siguen los service operations de BIAN?
**Nivel 4 — Data:** ¿Los Business Objects (BO) siguen el metamodelo BIAN?
**Nivel 5 — Governance:** ¿Hay un Architecture Board que valida cambios?

## Patrones comunes de desviación

1. **God Service** — Un microservicio cubre múltiples service domains
2. **Fragmented Domain** — Un service domain partido en demasiados microservicios
3. **Missing Gateway** — Acceso directo a base de datos sin API intermediaria
4. **Coupled Settlement** — Settlement acoplado a payment execution
5. **Shadow IT** — Servicios no registrados en el catálogo de arquitectura

## TOGAF Integration

BIAN opera como contenido (qué) dentro de TOGAF (cómo):
- **TOGAF ADM Phase B** (Business Architecture) → BIAN Business Areas
- **TOGAF ADM Phase C** (Application Architecture) → BIAN Service Domains
- **TOGAF ADM Phase D** (Technology Architecture) → Stack técnico

## Herramientas de modelado

- **Bizzdesign** — Enterprise Architecture Suite con soporte BIAN nativo
- **Sparx Enterprise Architect** — UML + ArchiMate
- **Draw.io / diagrams.net** — ArchiMate stencils gratuitos
- **Archi** — Open source ArchiMate tool
