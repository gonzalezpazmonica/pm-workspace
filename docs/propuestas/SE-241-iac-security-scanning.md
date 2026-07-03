---
id: SE-241
title: "IaC security scanning — Trivy + Prowler + ScoutSuite para Terraform, containers y cloud"
status: IMPLEMENTED
priority: P1
effort: M (12h — S1 4h + S2 4h + S3 4h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - terraform-developer agent
  - infrastructure-agent agent
  - SE-244 (dependency-vulnerability-scanning — Trivy deps, uso distinto)
  - nuclei-scanning skill
  - adversarial-security skill
  - docs/rules/domain/infrastructure-as-code.md
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - Trivy
  - Prowler
  - ScoutSuite
---

# SE-241 — IaC security scanning

## Problema

El agente `terraform-developer` genera ficheros `.tf` y el agente `infrastructure-agent`
orquesta despliegues cloud. Ambos operan bajo la regla "nunca ejecutar `terraform apply`
sin aprobación humana", pero no existe ningún gate de seguridad sobre el IaC generado:

- Un fichero `.tf` puede contener configuraciones inseguras: S3 buckets públicos, grupos de
  seguridad con `0.0.0.0/0`, IAM roles con `*` permissions, sin cifrado en reposo
- Las imágenes Docker referenciadas en el IaC pueden tener CVEs críticos
- No hay verificación de misconfiguraciones en manifiestos Kubernetes generados
- El `security-judge` del Court no tiene reglas específicas para Terraform/HCL/Dockerfile
- Prowler y ScoutSuite pueden auditar la infraestructura cloud ya desplegada (drift entre
  IaC y realidad)

El riesgo es real: un terraform-developer generando IaC con misconfiguraciones puede
desembocar en infraestructura expuesta si el humano aprueba sin análisis de seguridad.

## Tesis

Un hook de pre-aprobación que ejecuta Trivy sobre los ficheros IaC y Dockerfiles antes
de que el humano reciba la propuesta de `terraform apply`, más un script periódico que
invoca Prowler/ScoutSuite contra la infraestructura cloud ya desplegada. El objetivo es
que el humano reciba siempre el IaC junto con su security score, no separados.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| Trivy (IaC mode) | Escanea Terraform, CloudFormation, Kubernetes, Dockerfiles en busca de misconfiguraciones | `trivy config ./infra/` y `trivy image <image>` | Sí (binario local, DB offline) |
| Prowler | Auditoría de cloud compliance contra CIS, NIST, ISO 27001 en AWS/Azure/GCP | `prowler aws --compliance cis_level1_aws` | No (requiere credenciales cloud) |
| ScoutSuite | Multi-cloud security auditing: analiza configuración real de la cuenta cloud | `scout aws --report-dir output/security/` | No (requiere credenciales cloud) |

**Separación de responsabilidades**:
- Trivy: actúa sobre ficheros locales (offline, siempre disponible) — gate pre-aprobación
- Prowler/ScoutSuite: actúan contra cloud real (requieren credenciales) — auditoría periódica

## Diseño

### Integración en pipeline Savia

```
Gate pre-aprobación IaC:
  terraform-developer genera .tf
    → scripts/security/trivy-iac-scan.sh ./infra/
    → Report de misconfiguraciones adjunto a la propuesta humana
    → Bloqueante si CRITICAL (human puede override explícito)

Auditoría periódica cloud:
  /audit-cloud-infrastructure [provider] [profile]
    → Prowler para compliance checks
    → ScoutSuite para inventario completo
    → Report N3 en output/security/cloud-audit-YYYYMMDD/
```

### Script `scripts/security/trivy-iac-scan.sh`

- Parámetros: `--path <dir>` (Terraform root), `--severity HIGH,CRITICAL` (default)
- Ejecuta `trivy config` sobre `.tf`, `Dockerfile`, `*.yaml` (K8s manifests)
- Ejecuta `trivy image` sobre imágenes referenciadas en el IaC si están disponibles localmente
- Output: JSON en `output/security/iac-scan-YYYYMMDD.json` + resumen a stdout
- Exit code 1 si findings CRITICAL
- Incluye DB de vulnerabilidades en modo offline (`trivy --skip-update` con DB pre-descargada)

### Script `scripts/security/cloud-audit.sh`

- Parámetros: `--provider aws|azure|gcp`, `--tool prowler|scoutsuite|both`
- Credenciales desde variables de entorno o `~/.aws/credentials` (NUNCA hardcoded)
- Output consolidado en `output/security/cloud-audit-YYYYMMDD/`
- Genera resumen ejecutivo (compliance score por categoría CIS)

### Integración con agentes existentes

- `terraform-developer` incluye en su output: "Ejecutar `trivy-iac-scan.sh` antes de aplicar"
- `infrastructure-agent` invoca `trivy-iac-scan.sh` como paso previo a presentar la propuesta
- `security-guardian` puede invocar `cloud-audit.sh` en auditorías periódicas

### Reglas Trivy para Savia

Fichero `.trivyignore` en la raíz del proyecto para suprimir falsos positivos conocidos.
Configuración mínima de severidades en `trivy.yaml`:
```yaml
severity: HIGH,CRITICAL
exit-code: 1
format: json
```

### Confidencialidad

Reports en `output/security/` (N3). Las credenciales cloud nunca se incluyen en los reports.
ScoutSuite genera HTML con detalles de la cuenta — clasificado N3.

## Slices

**S1 — Trivy IaC scan script (4h)**
- `scripts/security/trivy-iac-scan.sh`
- Soporte Terraform + Dockerfile + K8s manifests
- DB offline mode con instrucciones de actualización
- BATS tests con fixtures de IaC conocidamente inseguros (S3 público, SG abierto)

**S2 — Prowler + ScoutSuite cloud audit script (4h)**
- `scripts/security/cloud-audit.sh`
- Soporte AWS (primero), Azure y GCP como extensión
- Credenciales desde env vars, never hardcoded
- Report consolidado con compliance score

**S3 — Integración con terraform-developer + comando (4h)**
- Modificación del agent prompt de `terraform-developer` para incluir referencia al scan
- Comando `/audit-iac [path]` en `.opencode/commands/`
- Comando `/audit-cloud [provider]` en `.opencode/commands/`
- Documentación en `docs/rules/domain/infrastructure-as-code.md`

## Criterios de aceptación

- [ ] `trivy-iac-scan.sh` detecta S3 bucket público en fixture Terraform conocido
- [ ] `trivy-iac-scan.sh` funciona en modo offline con DB pre-descargada
- [ ] Exit code 1 cuando hay findings CRITICAL; exit 0 en IaC limpio
- [ ] Las credenciales cloud nunca aparecen en ningún report generado
- [ ] `cloud-audit.sh` produce report JSON + HTML en `output/security/`
- [ ] `output/security/` verificado en .gitignore antes de escribir
- [ ] Fixtures de tests documentados (IaC inseguro conocido + IaC limpio)
- [ ] `terraform-developer` agent menciona el scan en su output estándar
- [ ] Trivy distingue entre `config` (IaC) y `image` (container) en el mismo run

## Qué NO incluye

- Análisis de vulnerabilidades de dependencias de lenguaje (pip, npm, nuget) — eso es SE-244
- Aplicación automática de fixes en ficheros `.tf` — requiere decisión humana
- Auditoría de Kubernetes en producción con privilegios de cluster-admin
- Integración con Vault o gestión de secretos cloud — fuera de scope de esta spec
- ScoutSuite en modo continuo/SaaS — sólo auditoría puntual on-demand
