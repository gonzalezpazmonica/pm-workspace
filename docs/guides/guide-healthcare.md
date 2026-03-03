# Guía: Organización Sanitaria

> Escenario: hospital, clínica o centro de salud que gestiona proyectos de mejora, protocolos clínicos, cumplimiento regulatorio y coordinación de equipos multidisciplinares.

**Nota**: Savia NO es un sistema de gestión de pacientes (HIS/HCE). Es una herramienta de gestión de proyectos que ayuda a equipos sanitarios a coordinar iniciativas de mejora, implementar protocolos y cumplir normativas.

---

## Tu organización

| Rol | Qué gestiona con Savia | Comandos principales |
|---|---|---|
| **Director/a de calidad** | Proyectos de mejora, auditorías, indicadores | `/ceo-report`, `/compliance-scan`, `/portfolio-overview` |
| **Jefe/a de servicio** | Coordinación del servicio, protocolos | `/savia-sprint`, `/savia-board`, `/savia-pbi` |
| **Responsable de IT** | Sistemas, integraciones, ciberseguridad | `/security-audit`, `/arch-health`, `/spec-implement` |
| **Coordinador/a de enfermería** | Turnos, formación, procedimientos | `/flow-task-*`, `/savia-send`, `/school-*` |
| **Técnico/a de calidad** | Indicadores, no conformidades, acciones correctivas | `/flow-task-*`, `/flow-timesheet`, `/qa-dashboard` |

---

## ¿Por qué Savia en sanidad?

- **Cumplimiento regulatorio**: tracking de HIPAA, RGPD sanitario, acreditaciones JCI/EFQM.
- **Gestión de proyectos de mejora**: ciclos PDCA como sprints.
- **Formación del personal**: Savia School para cursos obligatorios y reciclaje.
- **Confidencialidad extrema**: cifrado E2E para comunicaciones sobre incidentes.
- **Trazabilidad**: cada decisión y acción queda versionada — esencial para auditorías.
- **Sin datos de pacientes**: Savia gestiona PROYECTOS, no historias clínicas.

---

## Casos de uso

### 1. Proyecto de mejora continua (PDCA)

Cada ciclo PDCA es un sprint:

```
/savia-sprint start --project mejora-urgencias --goal "Reducir tiempo de triaje un 15%"
```

**Plan:**
```
/flow-task-create plan "Mapear flujo actual de triaje"
/flow-task-create plan "Identificar cuellos de botella"
/flow-task-create plan "Diseñar nuevo protocolo"
```

**Do:**
```
/flow-task-create do "Piloto del nuevo protocolo (1 semana)"
/flow-task-create do "Formación al equipo de triaje"
```

**Check:**
```
/flow-task-create check "Medir tiempos con nuevo protocolo"
/flow-task-create check "Encuesta de satisfacción al personal"
```

**Act:**
```
/flow-task-create act "Ajustar protocolo según resultados"
/flow-task-create act "Documentar y estandarizar"
```

### 2. Implementación de un nuevo sistema IT

> "Savia, vamos a implementar un nuevo sistema de citas online"

```
/savia-pbi create "Selección de proveedor de citas online" --project sistema-citas
/savia-pbi create "Integración con HIS existente" --project sistema-citas
/savia-pbi create "Formación a personal de admisión" --project sistema-citas
/savia-pbi create "Pruebas de aceptación de usuario" --project sistema-citas
/savia-pbi create "Go-live + soporte post-implantación" --project sistema-citas
```

Para la parte técnica, SDD funciona normalmente:

```
/spec-generate {task-id}             → Spec de la integración
/spec-implement {spec}               → Implementación
/security-review {spec}              → Revisión OWASP (crítico en sanidad)
```

### 3. Cumplimiento regulatorio

```
/compliance-scan                     → Escaneo de cumplimiento
```

Savia detecta requisitos de sector sanitario: protección de datos de salud, control de accesos, cifrado en tránsito y reposo, logs de auditoría.

**Tracking de acciones correctivas:**

```
/flow-task-create compliance "NC-001: Actualizar política de contraseñas"
/flow-task-create compliance "NC-002: Cifrar backups del servidor de pruebas"
/flow-task-create compliance "NC-003: Revisar permisos de acceso al HIS"
```

### 4. Formación obligatoria (Savia School)

Para cursos de formación continuada:

```
/school-setup "Hospital Ejemplo" "Formacion-RCP-2026"
/school-enroll sanitario01
/school-enroll sanitario02
```

```
/school-project sanitario01 "simulacion-rcp"
/school-evaluate sanitario01 "simulacion-rcp"
```

Las evaluaciones se cifran. Los registros de formación se exportan para la acreditación del centro.

---

## Día a día del director de calidad

### Mañana

> "Savia, ¿cómo van los proyectos de mejora?"

```
/portfolio-overview                  → Vista de todos los proyectos
/ceo-alerts                          → Alertas que requieren decisión
```

### Preparar comité de calidad

```
/ceo-report --format md              → Informe para el comité
/savia-board mejora-urgencias        → Board del proyecto principal
```

### Auditoría

```
/compliance-scan                     → Estado de cumplimiento
```

---

## Comunicación confidencial

### Sobre un incidente de seguridad del paciente

```
/savia-send @jefe-servicio "Incidente ISPA-2026-015: notificación al comité de seguridad. Reunión urgente mañana 08:00."
```

Cifrado E2E. Ningún dato de paciente en el mensaje — solo referencia al código de incidente.

### Coordinación de guardias

```
/savia-announce "Cambio de guardia del 15-Mar: Dr. A cubre a Dr. B (turno noche)"
```

---

## Privacidad — Regla de oro

**NUNCA datos de pacientes en Savia.** Ni nombres, ni historiales, ni códigos de paciente.

Savia gestiona:
- Proyectos de mejora (procesos, no pacientes)
- Protocolos y procedimientos
- Formación del personal
- Cumplimiento regulatorio
- Coordinación de equipos

Los sistemas de gestión de pacientes (HIS, HCE) son herramientas separadas.

---

## Gaps detectados y propuestas

| Gap | Descripción | Propuesta |
|---|---|---|
| **PDCA native** | No hay ciclo PDCA como entidad nativa | `/pdca-cycle {plan\|do\|check\|act}` con métricas |
| **Incident tracking** | Los incidentes de seguridad del paciente tienen flujos propios | `/incident-register {classify\|investigate\|action}` |
| **Accreditation tracking** | Seguimiento de estándares JCI/EFQM/ISO 9001 | `/accreditation-track {standard\|evidence\|gap}` |
| **Training compliance** | Control de formación obligatoria cumplida/pendiente por profesional | `/training-compliance {status\|expired\|plan}` |
| **Indicator dashboard** | KPIs sanitarios (tiempos de espera, tasa de infección, readmisiones) | `/health-kpi {define\|measure\|trend}` |

---

## Tips

- Los proyectos de mejora funcionan muy bien como sprints — el ciclo PDCA mapea naturalmente
- Nunca, bajo ningún concepto, introduzcas datos de pacientes en Savia
- El cifrado E2E es especialmente relevante para comunicaciones sobre incidentes
- `/compliance-scan` detecta requisitos de sector sanitario automáticamente
- Savia School es ideal para formación continuada obligatoria
- Los informes de horas (`/flow-timesheet-report`) justifican dedicación a proyectos de mejora
- Para centros con múltiples servicios, cada servicio puede ser un "equipo" en Company Savia
