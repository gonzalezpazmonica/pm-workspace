---
context_tier: L2
token_budget: 1100
resource: internal://docs/rules/domain/dependency-security-policy.md
---

# Política: Dependency Vulnerability Scanning — SE-244

> Todo proyecto generado por Savia incluye dependency scan en CI.
> El SBOM CycloneDX es artefacto de release obligatorio para proyectos enterprise.

## Principio fundamental

Los agentes de lenguaje generan proyectos con dependencias externas que pueden
tener CVEs conocidos. Savia no entrega código con dependencias vulnerables sin
que el humano tenga visibilidad del riesgo. El scan ocurre post-generación,
pre-merge.

## Severidades y umbrales

| Severidad | CVSSv3 | Comportamiento | Exit code CI |
|---|---|---|---|
| CRITICAL | >= 9.0 | Bloquea siempre — fix obligatorio | 1 |
| HIGH | >= 7.0 | Bloquea cuando existe fix disponible | 1 |
| MEDIUM | 4.0–6.9 | Informativo — no bloquea | 0 |
| LOW | < 4.0 | Informativo — no bloquea | 0 |

Zero false positives policy: solo se reporta lo que tiene impacto real confirmado.

## Script de referencia

```bash
# Escanear dependencias
bash scripts/dependency-scan.sh --path ./project/

# Escanear + generar SBOM
bash scripts/dependency-scan.sh --path ./project/ --generate-sbom

# Solo CRITICAL en CI estricto
bash scripts/dependency-scan.sh --path ./project/ --severity CRITICAL
```

## Manifiestos soportados

| Lenguaje | Manifiestos detectados automáticamente |
|---|---|
| Node / TypeScript | package.json, package-lock.json, yarn.lock |
| Python | requirements.txt, Pipfile, pyproject.toml, poetry.lock |
| .NET / C# | *.csproj, packages.config, packages.lock.json |
| Java | pom.xml, build.gradle |
| Go | go.mod, go.sum |
| Rust | Cargo.toml, Cargo.lock |
| Ruby | Gemfile, Gemfile.lock |
| PHP | composer.json, composer.lock |

## Ciclo de vida de vulnerabilidades

### 1. Detectar
```bash
bash scripts/dependency-scan.sh --path ./project/
# → output/security/dep-scan-YYYYMMDD.json
```

### 2. Evaluar
- ¿Existe un fix (versión sin CVE)? → actualizar inmediatamente
- ¿El código vulnerable se llama desde el proyecto? → evaluar impacto real
- ¿Es un falso positivo documentado? → suprimir con `.trivyignore`

### 3. Parchear o suprimir con justificación

**Parchear** (opción preferida):
```
# requirements.txt — antes
requests==2.25.0  # CVE-2023-32681: SSRF via proxies

# requirements.txt — después
requests>=2.31.0
```

**Suprimir con justificación** (cuando no existe fix):
```ini
# .trivyignore
# CVE-2022-XXXX: librería afectada no se invoca en rutas accesibles
# Justificación: función vulnerable solo se llama con input interno controlado
# Revisión: 2026-Q3 — actualizar cuando salga fix
CVE-2022-XXXX
```

## SBOM — Software Bill of Materials

El SBOM (Software Bill of Materials) en formato CycloneDX documenta todas las
dependencias incluidas en el software, sus versiones y licencias.

**Obligatorio para**:
- Proyectos enterprise antes de cada release
- Software entregado a clientes regulados (banca, salud, gobierno)
- Proyectos con requisitos de compliance (SOC2, ISO 27001, NIS2)

**Generación**:
```bash
bash scripts/dependency-scan.sh --path ./project/ --generate-sbom
# → output/security/sbom-YYYYMMDD.json (CycloneDX JSON)
```

**Conservación**: el SBOM de cada release se archiva junto con los artefactos
de build. Permite responder a "¿usábamos X cuando salió CVE-Y?" meses después.

## Integración CI

```yaml
# .github/workflows/deps-scan.yml (fragmento)
on:
  pull_request:
    paths:
      - '**/package*.json'
      - '**/requirements*.txt'
      - '**/*.csproj'
      - '**/pom.xml'
      - '**/go.mod'
      - '**/Cargo.toml'
      - '**/Gemfile'

jobs:
  dep-scan:
    steps:
      - name: Dependency Vulnerability Scan
        run: bash scripts/dependency-scan.sh --path . --severity CRITICAL,HIGH
```

## Confidencialidad de reports

- Reports en `output/security/` — clasificados N3
- `output/security/` debe estar en `.gitignore`
- El SBOM puede compartirse con clientes (no contiene secretos)

Ver: SE-244, SE-241 (IaC scanning — herramienta compartida Trivy, targets distintos)
