---
name: subscriber-lifecycle
description: "Gestión integral del ciclo de vida del suscriptor desde onboarding hasta análisis de churn"
icon: "👥"
category: "Telecomunicaciones"
---

# Ciclo de Vida del Suscriptor

Administra el ciclo de vida completo del suscriptor incluyendo onboarding, cambios de plan, cálculo de riesgo de churn y análisis analíticos. Todos los datos son anonimizados para mantener privacidad.

## Subcomandos

### onboard
Registra un nuevo suscriptor con identificador único (SUB-NNNN).

**Uso:** `subscriber-lifecycle onboard [opciones]`

**Parámetros:**
- `--plan` - Plan de suscripción inicial (requerido)
- `--fecha-activacion` - Fecha de activación (YYYY-MM-DD) (requerido)
- `--canal` - Canal de adquisición: web, tienda, agente, referencia (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
subscriber-lifecycle onboard \
  --plan "Fibra 300Mbps" \
  --fecha-activacion "2026-03-05" \
  --canal "web" \
  --proyecto mi-telco
```

**Resultado:** Crea archivo `projects/{proyecto}/telco/subscribers/SUB-NNNN.yaml` con perfil del suscriptor anonimizado.

### upgrade
Registra una mejora de plan con valor de upsell calculado.

**Uso:** `subscriber-lifecycle upgrade [opciones]`

**Parámetros:**
- `--suscriptor` - Identificador del suscriptor (requerido)
- `--nuevo-plan` - Plan nuevo (requerido)
- `--razon` - Razón de la mejora (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
subscriber-lifecycle upgrade \
  --suscriptor SUB-0001 \
  --nuevo-plan "Fibra 1Gbps" \
  --razon "Solicitud de mayor velocidad" \
  --proyecto mi-telco
```

### downgrade
Registra una reducción de plan con análisis de causas.

**Uso:** `subscriber-lifecycle downgrade [opciones]`

**Parámetros:**
- `--suscriptor` - Identificador del suscriptor (requerido)
- `--nuevo-plan` - Plan reducido (requerido)
- `--razon` - Razón de la reducción (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
subscriber-lifecycle downgrade \
  --suscriptor SUB-0001 \
  --nuevo-plan "Fibra 100Mbps" \
  --razon "Reducción de costos operativos" \
  --proyecto mi-telco
```

### churn-risk
Calcula la probabilidad de churn basada en patrones de uso, quejas y antigüedad.

**Uso:** `subscriber-lifecycle churn-risk [opciones]`

**Parámetros:**
- `--suscriptor` - Identificador del suscriptor (requerido)
- `--proyecto` - Identificador del proyecto (requerido)

**Ejemplo:**
```bash
subscriber-lifecycle churn-risk \
  --suscriptor SUB-0001 \
  --proyecto mi-telco
```

**Resultado:** Genera score de riesgo (0-100%) basado en:
- Patrones de uso (actividad, cambios recientes)
- Historial de quejas (número, severidad)
- Antigüedad en plataforma (meses de suscripción)
- Comparativa con cohorte

### report
Genera análisis de ciclo de vida del suscriptor con métricas agregadas anonimizadas.

**Uso:** `subscriber-lifecycle report [opciones]`

**Parámetros:**
- `--periodo` - Período a analizar: mes, trimestre, año (requerido)
- `--proyecto` - Identificador del proyecto (requerido)
- `--formato` - Formato de salida: tabla, json, yaml (default: tabla)

**Ejemplo:**
```bash
subscriber-lifecycle report \
  --periodo trimestre \
  --proyecto mi-telco \
  --formato tabla
```

**Resultado:** Informe con métricas agregadas anonimizadas:
- ARPU (Average Revenue Per User)
- Churn rate (porcentaje de bajas)
- LTV (Lifetime Value)
- CAC (Customer Acquisition Cost)

## Almacenamiento

Todos los datos se guardan en `projects/{proyecto}/telco/subscribers/` con estructura YAML.

## Privacidad

Ningún dato personal se almacena:
- Solo identificadores anonimizados (SUB-NNNN)
- Métricas agregadas para reportes
- Análisis basado en patrones, no en datos personales
- Cumplimiento total GDPR/LOPD

