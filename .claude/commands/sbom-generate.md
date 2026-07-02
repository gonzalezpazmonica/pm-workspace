---
name: sbom-generate
description: >
  Generar Software Bill of Materials (SBOM) del proyecto en formato
  CycloneDX. Incluye dependencias directas y transitivas.
agent: security-guardian
skills:
  - azure-devops-queries
tier: extended
---

# /sbom-generate

Genera un Software Bill of Materials (SBOM) del proyecto activo en formato
CycloneDX.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  📋 SBOM Generate                    ║
╚══════════════════════════════════════╝
```

### 2. Detectar dependencias

Leer todos los manifests del proyecto:

- **Directas**: las declaradas en package.json, *.csproj, requirements.txt, etc.
- **Transitivas**: las traídas como dependencias (si lock file disponible)

### 3. Generar SBOM

Formato: CycloneDX JSON v1.4

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "metadata": {
    "project": "{nombre}",
    "timestamp": "{ISO8601}"
  },
  "components": [
    {
      "type": "library",
      "name": "{nombre}",
      "version": "{versión}",
      "scope": "required|optional",
      "source": "direct|transitive"
    }
  ]
}
```

### 4. Guardar output

Fichero: `output/sbom/{proyecto}-sbom-{YYYYMMDD}.json`

### 5. Resumen

```
📊 SBOM generado:
  Componentes directos: X
  Componentes transitivos: Y
  Total: X+Y componentes
  Fichero: output/sbom/{proyecto}-sbom-{YYYYMMDD}.json
  Duración: ~20s
```

### 6. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ SBOM Generate — Completo        ║
╚══════════════════════════════════════╝
📄 SBOM: output/sbom/{proyecto}-sbom-{YYYYMMDD}.json
⚡ /compact
```

