---
context_tier: L2
token_budget: 150
se: SE-247
---

# Pre-Push Security Gate

Hook `pre-push` que ejecuta Gitleaks sobre los commits locales no pusheados. Última
línea de defensa antes de que código llegue al remote. Complementa (no reemplaza)
`block-credential-leak.sh` (pre-write) y SE-239 (historial completo).

## Cuándo se activa

Automáticamente en cada `git push` en repos donde está instalado. Solo escanea los
commits del diff entre remote y local — no el historial completo.

## Instalar

```bash
bash scripts/install-prepush-hook.sh
# O en un repo externo:
bash scripts/install-prepush-hook.sh --repo /ruta/al/repo
```

El script es idempotente: si el hook ya existe y es SE-247, no sobreescribe.
Si existe otro hook, hace backup automático (`.git/hooks/pre-push.bak.TIMESTAMP`).

## Desactivar temporalmente

```bash
SAVIA_PREPUSH_SECURITY=off git push
```

Usar solo en emergencias. El bypass queda sin registro si `commit-guardian` no está
activo. `git push --no-verify` también bypassa el hook — es intencional (el
desarrollador asume la responsabilidad).

## Actualizar la allowlist

Editar `.gitleaks.toml` en la raíz del repo. Secciones relevantes:

```toml
[allowlist]
paths = [
  '''tests/.*''',          # fixtures de test
  '''docs/examples/.*''',  # ejemplos en docs
]
regexes = [
  '''diff_hash=[0-9a-f]{64}''',   # firmas de confidencialidad Savia
  '''fake[_-]?(token|key)''',     # placeholders
]
```

## Output

Findings se escriben en `output/security/pre-push-findings.jsonl` (git-ignorado, N3).
El script verifica que `output/` esté en `.gitignore` antes de escribir.
**Nunca se imprime el valor del secret** — solo tipo, fichero, línea y commit hash truncado.

## Qué detecta gitleaks

| Categoría | Ejemplos |
|---|---|
| Cloud credentials | AWS Access Key, GCP Service Account, Azure SAS Token |
| Tokens de plataforma | GitHub PAT, GitLab Token, Slack Token, Discord Token |
| Claves privadas | RSA, EC, OpenSSH private key, PGP |
| Contraseñas genéricas | Patrones `password=`, `passwd=`, `pwd=` en código |
| Credenciales de BD | Connection strings con usuario:contraseña |
| API Keys | Stripe, Twilio, SendGrid, Mailgun, etc. |
| Certificados | PEM blocks, PKCS12 |

## Capa en la cadena de seguridad

| Hook | Momento | Qué analiza |
|---|---|---|
| `block-credential-leak.sh` | Pre-write | Contenido nuevo del fichero |
| `commit-guardian` | Pre-commit | Staged diff |
| **SE-247** | **Pre-push** | **Commits locales no pusheados** |
| SE-239 | On-demand | Historial completo |

## Remediar un finding

1. Rotar el credential inmediatamente (no esperar a limpiar el historial).
2. Eliminar o reemplazar el secret en el fichero.
3. Si el secret ya está en commits anteriores: `bash scripts/git-history-secret-remediate.sh`.
4. Si es falso positivo: añadir excepción en `.gitleaks.toml`.
