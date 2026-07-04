---
name: credential-scan
description: >
  Escanear historial de git buscando credenciales filtradas.
  Detecta API keys, tokens, passwords y certificados privados.
agent: security-guardian
tier: extended
---

# /credential-scan

Escanea el historial de commits del repositorio buscando credenciales
filtradas accidentalmente.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  🔑 Credential Scan                 ║
╚══════════════════════════════════════╝
```

### 2. Escanear historial

Patrones a buscar (últimos 50 commits):

```bash
git log -50 --all -p | grep -nE \
  'password\s*=\s*["\x27][^"\x27]{8,}|api[_-]?key\s*=\s*["\x27]|token\s*=\s*["\x27][^"\x27]{20,}|-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}|sk-[a-zA-Z0-9]{48}'
```

### 3. Escanear ficheros actuales

```bash
grep -rn "$PATTERNS" \
  --include="*.{cs,ts,js,py,go,rs,php,rb,java,json,yaml,yml,env}" .
```

Excluir: `*.example`, `*.template`, `node_modules/`, `.git/`

### 4. Formato de resultados

```
🔑 Credential encontrada:
  Tipo: {API key|password|token|private key}
  Ubicación: {fichero}:{línea} (commit: {hash corto})
  Riesgo: 🔴 ALTO — rotar inmediatamente
```

### 5. Recomendaciones

Si se encuentran credenciales:

1. Rotar las credenciales comprometidas inmediatamente
2. Usar `git filter-branch` o `BFG Repo-Cleaner` para limpiar historial
3. Mover a vault o `config.local/` (git-ignorado)

### 6. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Credential Scan — Completo      ║
╚══════════════════════════════════════╝
📄 Reporte: output/credential-scans/YYYYMMDD-scan-{proyecto}.md
⚡ /compact
```

