---
layer: peripheral
name: dependency-scanner
description: "Usar cuando se escanean vulnerabilidades en dependencias de proyectos (Node, Python, C#, Java, Go, Rust, Ruby) con Trivy fs. Genera SBOM CycloneDX."
metadata:
  # --- metadata.savia.* (SE-333) ---
  savia.category: security
  savia.maturity: beta
  savia.context: fork
  savia.context_cost: low
  savia.priority: high
  savia.summary: "Escanea manifiestos de dependencias con Trivy filesystem mode. Detecta CVEs en npm, pip, nuget, maven, cargo, go.mod, bundler. Genera SBOM CycloneDX JSON como artefacto de release. Bloqueante: CRITICAL/HIGH → exit 1. Informativo: MEDIUM/LOW. Error del escáner o SBOM fallido → exit 2. Output en output/security/."
  savia.tags: "security, dependencies, trivy, sbom, cve, supply-chain"
  savia.trigger_keywords: "escanea dependencias, vulnerabilidades en paquetes, dep scan, SBOM, supply chain security, CVE en npm, CVE en pip, vulnerabilidades node, vulnerabilidades python, dependency vulnerability"
---

## Subagent Scope Guard

> Si fuiste invocado como subagente para una tarea concreta, ejecuta solo esa
> tarea, reporta DONE / DONE_WITH_CONCERNS / BLOCKED y retorna.

# Dependency Scanner Skill

## §0 Cuándo usar

- Después de que un agente de lenguaje genera un proyecto con dependencias
- En CI en cada PR que toca `package*.json`, `requirements*.txt`, `*.csproj`, etc.
- Antes de un release para generar el SBOM obligatorio (proyectos enterprise)
- Cuando el humano pide revisar vulnerabilidades en dependencias

## §1 Activación por language pack

Este skill se activa automáticamente cuando se trabaja con:

| Language Pack | Manifiestos escaneados |
|---|---|
| TypeScript/Node | package.json, package-lock.json, yarn.lock |
| Python | requirements.txt, Pipfile, pyproject.toml |
| .NET/C# | *.csproj, packages.config, packages.lock.json |
| Java | pom.xml, build.gradle |
| Go | go.mod, go.sum |
| Rust | Cargo.toml, Cargo.lock |
| Ruby | Gemfile, Gemfile.lock |

## §2 Uso básico

```bash
# Escanear proyecto
bash scripts/dependency-scan.sh --path ./project/

# Generar SBOM CycloneDX además del report
bash scripts/dependency-scan.sh --path ./project/ --generate-sbom

# Solo CRITICAL (más estricto para CI)
bash scripts/dependency-scan.sh --path ./project/ --severity CRITICAL

# Modo offline (DB ya descargada)
bash scripts/dependency-scan.sh --path ./project/ --skip-update
```

Códigos de salida: `0` limpio en las severidades pedidas · `1` hallazgos (se listan
severidad, CVE, paquete, versión → fix y manifiesto) · `2` error de argumentos, sin
Trivy ni Docker, escaneo fallido, esquema de informe desconocido o SBOM no generado. El 2
gana al 1: hallazgos con SBOM fallido salen con 2 (los hallazgos se listan igualmente). Requiere Trivy >= 0.37 (`--scanners`)
y `jq`. `DEP_SCAN_OUTPUT_DIR` cambia el directorio de salida.

## §3 Auto-detección de tipo de proyecto

El script detecta automáticamente el tipo de proyecto buscando manifiestos
conocidos. No requiere configuración manual del lenguaje.

## §4 Fallback Docker

Si Trivy no está instalado localmente:

```bash
docker run --rm -v "$(pwd):/workspace" aquasec/trivy:latest fs /workspace
```

El script lo hace solo: monta el path escaneado en `/workspace` y pasa las mismas
banderas (el `.trivyignore` del path se usa; el de la raíz del workspace no está montado).

## §5 SBOM — Software Bill of Materials

El SBOM en formato CycloneDX es un artefacto de release obligatorio para
proyectos enterprise. Documenta exactamente qué dependencias incluye el
software. Generarlo no requiere conectividad extra (DB local). Si Trivy falla, no se
escribe SBOM (exit 2): nunca se fabrica uno vacío. La salida de Trivy queda como
`sbom-YYYYMMDD.json.failed` y un SBOM anterior del mismo día pasa a `.stale`. Un escaneo
fallido deja `dep-scan-YYYYMMDD.json.failed` sin pisar el informe válido anterior.

```
output/security/sbom-YYYYMMDD.json     ← SBOM CycloneDX
output/security/dep-scan-YYYYMMDD.json ← Report de CVEs
```

## §6 Gestión de vulnerabilidades encontradas

1. **CRITICAL**: siempre actualizar la dependencia afectada
2. **HIGH con fix disponible**: actualizar en el sprint actual
3. **HIGH sin fix**: suprimir en `.trivyignore` con justificación y fecha
4. **MEDIUM/LOW**: informativo — planificar en el backlog

Ver política completa: `docs/rules/domain/dependency-security-policy.md`
