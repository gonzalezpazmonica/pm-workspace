---
name: volunteer-manage
description: >
  Administra voluntarios para organizaciones sin fines de lucro. Registra
  voluntarios, gestiona disponibilidad, registra horas de servicio y genera
  reportes de retención y impacto.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# volunteer-manage

Comando para administrar voluntarios en proyectos sin fines de lucro.

## Subcomandos

### register
Registra un nuevo voluntario con información de perfil y disponibilidad.

```
volunteer-manage register <proyecto>
  --name "Nombre completo"
  --email "correo@example.com"
  --phone "número"
  --skills "skill1,skill2,skill3"
  --availability "monday-wednesday, 18:00-20:00"
  --onboarding-date "YYYY-MM-DD"
  [--notes "información adicional"]
```

Genera ID secuencial VOL-NNN. Requiere consentimiento de protección de datos.

### availability
Gestiona la ventana de disponibilidad de un voluntario.

```
volunteer-manage availability <proyecto> <vol-id>
  [--add "tuesday, 10:00-12:00"]
  [--remove "wednesday"]
  [--status "active|inactive|leave"]
  [--until "YYYY-MM-DD"]
```

Soporta licencias temporales y cambios estacionales.

### hours
Registra horas de servicio voluntario con descripción de actividad.

```
volunteer-manage hours <proyecto> <vol-id>
  --date "YYYY-MM-DD"
  --hours "número decimal"
  --activity "descripción de actividad"
  [--verified-by "supervisor"]
```

Valida que voluntario estuviera disponible en esa fecha.

### list
Muestra voluntarios con filtros opcionales.

```
volunteer-manage list <proyecto>
  [--skill "filtro de skill"]
  [--status "active|inactive|all"]
  [--sort "hours|name|active-date"]
  [--detail]
```

Oculta datos sensibles en lista básica.

### report
Genera reporte de voluntariado con métricas de retención e impacto.

```
volunteer-manage report <proyecto>
  [--period "quarter|annual"]
  [--format "html|pdf|markdown"]
  [--metrics "hours,retention,skills"]
```

Métricas calculadas:
- Total de horas por voluntario y agregado
- Tasa de retención (renovación)
- Distribución por actividad
- Tendencias de participación

## Taxonomía de Habilidades

Sistema de clasificación por áreas:
- `teaching`: docencia, tutorías
- `mentoring`: mentoría, coaching
- `admin`: gestión administrativa
- `technical`: desarrollo, IT
- `healthcare`: salud, bienestar
- `fundraising`: captación de fondos
- `outreach`: comunicación, alcance
- `specialized`: otros especialidades

## Privacidad de Datos

Los voluntarios retienen control sobre sus datos:

- Números de teléfono solo para coordinadores
- Reportes públicos sin información identificable
- Consentimiento explícito para cada uso de datos
- Derecho al olvido después de 2 años de inactividad
- No compartir datos con terceros sin aprobación

## Estructura de Datos

```yaml
# projects/{proyecto}/volunteers/VOL-042.yml
id: VOL-042
name: "María García"
email: "maria.g@example.com"
phone: "private"  # No almacenar
skills:
  - teaching
  - mentoring
status: active
availability:
  - day: monday
    start: "14:00"
    end: "17:00"
  - day: saturday
    start: "10:00"
    end: "13:00"
onboarding_date: 2025-09-15
total_hours: 128
active_since: 2025-09-15
last_activity: 2026-03-02
```

## Retención y Reconocimiento

- Hito: 50 horas → Certificado de Reconocimiento
- Hito: 100 horas → Mención en reportes públicos
- Seguimiento trimestral de actividad
- Espacios de desarrollo y crecimiento
