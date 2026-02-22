# Reglas de Negocio — Empresa

> Reglas transversales que aplican a todos los proyectos. Cada proyecto puede sobrescribir o ampliar estas reglas en su propio `reglas-negocio.md`.

## Constantes de Negocio

```
EMPRESA_NOMBRE          = "MI EMPRESA S.L."          # ← actualizar
EMPRESA_CIF             = "B-XXXXXXXX"               # ← actualizar
JORNADA_LABORAL_HORAS   = 8                           # horas por día
JORNADA_LABORAL_DIAS    = 5                           # días por semana (L-V)
FESTIVOS_REGION         = "Madrid"                    # comunidad para festivos oficiales
MONEDA                  = "EUR"
IVA_VIGENTE             = 0.21
COSTE_HORA_DESARROLLO   = 65.0                        # EUR/h (ajustar por perfil/cliente)
COSTE_HORA_QA           = 50.0
COSTE_HORA_PM           = 55.0
```

---

## 1. Gestión de Proyectos

### 1.1 Inicio de Proyecto
- Todo proyecto debe tener un **Project Charter** aprobado antes de comenzar el sprint 1
- Designar siempre: Project Manager, Product Owner y Scrum Master (pueden coincidir roles)
- Crear el proyecto en Azure DevOps con la estructura de iteraciones completa antes del kick-off
- El repositorio git del código fuente se crea bajo la organización Azure DevOps y se enlaza al proyecto

### 1.2 Gestión de Cambios
- Cualquier cambio en el alcance firmado requiere **Change Request** formal aprobado por el cliente
- Los Change Requests se gestionan como Epics/Features separados en Azure DevOps con tag `change-request`
- Impacto estimado en tiempo y coste debe documentarse antes de la aprobación

### 1.3 Cierre de Proyecto
- Entregable final: informe de cierre con métricas de proyecto, lecciones aprendidas y acta de aceptación
- Archivar todos los artefactos Scrum en la carpeta `projects/<proyecto>/sprints/`
- Retención de documentación: mínimo 5 años

---

## 2. Imputación de Horas

### 2.1 Registro Diario (obligatorio)
- Todos los miembros del equipo deben actualizar `CompletedWork` y `RemainingWork` en Azure DevOps **cada día antes de las 18:00**
- Si un día no se trabaja en ningún task de Azure DevOps, registrar el tiempo en la task especial `[Proyecto] - Gestión y reuniones`
- No se aceptan imputaciones retroactivas de más de 3 días hábiles

### 2.2 Actividades Imputables
| Código | Actividad | Descripción |
|--------|-----------|-------------|
| `DEV` | Development | Desarrollo de código, arquitectura, diseño técnico |
| `QA` | Testing | Testing manual, automatización de tests, QA |
| `DOC` | Documentation | Documentación técnica, user guides, wikis |
| `MTG` | Meeting | Reuniones (internas y con cliente) |
| `DES` | Design | Diseño UX/UI, wireframes, prototipos |
| `OPS` | DevOps | CI/CD, infraestructura, deployments, monitoring |
| `MGT` | Management | Gestión de proyecto, coordinación, reporting |

### 2.3 Imputación a Cliente
- Las horas imputables al cliente son aquellas con actividades: DEV, QA, DOC, DES, OPS
- Las horas de gestión (MGT, MTG internas) se imputan según el contrato del proyecto
- Redondear siempre al cuarto de hora más cercano (0.25h mínimo por actividad)

---

## 3. Calidad y Estándares Técnicos

### 3.1 Estándares de Código (.NET)
- Cobertura mínima de tests unitarios: **80%** (obligatorio para pasar PR)
- Análisis estático de código: SonarQube sin bloqueantes (Blocker/Critical = 0)
- Nombramiento: PascalCase para clases y métodos, camelCase para variables
- Documentación XML en todas las APIs públicas

### 3.2 Gestión de Ramas (Git)
- Rama principal: `main` — protegida, solo merge via PR aprobado
- Rama de desarrollo: `develop` — integración continua
- Ramas de feature: `feature/AB#XXXX-descripcion`
- Ramas de bugfix: `bugfix/AB#XXXX-descripcion`
- Ramas de release: `release/vX.Y.Z`
- **Prohibido** commitear directamente a `main` o `develop`

### 3.3 Commit Messages
- Formato obligatorio: `[AB#XXXX] Verbo en imperativo + descripción corta`
- Ejemplos: `[AB#1234] Add user authentication endpoint`, `[AB#1235] Fix null reference in OrderService`
- Sin abbreviaciones en los mensajes; máximo 72 caracteres en la primera línea

### 3.4 Pull Requests
- Al menos 1 aprobación requerida (2 si el cambio afecta arquitectura o datos)
- El autor NO puede aprobarse su propio PR
- PR description debe referenciar el work item: `Closes AB#XXXX`
- Los PRs no pueden estar abiertos más de 3 días hábiles sin actividad

---

## 4. Comunicación con el Cliente

### 4.1 Cadencia de Informes
- **Informe semanal:** Viernes antes de las 18:00 — resumen de estado del sprint
- **Informe de sprint:** Al finalizar cada sprint — results + métricas + próximo sprint
- **Informe ejecutivo mensual:** Último viernes de cada mes — dashboard completo
- **Alertas inmediatas:** Cualquier riesgo P1 o bloqueo de sprint goal se comunica en < 4h

### 4.2 Canal de Comunicación
- Comunicación formal: email con confirmación de lectura
- Comunicación ágil: Microsoft Teams (canal del proyecto)
- Reuniones: siempre con agenda previa y acta posterior en < 24h

### 4.3 Gestión de Expectativas
- No prometer fechas sin haber consultado la capacity del equipo
- Escalar a dirección cualquier cambio de alcance que afecte a plazos comprometidos
- Documentar SIEMPRE los acuerdos verbales por escrito (email o Teams)

---

## 5. Seguridad y Compliance

### 5.1 Datos
- Ningún dato de producción se usa en entornos de desarrollo/test sin anonimizar
- Las credenciales y secretos nunca van en el código fuente (usar Key Vault o variables de entorno)
- Cumplimiento GDPR: documentar qué datos personales maneja cada proyecto

### 5.2 Accesos
- Accesos a Azure DevOps siguiendo principio de mínimo privilegio
- Revisar y revocar accesos al término de cada proyecto
- Los PATs tienen caducidad máxima de 90 días y se rotan en cada renovación

---

## 6. Escalado de Decisiones

| Decisión | Autorización requerida |
|----------|----------------------|
| Cambio en el alcance del proyecto | PM + PO + Cliente |
| Ampliación de presupuesto | PM + Dirección + Cliente |
| Cambio tecnológico relevante | Tech Lead + PM + Dirección |
| Contratación/baja de recurso | PM + Dirección RRHH |
| Incidente de seguridad | Inmediato a Dirección + DPO |
