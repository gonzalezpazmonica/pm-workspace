# Dependency Scanner — Dominio y Conocimiento

## Por que existe esta skill

Las dependencias de terceros son el vector más explotado en ataques a la cadena de suministro software (supply chain attacks). El 80% del código en una aplicación típica es de terceros. Una vulnerabilidad en una librería transitiva — que nadie revisó conscientemente — puede comprometer toda la aplicación.

Este skill genera un SBOM (Software Bill of Materials) y escanea las dependencias contra bases de datos de CVEs conocidos.

---

## SBOM — Software Bill of Materials

El SBOM es el inventario completo de componentes de software. Formatos estándar:

| Formato | Estándar | Adopción |
|---|---|---|
| SPDX | Linux Foundation / ISO 5962 | Amplio en open source |
| CycloneDX | OWASP | Amplio en seguridad empresarial |
| SWID | ISO/IEC 19770 | Gobierno y enterprise |

Un SBOM mínimo incluye: nombre, versión, licencia, hash, proveedor, y dependencias transitivas.

---

## Bases de datos de vulnerabilidades

| Base de datos | Cobertura | Actualización |
|---|---|---|
| NVD (NIST) | CVEs oficiales MITRE | Continua |
| OSV (Google) | Ecosistemas open source | Tiempo real |
| GitHub Advisory | npm, PyPI, Maven, Go, Rust | Tiempo real |
| Snyk DB | Propietaria, con exploitability data | Tiempo real |

El scanner usa múltiples fuentes para maximizar cobertura y reducir falsos negativos.

---

## Clasificación de severidad (CVSS v3)

| CVSS Score | Severidad | Acción |
|---|---|---|
| 9.0 – 10.0 | CRITICAL | Actualizar antes de merge |
| 7.0 – 8.9 | HIGH | Actualizar en el sprint actual |
| 4.0 – 6.9 | MEDIUM | Planificar actualización |
| 0.1 – 3.9 | LOW | Informativo, backlog |

**Contexto de explotabilidad**: un CVSS alto en una dependencia de desarrollo (no incluida en producción) tiene impacto real menor. El scanner distingue `devDependencies` vs dependencias de producción.

---

## Ecosistemas soportados

| Ecosistema | Fichero de lock | Herramienta |
|---|---|---|
| Node.js/npm | `package-lock.json`, `yarn.lock` | `npm audit`, `osv-scanner` |
| Python | `requirements.txt`, `Pipfile.lock`, `poetry.lock` | `pip-audit`, `osv-scanner` |
| Java/Maven | `pom.xml` | `dependency-check`, `osv-scanner` |
| .NET/NuGet | `packages.lock.json`, `*.csproj` | `dotnet list package --vulnerable` |
| Go | `go.sum` | `govulncheck`, `osv-scanner` |
| Rust | `Cargo.lock` | `cargo audit` |

---

## Gestión de excepciones

Las vulnerabilidades con mitigaciones compensatorias se documentan en `output/security/sbom-exceptions.yaml`:

```yaml
exceptions:
  - cve: CVE-2024-XXXXX
    package: lodash@4.17.20
    reason: "Solo se usa en scripts de build, no expuesto en runtime"
    mitigacion: "Aislado en devDependencies, sin acceso a datos de usuario"
    revisado_por: "nombre"
    fecha_revision: "2026-01-15"
    fecha_expiracion: "2026-07-15"
```

Las excepciones expiran y requieren re-revisión periódica.

---

## Lo que NO hace este skill

- No actualiza dependencias automáticamente
- No evalúa si una vulnerabilidad es explotable en el contexto específico (requiere juicio humano)
- No sustituye un análisis SAST del código propio
