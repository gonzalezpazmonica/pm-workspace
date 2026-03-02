---
name: obs-connect
description: Conectar Savia a plataformas de observabilidad — Grafana, Datadog, Azure App Insights, OpenTelemetry
developer_type: all
agent: task
context_cost: high
---

# /obs-connect

> 🦉 Conecta tus fuentes de observabilidad. Savia habla con Grafana, Datadog, App Insights, OpenTelemetry y colectores custom.

---

## Plataformas soportadas

- **Grafana**: API REST, dashboards, alertas, Loki (logs), Tempo (traces), Mimir (metrics)
- **Datadog**: API v2, APM traces, logs, infrastructure metrics, LLM Observability
- **Azure Application Insights**: REST API, Application Map, KQL queries, Live Metrics
- **OpenTelemetry Collector**: OTLP endpoint, GenAI Semantic Conventions (v1.37+)
- **Custom**: cualquier endpoint compatible con OpenTelemetry o Prometheus

---

## Sintaxis

```
/obs-connect {plataforma} [--url endpoint] [--api-key clave] [--test] [--lang es|en]
```

### Parámetros

- `{plataforma}`: `grafana`, `datadog`, `appinsights`, `otel`, `custom`
- `--url`: endpoint de la API (ej: `https://grafana.miempresa.com`)
- `--api-key`: API key o token de autenticación
- `--test`: valida la conexión sin guardar
- `--lang`: idioma de output (`es` o `en`)

---

## Flujo

### Paso 1 — Identificar plataforma

1. Validar que `{plataforma}` es soportada
2. Leer configuración existente en `.claude/profiles/integrations/obs-{plataforma}.md`
3. Si existe → preguntar: "¿Actualizar configuración existente?"
4. Si no existe → crear nueva

### Paso 2 — Recopilar credenciales

1. **Grafana**: pedir URL de instancia + API token (o username/password)
2. **Datadog**: pedir API key + application key (region: EU o US)
3. **App Insights**: pedir connection string o app ID + instrumentation key
4. **OpenTelemetry**: pedir OTLP receiver endpoint (gRPC o HTTP)
5. **Custom**: pedir URL base + headers de autenticación

### Paso 3 — Validar conexión (--test)

1. Si `--test`, hacer request de prueba:
   - **Grafana**: GET `/api/health`
   - **Datadog**: GET `/api/v2/validate_api_key`
   - **App Insights**: GET `/api/resourceHealthMetadata`
   - **OpenTelemetry**: POST `/v1/metrics` con 1 métrica de test
   - **Custom**: GET `{url}/health` o `{url}/metrics`
2. Mostrar: `✓ Conexión exitosa en {latencia}ms`
3. Si falla → mostrar error y permitir reintento

### Paso 4 — Almacenar credenciales

1. **Nunca guardar en plaintext**
2. Crear/actualizar: `.claude/profiles/integrations/obs-{plataforma}.md`
3. Guardar referencia encriptada (AES-256-CBC, PBKDF2, 100k iter)
4. Incluir metadatos:
   - Fecha de conexión
   - Último test exitoso
   - Región/datacenter (si aplica)
   - Usuario que conectó
   - Capacidades detectadas (qué tipo de datos está disponible)

### Paso 5 — Resumen

Mostrar:
```
🦉 ¡Listo! Conectado a {plataforma}

URL: {url}
Último test: {timestamp}
Capacidades detectadas:
  - Metrics: ✓
  - Logs: ✓
  - Traces: ✓
  - Alerts: ✓

Próximo paso: /obs-query para consultar datos
```

---

## Opciones avanzadas

### Múltiples instancias de la misma plataforma

```
/obs-connect grafana --url https://prod-grafana.com --label prod
/obs-connect grafana --url https://staging-grafana.com --label staging
```

Savia almacena ambas, permitiendo consultas cruzadas.

### Configuración global vs. por proyecto

- Global: `.claude/profiles/integrations/obs-{plataforma}.md`
- Por proyecto: `.claude/projects/{proyecto}/integrations/obs-{plataforma}.md`

### Sincronización automática de dashboards

```
/obs-connect grafana --auto-sync-dashboards
```

Savia descarga y cachea dashboards para acceso offline.

---

## Casos de uso

**PM/CTO**: Conectar la instancia de producción de Grafana para ver health overall.

**Developer**: Conectar Datadog local + production para comparar comportamiento.

**SRE**: Conectar múltiples regiones (EU, US, APAC) de Datadog en un solo workspace.

**QA**: Conectar Azure App Insights del ambiente de staging para validación pre-release.

---

## Seguridad

- Credenciales nunca en `.git`
- Encriptadas en `.claude/profiles/integrations/`
- Rotación automática recomendada cada 90 días
- Auditoría de accesos en `ai-audit-log`
- Certificados SSL validados (no `--insecure`)

