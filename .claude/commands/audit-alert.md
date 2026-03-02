---
name: audit-alert
description: Alertas automáticas por patrones anómalos — horario inusual, comandos de riesgo, volumen alto, acceso sensible.
developer_type: all
agent: task
context_cost: medium
---

# Audit Alert — Detección de Anomalías

## Propósito

Monitorizar automáticamente el audit trail detectando patrones anómalos: acciones fuera de horario, comandos de riesgo alto sin aprobación, volumen inusual, accesos a datos sensibles, desviaciones de governance.

## Sintaxis

```bash
/audit-alert [--configure] [--show] [--test] [--lang es|en]
```

## Parámetros

| Parámetro | Tipo | Descripción |
|---|---|---|
| `--configure` | flag | Modo configuración interactivo |
| `--show` | flag | Mostrar alertas activas y estadísticas |
| `--test` | flag | Probar con datos históricos |
| `--lang` | string | `es` o `en` |

## Tipos de Anomalía Detectada

### 1. Acciones Fuera de Horario
Comando ejecutado fuera del rango normal del usuario (ej: 02:00 AM).
Umbral: 2+ acciones consecutivas → alerta MEDIUM

### 2. Comandos de Riesgo Alto
Comandos críticos sin aprobación: `/audit-export`, `/project-delete`, `/backup restore`, `/infrastructure-apply`
Severidad: CRITICAL

### 3. Volumen Inusual
>20 comandos en <5 minutos (posible automatización no autorizada).
Severidad: HIGH

### 4. Acceso a Datos Sensibles
Acceso frecuente a proyectos `confidential` o datos de producción sin justificación.
Severidad: MEDIUM

### 5. Violación de Governance
Acciones que violan políticas establecidas (ej: cambios PRO sin PR aprobado).
Severidad: CRITICAL

## Canales de Notificación

### Slack
```
🚨 AUDIT ALERT — High Risk
User: monica | Command: /infrastructure-apply --env PRO
Timestamp: 2026-03-02 15:30 UTC | Severity: ⛔ CRITICAL
```

### Email
Sujeto: `[AUDIT] {Tipo alerta} {severidad}`
Cuerpo: usuario, comando, hora, severidad, link a audit-trail

### Dashboard
Alerta visible en `/health-dashboard` con contador de anomalías activas

## Configuración Interactiva

```
1. Horario normal: [09:00-18:00] Cambiar? (s/n)
2. Días laborales: [Lunes-Viernes] Cambiar? (s/n)
3. Comandos riesgo alto: [actual list] Añadir? (s/n)
4. Canales: Slack ☐ Email ☑ Dashboard ☐
5. Nivel mínimo: [High] Low □ Medium □ High ☑ Critical □
```

Fichero de configuración: `$HOME/.pm-workspace/audit-alerts.yaml`

## Características Principales

- ✅ Evaluación automática **cada hora** del audit trail
- ✅ Whitelist para falsos positivos
- ✅ Todas las alertas registradas en audit trail
- ✅ Histórico en `.pm-workspace/audit-alerts-history.jsonl`
- ✅ Integración con `/health-dashboard`

## Notas

- Alertas sobre auditar NO crean alertas (sin recursión)
- Configuración por usuario, se guarda en perfil
- Severidad CRITICAL bloqueará el comando hasta revisión manual
