---
name: adversarial-security
description: Pipeline de seguridad adversarial — Red Team, Blue Team, Auditor con scoring
maturity: stable
context: fork
context_cost: medium
agent: security-attacker
---

# Adversarial Security Skill

## §1 Vulnerability Scoring

**CVSS simplificado para proyectos internos**:

| Factor | Peso | Valores |
|--------|------|---------|
| Attack Vector | 0.3 | Network (1.0), Adjacent (0.7), Local (0.5), Physical (0.2) |
| Complexity | 0.2 | Low (1.0), High (0.5) |
| Privileges | 0.2 | None (1.0), Low (0.6), High (0.3) |
| Impact | 0.3 | High (1.0), Medium (0.6), Low (0.3) |

score = sum(factor × peso) × 10 → escala 0-10

## §2 STRIDE Mapping

| Categoría | Pregunta clave | Controles típicos |
|-----------|---------------|-------------------|
| Spoofing | ¿Puedo suplantar a otro? | Auth, MFA, tokens |
| Tampering | ¿Puedo modificar datos? | Integridad, signing, HMAC |
| Repudiation | ¿Puedo negar una acción? | Audit logs, timestamps |
| Info Disclosure | ¿Puedo acceder a datos? | Encryption, access control |
| DoS | ¿Puedo tumbar el servicio? | Rate limiting, WAF |
| Elevation | ¿Puedo escalar privilegios? | RBAC, least privilege |

## §3 OWASP Top 10 Checklist

1. Broken Access Control
2. Cryptographic Failures
3. Injection
4. Insecure Design
5. Security Misconfiguration
6. Vulnerable Components
7. Auth Failures
8. Software/Data Integrity Failures
9. Logging Failures
10. SSRF

## §4 Dependency Audit

```bash
# npm: audit de dependencias
npm audit --json 2>/dev/null | jq '.vulnerabilities | length'
# pip: safety check
pip-audit --format=json 2>/dev/null
# dotnet: audit
dotnet list package --vulnerable --format json 2>/dev/null
```

## §5 Security Score Formula

score = 100 - (critical×25 + high×10 + medium×3 + low×1)
Cada fix verificado recupera los puntos. Floor: 0.
