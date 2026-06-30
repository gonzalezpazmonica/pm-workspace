---
context_tier: L2
token_budget: 1100
resource: internal://docs/rules/domain/iac-security-policy.md
---

# Política: IaC Security Scanning — SE-241

> Todo IaC generado por Savia pasa `trivy config` antes del merge humano.
> El humano recibe siempre el IaC junto con su security score, nunca separados.

## Principio fundamental

Savia genera IaC (Terraform, Bicep, Dockerfiles, Kubernetes) pero nunca lo aplica
sin aprobación humana. El gate de seguridad ocurre entre generación y aprobación:
el agente genera → Trivy escanea → humano recibe propuesta + security score.

## Severidades bloqueantes vs informativas

| Severidad | Comportamiento | Exit code CI |
|---|---|---|
| CRITICAL | Bloquea CI, requiere corrección antes del merge | 1 |
| HIGH | Bloquea CI, requiere corrección o supresión justificada | 1 |
| MEDIUM | Informativo — warning en stdout, no bloquea | 0 |
| LOW | Informativo — warning en stdout, no bloquea | 0 |

Default: `--severity CRITICAL,HIGH` bloquea. MEDIUM/LOW son informativos.

El humano puede override explícito de un hallazgo CRITICAL añadiéndolo a
`.trivyignore` con justificación documentada. El CI no hace override automático.

## Herramientas

- **Trivy (local)**: escaneo offline sobre ficheros IaC — gate pre-aprobación
- **Fallback Docker**: `docker run --rm -v "$(pwd):/workspace" aquasec/trivy:latest config /workspace`
- **Prowler / ScoutSuite**: auditoría periódica de cloud desplegado (requieren credenciales)

## Scripts de referencia

```bash
# Gate pre-aprobación
bash scripts/iac-security-scan.sh --path ./infra/ --severity CRITICAL,HIGH

# Escanear imagen Docker referenciada en IaC
bash scripts/iac-security-scan.sh --image myapp:latest

# Generar baseline para proyectos legacy
bash scripts/iac-security-baseline.sh --path ./infra/ --output .trivyignore
```

## Gestión de falsos positivos con .trivyignore

Cuando una misconfiguración es un falso positivo conocido o aceptado:

```ini
# .trivyignore
# AVD-AWS-0089: S3 bucket con acceso público requerido para hosting web estático
# Justificación: bucket exclusivamente para assets públicos del frontend
# Revisión: 2026-Q3
AVD-AWS-0089
```

Reglas del `.trivyignore`:
1. **Toda supresión requiere comentario** con justificación y fecha de revisión
2. **Las supresiones no son permanentes** — planificar corrección en backlog
3. **CRITICAL suprimidas requieren aprobación del security-guardian** antes de merge
4. **El fichero se versiona** — cambios en `.trivyignore` disparan revisión

## Misconfiguraciones más comunes en IaC generado por LLMs

Los modelos tienden a generar configuraciones permisivas por defecto:

| Recurso | Problema | Regla Trivy |
|---|---|---|
| S3 / Blob Storage | ACL pública por defecto | AVD-AWS-0089, AVD-AZU-0011 |
| Security Group / NSG | `0.0.0.0/0` en todos los puertos | AVD-AWS-0105, AVD-AZU-0047 |
| IAM / RBAC | Wildcard `*` en actions o resources | AVD-AWS-0057, AVD-AZU-0035 |
| RDS / Storage | Sin cifrado en reposo | AVD-AWS-0077, AVD-AZU-0022 |
| Container (Dockerfile) | Ejecuta como root (USER ausente) | DS002 |
| Kubernetes Pod | Privileged: true, hostPID, hostNetwork | KSV001, KSV002 |
| TLS / HTTPS | HTTP expuesto sin redirección | AVD-AWS-0053 |

## Confidencialidad de reports

- Reports en `output/security/` — clasificados N3 (confidencial interno)
- Las credenciales cloud NUNCA se incluyen en reports
- `output/security/` debe estar en `.gitignore`
- ScoutSuite genera HTML con detalles de cuenta — clasificado N3

## Integración CI

```yaml
# .github/workflows/iac-security.yml (fragmento)
- name: IaC Security Scan
  run: bash scripts/iac-security-scan.sh --path ./infra/ --severity CRITICAL,HIGH
  # exit 1 automáticamente si CRITICAL/HIGH detectados
```

Ver: `docs/rules/domain/infrastructure-as-code.md` — SE-241
