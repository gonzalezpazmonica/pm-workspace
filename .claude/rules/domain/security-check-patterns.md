# Seguridad: Patrones de Detección Detallados

> Referencia extraída de `security-guardian.md`. Contiene regex patterns, implementaciones específicas y ejemplos de cada check.

## SEC-1 — Credenciales y secretos reales

Patrones específicos de alto riesgo:
- AWS Access Key: `AKIA[0-9A-Z]{16}`
- Azure SAS Token: `sv=20[0-9]{2}-`
- Azure DevOps PAT: cadenas Base64 de 52+ caracteres con `=` al final
- Google API Key: `AIza[0-9A-Za-z_-]{35}`
- GitHub Token: `ghp_[A-Za-z0-9]{36}` o `github_pat_`
- JWT completo: tres bloques separados por `.` con > 50 caracteres
- Connection strings con password literal: `password=algo_real` (no `TU_PASSWORD`)
- Private keys: `-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY-----`

Comando de búsqueda:
```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(password\s*[=:]\s*['\"][^'\"]{4,}|token\s*[=:]\s*['\"][^'\"]{8,}|api[_-]?key\s*[=:]\s*['\"][^'\"]{8,}|secret\s*[=:]\s*['\"][^'\"]{8,}|pat\s*[=:]\s*[A-Za-z0-9+/]{20,}|bearer\s+[A-Za-z0-9._-]{20,}|connectionstring\s*[=:]\s*['\"][^'\"]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35})"
```

## SEC-2 — Nombres de proyectos o clientes privados

Comandos de verificación:
```bash
git ls-files projects/ | sed 's|projects/||' | cut -d'/' -f1 | sort -u
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE "projects/"
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(dev\.azure\.com/(?!MI-ORGANIZACION)|azure\.com/[a-zA-Z0-9-]{3,}(?<!ORGANIZACION))"
```

## SEC-3 — IPs y hostnames de infraestructura real

Comando de búsqueda:
```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+|[a-z][a-z0-9-]*\.(internal|local|corp|intranet|lan)\b)"
```

Verificar si está git-ignorado:
```bash
git check-ignore -q FICHERO && echo "ignorado" || echo "rastreado"
```

## SEC-4 — Datos personales reales (GDPR)

Búsqueda de emails reales:
```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "([a-zA-Z0-9._%+-]+@(?!empresa\.com|cliente\.com|cliente-beta\.com|contoso\.com|example\.com|gonzalezpazmonica)[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})"
```

Patrones adicionales:
- DNI/NIF real: 8 dígitos + letra (verificar si es contexto de regex o dato real)
- Teléfonos reales: `[+]?[0-9]{9,15}` fuera de contexto de ejemplo
- Nombres completos en contextos no-ficticios (equipo.md de proyectos NO ejemplo)

## SEC-5 — URLs de repositorios o servicios privados

```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(https?://(?!github\.com/gonzalezpazmonica|dev\.azure\.com/MI-ORGANIZACION|shields\.io)[a-zA-Z0-9.-]+\.(azure\.com|visualstudio\.com|gitlab\.com|bitbucket\.org)/[a-zA-Z0-9/_-]+)"
```

## SEC-6 — Ficheros que nunca deben estar staged

```bash
git diff --cached --name-only | grep -iE \
  "(\.env$|\.env\.|settings\.local\.|\.local\.|pm-config\.local\.|CLAUDE\.local\.|\.pat$|\.secret$|id_rsa|id_ed25519|\.pem$|\.p12$|\.pfx$|\.key$)"
```

Verificar también ficheros de proyectos privados:
```bash
git diff --cached --name-only | grep -iE "(projects/(?!proyecto-alpha|proyecto-beta|sala-reservas)[^/]+/)"
```

## SEC-7 — Información de infraestructura en ficheros rastreados

```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(jdbc:|mongodb://|amqp://|redis://|Server=.*;(User|Password)|Data Source=.*;Password|host\.docker\.internal)" \
  | grep -v "TU_PASSWORD\|TU_PASS\|PASSWORD\|PLACEHOLDER\|ejemplo\|example"
```

## SEC-8 — Marcadores de merge conflict y artefactos de Git

```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -E "^(\+<{7}|\+>{7}|\+={7})"
git diff --cached --name-only | grep -iE "\.(orig|BACKUP|BASE|LOCAL|REMOTE)\."
```

## SEC-9 — Metadatos y comentarios reveladores

```bash
git diff --cached | grep "^+" | grep -v "^\+\+\+" | grep -iE \
  "(TODO.*contraseña|FIXME.*token|HACK.*secret|NOTE.*password|cliente real|proyecto real|empresa real|#.*IP.*real|#.*servidor real)"
```
