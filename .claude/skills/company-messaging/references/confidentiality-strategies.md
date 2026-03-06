# Anexo: Estrategias de Protección por Plataforma
# ── Implementación detallada, patrones por lenguaje y migración de secrets ────

## Azure — Key Vault + App Configuration

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

## AWS — Secrets Manager + Parameter Store

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

## GCP — Secret Manager

```bash
# Almacenar secret
echo -n "postgresql://..." | gcloud secrets create miapp-dev-db-connection \
  --replication-policy="automatic" \
  --data-file=-

# Acceder en aplicación
gcloud secrets versions access latest --secret="miapp-dev-db-connection"
```

## Local / Docker — dotenv (git-ignorado)

```bash
# config.local/.env.DEV — NUNCA en repositorio
DATABASE_CONNECTION_STRING=Server=localhost;Database=miapp;User=sa;Password=...
REDIS_CONNECTION_STRING=localhost:6379
API_KEY_EXTERNAL_SERVICE=sk-...
```

---

## Validación Pre-Commit — Patrones Prohibidos

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

---

## Rotación de Secrets

| Tipo | Frecuencia | Auto |
|---|---|---|
| Passwords BD | 90 días | Sí |
| API keys propias | 180 días | Sí |
| Tokens servicio | 30 días | Sí |
| Certificados TLS | Antes expiración | Sí |
| PAT Azure DevOps | 90 días | Manual |

### Proceso

1. Generar nuevo secret en vault
2. Actualizar aplicación para usar nuevo
3. Verificar que funciona
4. Revocar anterior (gracia de 24h)
5. Documentar rotación
