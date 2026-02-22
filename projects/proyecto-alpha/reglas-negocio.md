# Reglas de Negocio — Proyecto Alpha

> Reglas específicas de Proyecto Alpha que complementan o sobrescriben las reglas globales de `docs/reglas-negocio.md`.

## Constantes Específicas del Proyecto

```
DOMINIO_NEGOCIO         = "[Sector/dominio del cliente — actualizar]"
TIPO_CONTRATO           = "Time & Material"         # T&M / Precio fijo / Mixto
PRESUPUESTO_TOTAL_H     = 2000                       # horas totales contratadas
HORAS_PM_INCLUIDAS_PCT  = 0.10                       # 10% del total son horas PM
REVISION_PRESUPUESTO_H  = 200                        # alerta cuando quedan X horas

# Especificidades del cliente
IDIOMA_INFORMES         = "Español"
FORMATO_INFORMES_PREF   = "Word"                     # preferencia del cliente
DIA_ENTREGA_INFORME     = "Viernes"
HORA_ENTREGA_INFORME    = "17:00"
SLA_RESPUESTA_CLIENTE_H = 24                         # horas máximo para responder al cliente
```

---

## 1. Reglas del Dominio de Negocio

> Documentar aquí las reglas de negocio específicas del sistema que se está desarrollando.
> Esta sección es crítica — Claude Code las usa al revisar criterios de aceptación y PRs.

### 1.1 [Módulo de Autenticación]
- Los usuarios deben autenticarse vía Azure Active Directory (SSO corporativo)
- La sesión expira tras 8 horas de inactividad
- El acceso de un usuario revocado en Azure AD debe bloquearse en < 5 minutos
- Todos los intentos de login (exitosos y fallidos) deben registrarse en el audit log

### 1.2 [Módulo de [Nombre]]
> Añadir módulos según el proyecto avance.

### 1.3 Datos Maestros
- [Entidad A]: [reglas sobre esta entidad]
- [Entidad B]: [reglas sobre esta entidad]

---

## 2. Reglas de Calidad Específicas

### 2.1 Umbrales de Rendimiento (SLAs técnicos)
```
RESPONSE_TIME_P95    = 500ms         # API endpoints bajo carga normal
RESPONSE_TIME_P99    = 2000ms        # máximo aceptable
AVAILABILITY_SLA     = 99.5%         # disponibilidad mensual
ERROR_RATE_MAX       = 0.1%          # tasa máxima de errores 5xx
CONCURRENT_USERS     = 100           # usuarios concurrentes soportados
```

### 2.2 Estándares específicos del proyecto
- Todas las APIs deben estar documentadas con Swagger/OpenAPI antes del deploy a staging
- Los datos sensibles del cliente deben estar encriptados en reposo (AES-256)
- Los logs no deben contener datos personales (GDPR)
- Backup diario de la base de datos (retención 30 días)

---

## 3. Reglas de Imputación Específicas

### 3.1 Actividades facturables en este proyecto
| Actividad | ¿Facturable? | Código de proyecto |
|-----------|-------------|-------------------|
| Development | ✅ Sí | ALPHA-DEV |
| Testing | ✅ Sí | ALPHA-QA |
| Documentation | ✅ Sí | ALPHA-DOC |
| Design | ✅ Sí | ALPHA-DES |
| DevOps / CI-CD | ✅ Sí | ALPHA-OPS |
| Reuniones con cliente | ✅ Sí | ALPHA-MTG |
| Reuniones internas | ⚠️ Según contrato | ALPHA-MGT |
| Formación | ❌ No | — |

### 3.2 Límites de horas por módulo (si aplica)
```
Módulo Autenticación:   estimado 400h   / consumido Xh (actualizar)
Módulo Dashboard:       estimado 300h   / consumido Xh
Módulo Reporting:       estimado 200h   / consumido Xh
PM / Gestión:           estimado 200h   / consumido Xh
QA / Testing global:    estimado 150h   / consumido Xh
Contingencia:           estimado 150h   / no usar salvo aprobación
```

---

## 4. Reglas de Comunicación con el Cliente

### 4.1 Personas de contacto en el cliente
| Persona | Rol | Canal preferido | Disponibilidad |
|---------|-----|----------------|----------------|
| [Nombre PO] | Product Owner | Email + Teams | L-V 9:00-18:00 |
| [Nombre técnico] | Referente técnico | Teams | L-V 9:00-17:00 |
| [Nombre dirección] | Dirección | Email | Previa cita |

### 4.2 Escalado en el cliente
- Para cambios de alcance: contactar siempre con [Nombre PO] + [Nombre dirección]
- Para bugs en producción: llamar a [teléfono de guardia — añadir]
- Para decisiones técnicas: con [Nombre técnico] + confirmación por email

### 4.3 Hitos de entrega comprometidos
| Hito | Fecha | Descripción | Estado |
|------|-------|-------------|--------|
| MVP v1.0 | 2026-03-31 | Módulo de autenticación completo | 🟡 En progreso |
| v1.1 | 2026-04-30 | Dashboard de usuario + reporting básico | ⏳ Pendiente |
| v1.2 | 2026-05-31 | Módulo de [completar] | ⏳ Pendiente |
| Cierre | 2026-06-30 | Entrega final + formación usuarios | ⏳ Pendiente |

---

## 5. Decisiones Técnicas Tomadas

> Registrar aquí las decisiones de arquitectura para que el agente no las recuestione.

| Decisión | Alternativas consideradas | Motivo | Fecha | Responsable |
|----------|--------------------------|--------|-------|-------------|
| EF Core como ORM | Dapper, ADO.NET | Productividad + equipo lo conoce | 2026-01-10 | Juan García |
| Angular 17 para frontend | React, Blazor | Stack cliente + compatibilidad | 2026-01-10 | Juan García |
| Azure App Service | Docker/AKS | Simplicidad, presupuesto | 2026-01-12 | Juan + PM |
| SQL Server | PostgreSQL | Sistema existente del cliente | 2026-01-05 | Cliente |

---

## 6. Riesgos Activos

| # | Riesgo | Impacto | Probabilidad | Mitigación | Propietario |
|---|--------|---------|-------------|------------|-------------|
| R1 | Retraso en aprobación de diseños por PO | Alto | Media | Sesiones de review semanales | PM |
| R2 | Integración SSO más compleja de lo estimado | Alto | Baja | Spike técnico en Sprint 2026-04 | Tech Lead |
| R3 | Cambio de alcance en módulo de reporting | Medio | Alta | Gestionar Change Request | PM |

---

## 7. Glosario del Proyecto

> Términos específicos del dominio que Claude Code debe conocer para interpretar correctamente los work items.

| Término | Definición |
|---------|------------|
| [Término A] | [Definición del término en el contexto del proyecto] |
| [Término B] | [Definición] |
| SSO | Single Sign-On — autenticación única corporativa vía Azure AD |
| PBI | Product Backlog Item — item genérico del backlog Scrum |
