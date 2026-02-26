# Regla: Protección de Configuración Confidencial
# ── Secrets, connection strings y datos sensibles NUNCA en el repositorio ────

> REGLA CRÍTICA: Ningún dato sensible debe existir en el repositorio.
> Esta regla aplica a TODOS los proyectos, lenguajes y entornos del workspace.

## Principios Fundamentales

1. **NUNCA connection strings en el repositorio** — ni en código, ni en configuración, ni en comentarios
2. **NUNCA API keys, tokens o passwords en el repositorio** — usar servicios de secrets
3. **NUNCA hardcodear valores sensibles** — siempre variables de entorno o referencias a vault
4. **Los ficheros de configuración en el repo solo contienen estructura** — los valores van aparte
5. **Cada entorno tiene sus propios secrets** — nunca reutilizar entre DEV/PRE/PRO

---

## Clasificación de Datos

### 🔴 CONFIDENCIAL — NUNCA en repositorio
- Connection strings (base de datos, cache, message bus)
- API keys y tokens de acceso
- Passwords y secrets
- Certificados y claves privadas (.pfx, .pem, .key)
- Client secrets (OAuth, Azure AD, etc.)
- Encryption keys
- PAT (Personal Access Tokens)
- Webhook secrets

### 🟡 RESTRINGIDO — En repositorio solo con placeholders
- URLs de servicios internos (usar variables)
- Nombres de recursos cloud (usar convención de naming)
- Configuración de puertos no-estándar
- Feature flags de seguridad

### 🟢 PÚBLICO — Puede ir en repositorio
- Nombres de entornos (DEV, PRE, PRO)
- Configuración de logging (niveles, formatos)
- Timeouts y retry policies
- Configuración de CORS (orígenes públicos)
- Versiones de dependencias

---

## Estrategias de Protección por Plataforma

### Azure — Key Vault + App Configuration

```json
// appsettings.json — EN REPO (solo referencias)
{
  "ConnectionStrings": {
    "DefaultConnection": "PLACEHOLDER_USE_KEYVAULT"
  },
  "KeyVault": {
    "VaultUri": "https://kv-{proyecto}-{env}.vault.azure.net/"
  }
}
```

```csharp
// Program.cs — referencia a Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri(builder.Configuration["KeyVault:VaultUri"]),
    new DefaultAzureCredential());
```

```bash
# Almacenar secret en Key Vault
az keyvault secret set \
  --vault-name "kv-miapp-dev" \
  --name "ConnectionStrings--DefaultConnection" \
  --value "Server=tcp:sql-miapp-dev.database.windows.net..."
```

### AWS — Secrets Manager + Parameter Store

```json
// config.json — EN REPO (solo referencias)
{
  "database": {
    "connectionString": "aws-ssm:///miapp/dev/db-connection"
  }
}
```

```bash
# Almacenar en SSM Parameter Store
aws ssm put-parameter \
  --name "/miapp/dev/db-connection" \
  --value "postgresql://..." \
  --type SecureString \
  --key-id "alias/miapp-key"

# Almacenar en Secrets Manager
aws secretsmanager create-secret \
  --name "miapp/dev/db-password" \
  --secret-string "..."
```

### GCP — Secret Manager

```bash
# Almacenar secret
echo -n "postgresql://..." | gcloud secrets create miapp-dev-db-connection \
  --replication-policy="automatic" \
  --data-file=-

# Acceder en aplicación
gcloud secrets versions access latest --secret="miapp-dev-db-connection"
```

### Local / Docker — dotenv (git-ignorado)

```bash
# config.local/.env.DEV — NUNCA en repositorio
DATABASE_CONNECTION_STRING=Server=localhost;Database=miapp;User=sa;Password=...
REDIS_CONNECTION_STRING=localhost:6379
API_KEY_EXTERNAL_SERVICE=sk-...
```

---

## .gitignore Obligatorio

Todo proyecto DEBE incluir estas exclusiones:

```gitignore
# ── Secrets y configuración sensible ──────────────────────────────
config.local/
*.env
.env.*
!.env.example
*.secret
*.secrets
*.pfx
*.pem
*.key
*.p12

# ── Terraform ─────────────────────────────────────────────────────
*.tfvars.secret
*.tfstate
*.tfstate.*
.terraform/
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# ── Azure / Cloud credentials ─────────────────────────────────────
azure.json
credentials.json
service-account-key.json
*.azure-credentials

# ── IDE y local ───────────────────────────────────────────────────
.vs/
.idea/
*.user
*.suo
launchSettings.json         # Puede contener variables de entorno locales
```

---

## Fichero de Ejemplo (.env.example)

Todo proyecto DEBE tener un `.env.example` en el repositorio que documente las variables necesarias SIN valores reales:

```bash
# .env.example — Copiar a config.local/.env.{ENTORNO} y rellenar valores
# NUNCA rellenar este fichero con datos reales

# ── Base de datos ──────────────────────────────────────────────
DATABASE_CONNECTION_STRING=Server=HOSTNAME;Database=DBNAME;User=USERNAME;Password=PASSWORD
DATABASE_MAX_POOL_SIZE=20

# ── Cache ──────────────────────────────────────────────────────
REDIS_CONNECTION_STRING=HOSTNAME:PORT,password=PASSWORD,ssl=True

# ── Autenticación ─────────────────────────────────────────────
AUTH_AUTHORITY=https://login.microsoftonline.com/TENANT_ID
AUTH_CLIENT_ID=CLIENT_ID_HERE
AUTH_CLIENT_SECRET=CLIENT_SECRET_HERE

# ── Servicios externos ────────────────────────────────────────
API_KEY_MAPS=YOUR_API_KEY
API_KEY_NOTIFICATIONS=YOUR_API_KEY

# ── Observabilidad ────────────────────────────────────────────
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=YOUR_KEY
LOG_LEVEL=Information
```

---

## Validación Pre-Commit (Security Guardian)

El agente `security-guardian` y `commit-guardian` DEBEN verificar antes de cada commit:

### Patrones prohibidos en código

```regex
# Connection strings
(Server|Data Source|Host)=.*Password=
(mongodb|postgresql|mysql|sqlserver):\/\/.*:.*@
redis:\/\/.*:.*@

# API Keys y Tokens
(sk-|pk-|ak-|rk-)[a-zA-Z0-9]{20,}
(ghp_|gho_|ghu_|ghs_|ghr_)[a-zA-Z0-9]{36,}
AKIA[0-9A-Z]{16}
AIza[0-9A-Za-z\-_]{35}

# Azure
DefaultEndpointsProtocol=https;AccountName=.*AccountKey=
(sv=\d{4}-\d{2}-\d{2}&s[a-z]=)

# Certificados
-----BEGIN (RSA |EC )?PRIVATE KEY-----
-----BEGIN CERTIFICATE-----

# Passwords en configuración
[Pp]assword\s*[:=]\s*["'][^"']+["']
[Ss]ecret\s*[:=]\s*["'][^"']+["']
```

### Verificación automatizada

```bash
# Buscar secrets en staged files antes de commit
git diff --cached --diff-filter=ACM | grep -iE \
  '(password|secret|token|apikey|api_key|connection.?string)' \
  --include='*.cs' --include='*.json' --include='*.yaml' --include='*.yml' \
  --include='*.tf' --include='*.py' --include='*.js' --include='*.ts' \
  --include='*.java' --include='*.go' --include='*.rs' --include='*.php'
```

---

## Rotación de Secrets

### Política recomendada

| Tipo de secret | Frecuencia de rotación | Automatizable |
|---|---|---|
| Passwords de BD | Cada 90 días | Sí (Key Vault) |
| API keys propias | Cada 180 días | Sí |
| API keys terceros | Según proveedor | Manual |
| Tokens de servicio | Cada 30 días | Sí |
| Certificados TLS | Antes de expiración | Sí (Let's Encrypt) |
| PAT Azure DevOps | Cada 90 días | Manual |

### Proceso de rotación

1. Generar nuevo secret en el servicio de vault
2. Actualizar la aplicación para usar el nuevo secret
3. Verificar que funciona correctamente
4. Revocar el secret anterior (con período de gracia de 24h)
5. Documentar la rotación en el log de operaciones

---

## Checklist de Confidencialidad por Proyecto

- [ ] `.gitignore` incluye todas las exclusiones obligatorias
- [ ] `.env.example` creado con todas las variables documentadas (sin valores reales)
- [ ] `config.local/` creado y git-ignorado
- [ ] Ficheros `.env.{ENTORNO}` creados en `config.local/` para cada entorno
- [ ] Connection strings almacenados en vault del cloud provider (Key Vault / SSM / Secret Manager)
- [ ] Código usa referencias a vault, NO valores directos
- [ ] `security-guardian` configurado para verificar patrones prohibidos
- [ ] Política de rotación definida y documentada
- [ ] Todo el equipo conoce la política de secrets (incluido en onboarding)
