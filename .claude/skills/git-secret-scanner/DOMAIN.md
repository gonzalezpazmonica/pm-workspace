# Git Secret Scanner — Dominio y Conocimiento

## Por que existe esta skill

Los secretos comprometidos en historial git son la causa más frecuente de brechas de seguridad en proyectos software. Una credencial commiteada por error permanece accesible para siempre en el historial aunque se elimine del último commit — git nunca olvida.

Este skill usa gitleaks para escanear el historial completo o los commits pendientes de push, clasificando los hallazgos por severidad antes de que lleguen a un repositorio remoto.

---

## Taxonomía de secrets por criticidad

| Tipo | Ejemplos | Severidad |
|---|---|---|
| Cloud credentials | AWS_SECRET_ACCESS_KEY, AZURE_CLIENT_SECRET, GCP_SERVICE_ACCOUNT | CRITICAL |
| Database passwords | DATABASE_URL con credenciales, PGPASSWORD | CRITICAL |
| API keys de servicios financieros | Stripe, PayPal, Braintree | CRITICAL |
| Tokens de CI/CD | GitHub PAT, GitLab token, CircleCI token | HIGH |
| Claves privadas | RSA, EC, PGP private keys | HIGH |
| JWT secrets | JWT_SECRET, SESSION_SECRET con valor hardcodeado | HIGH |
| API keys de servicios | SendGrid, Twilio, Slack webhook | MEDIUM |
| Contraseñas en código | strings que coinciden con patrones de contraseña | MEDIUM |
| Hashes internos | tokens de desarrollo, claves de test | LOW |

---

## Patrones de detección (gitleaks)

gitleaks usa reglas en TOML que combinan:
- **Regex**: patrón de la clave en sí (ej. `AKIA[0-9A-Z]{16}` para AWS access keys)
- **Keywords**: palabras clave en el contexto (ej. `secret`, `password`, `token`)
- **Entropy**: entropía de Shannon del string (>3.5 para base64, >3.0 para hex)

Un hallazgo real requiere que al menos dos de los tres criterios coincidan — reduce falsos positivos.

---

## Política de remediation

### Regla fundamental
Un secret commiteado **no se elimina borrando el archivo** — está en el historial. Las únicas acciones válidas son:
1. **Rotar inmediatamente** la credencial comprometida (antes de cualquier otra acción)
2. **Limpiar historial** con `git filter-repo` o BFG Repo Cleaner (requiere force-push coordinado)
3. **Documentar** el incidente como N3 en `output/security/`

### Lo que NO hace este skill
- No rota credenciales automáticamente
- No modifica el historial git
- No reporta findings a sistemas externos

Todas las acciones correctivas son responsabilidad humana. El skill genera findings y comandos sugeridos, nunca los ejecuta.

---

## Allowlist y falsos positivos

Los falsos positivos comunes que deben ir a `.gitleaks.toml` allowlist:
- Hashes de test fijos en fixtures
- Ejemplos en documentación (marcados con `EXAMPLE_` o `FAKE_`)
- Valores de configuración públicos sin privilegios (ej. client IDs OAuth)
- Credenciales de entornos de CI explícitamente mock

Umbral configurable: `GITLEAKS_THRESHOLD` en `.env` del proyecto.

---

## Integración con pre-push hook

El flujo de SE-247 (pre-push gate) invoca este scanner como primera validación antes de permitir el push. Si encuentra hallazgos CRITICAL o HIGH, el push se bloquea hasta que el humano confirma que son falsos positivos o rota las credenciales.
