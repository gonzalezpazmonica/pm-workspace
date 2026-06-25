---
context_tier: L3
spec: SE-007
status: IMPLEMENTED
token_budget: 1000
---

# Enterprise Onboarding Protocol — Onboarding a escala con SSO/SAML

> Ref: `docs/propuestas/savia-enterprise/SPEC-SE-007-enterprise-onboarding.md`

## Objetivo

Incorporar organizaciones de 50-500 personas en menos de una semana mediante:
- Onboarding batch desde CSV
- Adaptadores SSO/SAML agnósticos (Okta, Entra ID, Keycloak, Google, Auth0)
- Dashboard de adopción local (sin telemetría externa)

## Onboarding batch

### Formato CSV requerido

```csv
user_slug,display_name,role,tenant,email
jsmith,John Smith,developer,squad-alpha,jsmith@company.com
mgarcia,María García,pm,squad-beta,mgarcia@company.com
```

### Ejecución

```bash
# Previsualización (sin efectos)
bash scripts/enterprise/onboarding-batch.sh --csv equipo.csv --dry-run

# Onboarding real
bash scripts/enterprise/onboarding-batch.sh --csv equipo.csv
```

### Output JSON

```json
{
  "total": 20,
  "created": 18,
  "skipped": 2,
  "dry_run": false,
  "profiles_dir": ".claude/profiles/users",
  "errors": []
}
```

### Perfil creado por usuario

```
.claude/profiles/users/{slug}/
├── identity.md      ← name, role, tenant, email, onboarded_at
└── preferences.md   ← defaults: formality, alert_style, language
```

## Adaptadores SSO/SAML

### Proveedores soportados

| IdP | Protocolo | Prioridad |
|-----|-----------|-----------|
| Keycloak | SAML 2.0, OIDC | Sovereign (recomendado) |
| Microsoft Entra ID | SAML 2.0, OIDC | Corporativo España |
| Okta | SAML 2.0, OIDC | Internacional |
| Google Workspace | OIDC | SMB |
| Auth0 | OIDC | Startups |
### Configuración

Crear `.claude/enterprise/sso.yaml` (gitignored):

```yaml
provider: okta          # o azure-ad, keycloak, google-workspace, auth0
provider_url: https://company.okta.com/app/metadata.xml
acs_url: https://savia.company.com/auth/saml/callback
cert_path: /etc/savia/saml-cert.pem
```

O vía variables de entorno:
```bash
export SSO_PROVIDER_URL="https://company.okta.com/app/metadata.xml"
export SSO_ACS_URL="https://savia.company.com/auth/saml/callback"
export SSO_CERT_PATH="/etc/savia/saml-cert.pem"
```

### Verificación

```bash
bash scripts/enterprise/sso-adapter-check.sh --provider okta
```

Output en entorno configurado:
```json
{
  "provider": "okta",
  "reachable": true,
  "cert_valid": true,
  "acs_configured": true
}
```

Output en entorno sin SSO (single-tenant local):
```json
{
  "sso_not_configured": true,
  "provider": "okta",
  "message": "SSO no configurado en este entorno..."
}
```

### Principios de seguridad

- Savia es **solo lectura** con el IdP: nunca escribe, nunca provisionea.
- Solo extrae: `email`, `groups`, `roles`.
- Tokens validados pero no almacenados.
- Cert validation via openssl antes de cualquier integración.

## Dashboard de adopción

Métricas disponibles (todas locales, sin telemetría externa):
- `% personas con perfil activo` por equipo
- `comandos más usados` por rol
- `tiempo ahorrado estimado` vs baseline
- `competencias detectadas/cubiertas`
- `incidentes de compliance` por equipo

```bash
# Generar reporte de adopción
bash scripts/enterprise/metrics-emitter.sh --format prom --dry-run
```

## Buddy IA

Cada perfil creado puede activar un buddy IA asignado (agent `onboarding-dev`):
```bash
# Lanzar buddy para usuario
/onboarding-dev --user jsmith --role developer
```

El buddy:
- Genera documentación de onboarding adaptada al rol
- Acompaña las primeras 2 semanas
- Detecta bloqueos y los escala al mentor humano

## Límites y SLAs

| Operación | Límite | SLA |
|-----------|--------|-----|
| Onboarding batch | 500 usuarios/ejecución | < 10 min para 50 usuarios |
| SSO check | 1 provider | < 30s |
| Dashboard | Sin límite | Local, instantáneo |
## Dependencias

- SE-001: layer contract
- SE-002: multi-tenant isolation (perfiles por tenant)
- SE-009: observability (métricas de adopción)