---
name: git-secret-scanner
description: "Escanea el historial git o los commits pendientes de push buscando secrets con gitleaks. SE-239/SE-247."
summary: |
  Escaneo de secrets en historial git con gitleaks.
  Clasificación CRITICAL/HIGH/MEDIUM/LOW.
  Output: JSONL + summary MD en output/security/.
maturity: stable
context: fork
context_cost: low
category: "security"
tags: ["security", "gitleaks", "secret", "git-history", "pre-push"]
trigger:
  type: keyword
  keywords: ["escanea el historial", "busca secrets", "git secret scan", "secret scanning", "scan history", "gitleaks"]
se: SE-239
---

# Git Secret Scanner Skill

Detecta secrets en el historial git o en commits pendientes de push.

## Triggers

- "escanea el historial"
- "busca secrets en git"
- "git secret scan"
- "hay secrets en el repo?"
- "gitleaks"

## Uso rápido

### Escanear historial completo

```bash
bash scripts/git-history-secret-scan.sh
```

### Escanear solo desde un punto

```bash
bash scripts/git-history-secret-scan.sh --since HEAD~50
bash scripts/git-history-secret-scan.sh --since 2026-01-01
bash scripts/git-history-secret-scan.sh --since v1.0.0
```

### Instalar hook pre-push (SE-247)

```bash
bash scripts/install-prepush-hook.sh
```

## Outputs

| Fichero | Contenido |
|---|---|
| `output/security/history-scan-YYYYMMDD.jsonl` | Findings completos (git-ignorado) |
| `output/security/history-scan-YYYYMMDD-summary.md` | Resumen legible |
| `output/security/pre-push-findings.jsonl` | Findings del hook pre-push |

Todos en `output/security/` — git-ignorado (N3, confidencial).

## Exit codes

| Code | Significado |
|---|---|
| 0 | Sin findings — repo limpio |
| 1 | Findings CRITICAL o HIGH |
| 2 | Solo findings MEDIUM o LOW |

## Severidad

| Nivel | Qué incluye |
|---|---|
| CRITICAL | AWS keys, GCP tokens, GitHub PAT, private keys |
| HIGH | Contraseñas, certificados, credentials genéricos |
| MEDIUM | URIs con credenciales embebidas |
| LOW | Posibles falsos positivos, entropy alta sin regex match |

## Remediar un finding

```bash
bash scripts/git-history-secret-remediate.sh --commit <hash> --file <path>
```

El script genera los comandos `git-filter-repo` o BFG — **no los ejecuta**.
El humano revisa y ejecuta con coordinación del equipo.

## Gitleaks no instalado

El script detecta automáticamente si gitleaks está disponible y muestra
instrucciones de instalación + alternativa Docker:

```bash
docker run --rm -v "$(pwd):/path" zricethezav/gitleaks:latest detect --source /path
```

## Allowlist

Editar `.gitleaks.toml` en la raíz para excluir falsos positivos:
- Hashes SHA256 de firmas de confidencialidad Savia (`diff_hash=`, `signature=`)
- Fixtures de test
- Ejemplos en documentación
