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

Implementación detallada de protección de secrets para cada proveedor cloud:
**→ `confidentiality-strategies.md`**

Patrones incluidos:
- **Azure**: Key Vault + App Configuration
- **AWS**: Secrets Manager + Parameter Store
- **GCP**: Secret Manager
- **Local**: dotenv con git-ignore
- **Validación pre-commit**: patrones prohibidos
- **Rotación**: políticas por tipo de secret

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

Todo proyecto DEBE tener un `.env.example` documentando variables SIN valores:

```bash
# config.local/.env.{ENTORNO} — Copiar y rellenar con datos reales
DATABASE_CONNECTION_STRING=Server=HOSTNAME;Database=DBNAME;User=USERNAME;Password=PASSWORD
REDIS_CONNECTION_STRING=HOSTNAME:PORT,password=PASSWORD,ssl=True
AUTH_AUTHORITY=https://login.microsoftonline.com/TENANT_ID
AUTH_CLIENT_ID=CLIENT_ID_HERE
AUTH_CLIENT_SECRET=CLIENT_SECRET_HERE
API_KEY_MAPS=YOUR_API_KEY
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=YOUR_KEY
LOG_LEVEL=Information
```

---

## Validación Pre-Commit

El agente `security-guardian` y `commit-guardian` verifican patrones prohibidos
(connection strings, API keys, certificados, passwords) antes de cada commit.

Patrones específicos por lenguaje y proveedor: **→ `confidentiality-strategies.md`**

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
