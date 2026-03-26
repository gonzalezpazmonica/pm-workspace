# Análisis de Gaps: Grandes Consultoras Tecnológicas y Cómo los Resuelve pm-workspace

🌐 [English versión](../guides_en/guide-enterprise-gap-analysis.md)

> Este documento identifica los problemas operativos más comunes en grandes consultoras tecnológicas (500-5.000 empleados) y detalla cómo pm-workspace/Savia los resuelve con comandos, reglas y skills concretos.

**Complementa a**: [Guía de Gran Consultora Tecnológica](guide-enterprise-consultancy.md)

---

## 1. Silos de Conocimiento entre Equipos

### El problema

En consultoras con 20-50+ proyectos concurrentes, cada equipo desarrolla sus propios patrones, decisiones de arquitectura y lecciones aprendidas de forma aislada. Un estudio de McKinsey (2025) estima que los silos de datos cuestan a las empresas aproximadamente 3,1 billones de dólares anuales en ingresos y productividad perdidos. Los empleados dedican casi el 29% de su semana laboral a buscar información que ya existe en otro lugar de la organización.

### Impacto en la consultora

- El equipo de banca resuelve un problema de autenticación que el equipo de seguros resolvió hace 3 meses
- No existe un registro centralizado de decisiones de arquitectura (ADRs)
- La rotación de personal (habitual en consultoras) destruye conocimiento no documentado
- Cada proyecto reinventa plantillas, procesos y estándares

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Memoria persistente de agentes | `/agent-memory` | Los agentes recuerdan decisiones, patrones y lecciones entre sesiones. 3 scopes: project, local, user |
| Búsqueda cross-proyecto | `/scale-optimizer knowledge-search` | Busca patrones, decisiones y specs en todos los proyectos de la organización |
| SaviaHub centralizado | `/savia-hub` | Repositorio Git compartido que sindica identidad, clientes, proyectos y specs |
| Priming de conocimiento | `/knowledge-prime` | Documenta patrones organizacionales en formato Fowler de 7 secciones reutilizables |
| SDD como documentación viva | `/spec-review`, `/sdd-status` | Cada feature tiene spec, implementación y tests vinculados — nunca quedan sin documentar |

**Resultado**: El conocimiento deja de vivir en cabezas individuales o hilos de chat. Vive en Git, buscable, versionado y persistente.

---

## 2. Coordinación Deficiente entre Equipos

### El problema

Cuando 5-10 equipos trabajan en paralelo para el mismo cliente o en el mismo programa, las dependencias entre equipos se convierten en el principal cuello de botella. Las reuniones de coordinación se multiplican (8-12 semanales en consultoras grandes) y las dependencias bloqueantes no se detectan hasta que ya han causado retraso.

### Impacto en la consultora

- Un equipo espera 2 semanas por una API que otro equipo aún no ha priorizado
- Las reuniones de sincronización consumen el 30-40% del tiempo de PMs y Tech Leads
- No hay visibilidad de dependencias circulares hasta que el sprint fracasa
- El Dir. Operaciones no tiene una foto real de la carga entre equipos

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Coordinación multi-equipo | `/team-orchestrator` | Crea equipos con Team Topologies (stream-aligned, platform, enabling), asigna miembros, detecta dependencias |
| Detección de dependencias | `/team-orchestrator deps` | Identifica bloqueos (blocking, informational, shared-resource), incluye alertas de dependencias circulares |
| Sincronización de estado | `/team-orchestrator sync` | Actualiza estado de todos los equipos del departamento en un solo comando |
| Dashboard multi-equipo | `/enterprise-dashboard team-health` | SPACE framework: satisfacción, rendimiento, actividad, comunicación, eficiencia por equipo |
| Métricas cross-equipo | Regla `team-structure.md` | Dependency Health Index, Cross-team WIP, Sync Overhead — métricas cuantificables |

**Resultado**: De 8-12 reuniones semanales de coordinación a 2-3, con dependencias visibles, bloqueantes detectados automáticamente y escalado definido.

---

## 3. Opacidad Financiera por Proyecto

### El problema

En grandes consultoras, conocer el coste real de un proyecto (no el estimado, sino el actual) es sorprendentemente difícil. Las hojas de tiempo viven en un sistema, los costes de infraestructura en otro, las licencias de herramientas en un tercero. El CFO recibe datos consolidados con semanas de retraso.

### Impacto en la consultora

- No se detectan proyectos que superan presupuesto hasta que el desvío es crítico (+20-30%)
- Facturación manual que consume 2-3 días/mes por PM
- Imposibilidad de comparar rentabilidad entre proyectos o clientes en tiempo real
- Forecasting basado en intuición, no en datos (CPI, SPI, EAC)

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Registro de costes | `/cost-center log` | Append-only ledger en JSONL — cada entrada inmutable y auditable |
| Alertas de presupuesto | Regla `cost-tracking.md` | Alertas automáticas al 50%, 75% y 90% del presupuesto |
| Forecasting con EVM | `/cost-center forecast` | Earned Value Management: EAC = BAC / CPI, CPI = EV / AC, SPI = EV / PV |
| Facturación por cliente | `/cost-center invoice` | Genera facturas desde timesheets con rate tables configurables |
| Reporting financiero | `/cost-center report` | Burn rate, rentabilidad, comparativa entre proyectos y periodos |

**Resultado**: El CFO tiene datos financieros en tiempo real por proyecto, cliente y equipo. El PM detecta desvíos cuando son del 5%, no del 30%.

---

## 4. Comunicación Fragmentada con Stakeholders

### El problema

Según el PMI, la mala comunicación es responsable de un tercio de todos los fracasos de proyectos. En una consultora, cada proyecto tiene múltiples stakeholders (cliente final, dirección interna, equipo técnico, compliance) que necesitan información diferente en formatos distintos. Los PMs pasan horas creando reportes manuales adaptados a cada audiencia.

### Impacto en la consultora

- El CEO quiere ROI y margen; el CTO quiere deuda técnica y arquitectura; el cliente quiere avance y plazos
- Información contradictoria entre reportes genera desconfianza
- Los reportes se generan con datos de hace 1-2 semanas
- Un PM gestionando 3 proyectos dedica el 40% del tiempo a reportes

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Reportes ejecutivos | `/ceo-report` | Dashboard para CEO/CFO: velocity, ROI, time-to-market, riesgos |
| Dashboard enterprise | `/enterprise-dashboard portfolio` | Vista agregada de toda la cartera: proyectos activos, en riesgo, compliance |
| Output adaptativo | Regla `adaptive-output.md` | 3 modos automáticos: Coaching (junior), Executive (dirección), Technical (senior) |
| Reportes Excel | `/excel-report` | Multi-pestaña: capacity, CEO, time-tracking — listos para entregar al cliente |
| Métricas DORA | `/org-metrics` | Deployment frequency, lead time, MTTR, change failure rate — estándar industry |
| Standup automatizado | `/daily-standup` | Resumen diario por equipo, enviable a Slack sin reunión presencial |

**Resultado**: Cada stakeholder recibe información relevante en su formato y profundidad adecuados, generada automáticamente desde datos vivos, no desde reportes manuales de la semana pasada.

---

## 5. Falta de Control de Acceso y Gobernanza

### El problema

En una consultora que trabaja para banca, seguros y administración pública simultáneamente, un desarrollador del proyecto A no debería ver datos del proyecto B. Sin embargo, la mayoría de herramientas PM tratan a todos los usuarios como iguales o requieren configuración manual compleja.

### Impacto en la consultora

- Riesgo de exposición de datos entre clientes (GDPR, AEPD)
- No hay registro auditable de quién accede a qué
- Compliance manual: hojas Excel para demostrar controles ante auditorías
- No hay segregación de roles más allá de "admin" y "usuario"

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| RBAC 4 niveles | `/rbac-manager` | Admin, PM, Contributor, Viewer — permisos granulares por proyecto |
| Audit trail inmutable | `/governance-enterprise audit-trail` | JSONL append-only con rotación mensual. Quién hizo qué, cuándo |
| Compliance checks | `/governance-enterprise compliance-check` | Verificación automática GDPR, AEPD, ISO 27001, EU AI Act |
| Decisión registry | `/governance-enterprise decisión-registry` | Registro inmutable de decisiones con justificación y responsable |
| Certificación | `/governance-enterprise certify` | Genera evidencia de cumplimiento para auditorías externas |
| PII Gate | Hook `hook-pii-gate.sh` | Scanner pre-push que bloquea commits con datos personales |

**Resultado**: Segregación real por roles, audit trail inmutable para auditorías, compliance automático — todo sin herramientas externas ni hojas Excel.

---

## 6. Onboarding Lento y Pérdida de Contexto

### El problema

Las grandes consultoras tienen alta rotación (15-25% anual) y reasignaciones frecuentes entre proyectos. Cada incorporación consume 2-4 semanas hasta que la persona es productiva. El conocimiento del proyecto vive en la cabeza del PM anterior, en hilos de Slack archivados y en documentos desactualizados.

### Impacto en la consultora

- 2-4 semanas de improductividad por cada nueva incorporación
- El PM saliente se va sin transferir todo el contexto
- Checklists de onboarding genéricos que no se adaptan al rol
- 100+ incorporaciones/año × 3 semanas = 300 semanas-persona perdidas

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Importación masiva | `/onboard-enterprise import` | CSV batch: nombre, email, rol, equipo, proyecto — provisioning automático |
| Checklists por rol | `/onboard-enterprise checklist` | Checklists específicos para Admin, PM, Dev, QA — con seguimiento de progreso |
| Transferencia de conocimiento | `/onboard-enterprise knowledge-transfer` | Protocolo estructurado: contexto del proyecto, decisiones clave, contactos, riesgos |
| Entrevista de contexto | `/context-interview` | 8 fases estructuradas: dominio, stakeholders, stack, restricciones, compliance |
| Memoria de Savia | `/savia-recall` | Savia recuerda el contexto del proyecto y lo transmite al nuevo miembro |
| Evaluación de competencias | `/team-onboarding` | Evaluación automática de skills del nuevo miembro para asignación óptima |

**Resultado**: De 2-4 semanas a 3-5 días de onboarding. El contexto vive en el repositorio, no en personas.

---

## 7. Vendor Lock-in y Pérdida de Soberanía

### El problema

Según Capgemini (2025), el 75% de las organizaciones buscan consolidación de vendors, frente al 29% en 2020. Las consultoras dependen de Jira, Confluence, Azure DevOps, Monday.com — cada una con sus formatos propietarios, sus APIs cambiantes y sus incrementos anuales de precio. El coste real no son solo las licencias: es la imposibilidad de marcharse.

### Impacto en la consultora

- €50K-200K/año en licencias de herramientas PM que no son tuyas
- Migrar de Jira a otra herramienta cuesta 6-12 meses y €100K+
- La inteligencia organizacional (cómo ejecutar proyectos) queda capturada en la plataforma del vendor
- El vendor cambia precios, métricas de facturación o términos de servicio sin previo aviso

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Sovereignty Score | `/sovereignty-audit` | 5 dimensiones: portabilidad de datos, independencia LLM, protección del grafo organizacional, gobernanza de consumo, optionalidad de salida |
| Todo es Git | Arquitectura core | Specs en Markdown, datos en JSONL/YAML, configs en frontmatter — formato abierto, portable |
| Sin base de datos propietaria | Filosofía Git-first | Git es la fuente de verdad. Sin PostgreSQL obligatorio, sin servidor API obligatorio |
| Código abierto | Licencia MIT/Apache | Todo el código (incluidos RBAC, costos, gobernanza) es open-source |
| Exit plan | `/sovereignty-audit exit-plan` | Genera plan concreto para migrar datos a cualquier otra herramienta |
| Coste ~7K€/año | vs 61K€ Jira, 35K€ Linear | Solo se paga Claude (200€/usuario/año). pm-workspace es gratis |

**Resultado**: Tus datos, tu conocimiento, tu inteligencia organizacional — todo vive en Git, en tu infraestructura, bajo tu control. Sin lock-in técnico, contractual ni cognitivo.

---

## 8. Scope Creep No Detectado

### El problema

Los stakeholders introducen cambios "pequeños" sin proceso formal. Según datos del sector, el scope creep causa el 50% de los desvíos en proyectos. En consultoras, el problema se amplifica porque el cliente final tiene acceso directo al equipo y los cambios se acuerdan en llamadas informales que nunca se reflejan en el backlog.

### Impacto en la consultora

- Features que aparecen en el sprint sin spec ni estimación
- El equipo entrega más de lo acordado pero factura lo mismo
- No hay trazabilidad de quién solicitó qué cambio y cuándo
- Los sprints fallan por sobrecarga no planificada

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Snapshots de backlog | `/backlog-git snapshot` | Foto inmutable del backlog en cada sprint — detecta cambios no autorizados |
| Detección de scope creep | `/backlog-git deviation-report` | Compara snapshots: items añadidos, eliminados, re-estimados sin aprobación |
| SDD obligatorio | Regla `spec-driven-development` | Ninguna feature se implementa sin spec aprobada — el agente rechaza código sin spec |
| PR Guardian | CI/CD `pr-guardian.yml` | 8 gates automáticos: si la spec no existe o está desactualizada, el PR se bloquea |
| Audit trail | `/governance-enterprise decisión-registry` | Cada cambio de alcance queda registrado con responsable y justificación |

**Resultado**: Los cambios no autorizados se detectan automáticamente. Si no hay spec, no hay código. Si no hay decisión registrada, no hay cambio de alcance.

---

## 9. Calidad Inconsistente entre Proyectos

### El problema

Con 20-50 proyectos concurrentes, cada equipo aplica sus propios estándares de calidad. Un proyecto tiene 80% de test coverage, otro tiene 20%. Un equipo documenta ADRs, otro no documenta nada. No hay forma de comparar la salud de proyectos entre sí.

### Impacto en la consultora

- El cliente A recibe calidad excelente, el cliente B recibe calidad mediocre
- No hay benchmarks internos para medir mejora
- Los bugs en producción varían 3-5x entre equipos
- La reputación de la consultora depende del equipo asignado, no de la organización

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Scoring por dimensiones | Regla `scoring-curves.md` | 6 curvas calibradas: PR size, context usage, file size, velocity, test coverage, Brier score |
| Comparación entre refs | `/score-diff` | Compara salud del workspace entre cualquier par de commits o ramas |
| Severidad Rule of Three | Regla `severity-classification.md` | 3+ problemas = CRITICAL, 2 = WARNING, 1 = INFO. Escalado temporal automático |
| Validación por consenso | `/validate-consensus` | Panel de 3 jueces (reflection, code-review, business) con scoring ponderado |
| Coherence check | `/check-coherence` | Verifica que specs, código y tests están alineados con los objetivos declarados |
| 14 pre-commit hooks | Hooks integrados | Deuda técnica, seguridad, performance, arquitectura, DORA metrics — antes de que el código llegue a Git |

**Resultado**: Estándares de calidad uniformes, medibles y comparables en toda la organización. Los problemas se detectan en el IDE, no en producción.

---

## 10. Cumplimiento Normativo Manual y Reactivo

### El problema

Las consultoras que trabajan con banca, seguros, sanidad o administración pública deben cumplir con GDPR, AEPD, ISO 27001, EU AI Act y regulaciones sectoriales. El cumplimiento se gestiona de forma manual: hojas Excel, auditorías anuales, documentación estática que se desactualiza el día después de crearla.

### Impacto en la consultora

- Preparar una auditoría ISO 27001 consume 2-4 semanas de trabajo
- Los controles de GDPR se verifican manualmente una vez al año
- No hay visibilidad continua del estado de compliance
- Sanciones GDPR de hasta el 4% de la facturación global

### Cómo lo resuelve pm-workspace

| Solución | Comando / Componente | Detalle |
|----------|----------------------|---------|
| Compliance automático | `/governance-enterprise compliance-check` | Verificación continua de controles GDPR, AEPD, ISO 27001, EU AI Act |
| Compliance calendar | Regla `governance-enterprise.md` | Calendario de obligaciones con frecuencias y responsables |
| AEPD específico | `/aepd-compliance` | Framework de 4 fases para IA agéntica — cumplimiento AEPD nativo |
| Certificación | `/governance-enterprise certify` | Genera paquete de evidencia para auditorías externas |
| Detección sectorial | Regla `regulatory-compliance` | Detecta automáticamente el sector del proyecto y aplica controles específicos |
| PII scanner | Hook `hook-pii-gate.sh` | Bloquea commits con datos personales antes de que lleguen al repositorio |
| Equality Shield | `/bias-check` | Auditoría de sesgos de IA en asignaciones y evaluaciones (6 sesgos, test contrafactual) |

**Resultado**: Compliance continuo, no anual. Evidencia generada automáticamente. Auditorías que se preparan en horas, no en semanas.

---

## Resumen: Matriz de Gaps y Soluciones

| # | Gap | Impacto sin resolver | Solución pm-workspace | Score antes → después |
|---|-----|---------------------|----------------------|----------------------|
| 1 | Silos de conocimiento | 29% del tiempo buscando info | SaviaHub + agent-memory + knowledge-search | 3/10 → 8/10 |
| 2 | Coordinación entre equipos | 8-12 reuniones/sem, bloqueos ocultos | team-orchestrator + Team Topologies | 1/10 → 8/10 |
| 3 | Opacidad financiera | Desvíos detectados al +30% | cost-center + EVM + alertas automáticas | 0/10 → 8/10 |
| 4 | Comunicación con stakeholders | 40% del PM en reportes manuales | Reportes adaptativos + enterprise-dashboard | 3/10 → 8/10 |
| 5 | Falta de gobernanza | Riesgo GDPR, sin audit trail | RBAC + audit trail + compliance checks | 1/10 → 8/10 |
| 6 | Onboarding lento | 2-4 sem/persona, 300 sem/año perdidas | onboard-enterprise + context-interview | 2/10 → 8/10 |
| 7 | Vendor lock-in | 50K-200K€/año, migración imposible | Git-first + open-source + sovereignty-audit | 5/10 → 9/10 |
| 8 | Scope creep | 50% de desvíos | backlog-git + SDD obligatorio + PR Guardian | 4/10 → 8/10 |
| 9 | Calidad inconsistente | 3-5x variación entre equipos | scoring-curves + consensus + 14 hooks | 3/10 → 7/10 |
| 10 | Compliance manual | 2-4 sem por auditoría | governance-enterprise + AEPD + PII gate | 1/10 → 8/10 |

---

**Versión**: 1.0 | **Última actualización**: 2026-03-06 | **Mantainer**: pm-workspace Community
