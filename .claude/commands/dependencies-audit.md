---
name: dependencies-audit
description: >
  Auditoría de dependencias del proyecto para vulnerabilidades conocidas
  y versiones desactualizadas. Soporta npm, pip, Go, Rust, .NET, Ruby, PHP.
agent: security-guardian
skills:
  - azure-devops-queries
tier: extended
---

# /dependencies-audit

Revisa las dependencias del proyecto activo buscando vulnerabilidades conocidas
y versiones desactualizadas.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  📦 Dependencies Audit              ║
╚══════════════════════════════════════╝
```

### 2. Detectar stack y manifest

Buscar por orden de prioridad:

- `package.json` / `package-lock.json` → npm audit
- `*.csproj` / `packages.config` → dotnet list package --vulnerable
- `requirements.txt` / `Pipfile` → pip-audit / safety
- `go.mod` → govulncheck
- `Cargo.toml` → cargo audit
- `composer.json` → composer audit
- `Gemfile` → bundle audit

### 3. Ejecutar auditoría nativa

```bash
npm audit --json 2>/dev/null
dotnet list package --vulnerable
pip-audit
govulncheck ./...
cargo audit
```

Si la herramienta nativa no está disponible, análisis manual de CVEs.

### 4. Formato de resultados

```
📦 {dependencia} {versión_actual}
   🔴 CVE-XXXX-XXXXX (Critical) — {descripción breve}
   Recomendación: Actualizar a {versión_segura}
```

### 5. Resumen

```
📊 Dependencies Audit:
  Total: X dependencias
  🔴 Critical: X | 🟡 High: Y | 🟠 Medium: Z | 🔵 Low: W
  Actualizaciones requeridas: X
  Duración: ~30s
```

### 6. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Dependencies Audit — Completo   ║
╚══════════════════════════════════════╝
📄 Detalle: output/dependencies/YYYYMMDD-audit-{proyecto}.md
⚡ /compact
```

