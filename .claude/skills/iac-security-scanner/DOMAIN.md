# IaC Security Scanner — Dominio y Conocimiento

## Por que existe esta skill

La infraestructura como código (Terraform, Bicep, CloudFormation, Helm) concentra configuración que en producción controla acceso a datos, redes y servicios críticos. Un error de configuración en un fichero `.tf` puede exponer un bucket S3 al público, abrir un grupo de seguridad a toda internet, o deshabilitar cifrado en reposo.

Este skill usa checkov y/o tfsec para analizar IaC estáticamente antes de que llegue a `terraform apply`.

---

## Categorías de misconfiguration más frecuentes

### Exposición de red
- Security groups con `0.0.0.0/0` en ingress para puertos sensibles (22, 3389, 5432)
- Load balancers sin restricción de IP origen
- Buckets S3/Azure Blob sin bloqueo de acceso público

### Cifrado
- RDS/S3/EBS sin cifrado en reposo habilitado
- Tráfico HTTP en lugar de HTTPS en ALB/API Gateway
- KMS keys sin rotación automática habilitada

### Gestión de identidad
- Roles IAM con permisos `*:*` (wildcard)
- Service accounts con roles de propietario innecesarios
- Secrets en variables de entorno de recursos (en lugar de Secrets Manager/Key Vault)

### Auditoría y logging
- CloudTrail/Azure Monitor deshabilitado
- Flow logs de VPC desactivados
- Retención de logs insuficiente (< 90 días para compliance)

---

## Frameworks de referencia

| Framework | Ámbito | Controles clave |
|---|---|---|
| CIS Benchmarks | AWS/Azure/GCP específicos | ~300 controles por cloud |
| NIST SP 800-190 | Contenedores | Imagen base, permisos, secretos |
| SOC 2 Type II | Organización | Disponibilidad, confidencialidad |
| ISO 27001 Annex A | General | Control de acceso, cifrado |

checkov mapea sus checks a estos frameworks automáticamente.

---

## Política de severidad

| Severidad | Acción requerida | Ejemplo |
|---|---|---|
| CRITICAL | Bloquea CI hasta resolución | Bucket público con datos, SSH abierto a internet |
| HIGH | Bloquea CI (configurable con waiver) | Sin cifrado en RDS, IAM wildcard |
| MEDIUM | Warning en CI, ticket obligatorio | Flow logs desactivados |
| LOW | Informativo | Retención de logs subóptima |

---

## Lo que NO hace este skill

- No ejecuta `terraform plan` ni `terraform apply`
- No modifica ficheros IaC
- No accede a APIs cloud en tiempo real (análisis estático únicamente)
- No sustituye una revisión humana de arquitectura de seguridad
