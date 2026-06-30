---
id: SE-239
title: "Git history secret scanning — TruffleHog + Gitleaks sobre historial completo"
status: PROPOSED
priority: P1
effort: M (10h — S1 3h + S2 3h + S3 4h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - block-credential-leak.sh (hook existente, tiempo de escritura)
  - SE-247 (pre-push-security-gate)
  - nuclei-scanning skill
  - security-guardian agent
proposed_at: "2026-06-28"
era: 237
tools_from_hackingtool:
  - TruffleHog
  - Gitleaks
---

# SE-239 — Git history secret scanning

## Problema

`block-credential-leak.sh` intercepta secrets en tiempo de escritura (pre-commit, pre-write),
pero no analiza el historial git existente. Un repositorio puede acumular tokens, contraseñas,
claves API y certificados en commits de semanas o meses atrás que ningún hook ha inspeccionado.

Evidencia del gap:
- El hook sólo actúa sobre el diff staged actual, no sobre `git log --all`
- Los proyectos generados por agentes (dotnet-developer, python-developer, etc.) se inician desde
  cero pero los proyectos incorporados desde repos externos no tienen garantía de historial limpio
- No existe comando `/scan-history` ni script equivalente en scripts/
- El CI de pm-workspace no incluye ningún paso de secret scanning sobre el árbol completo

Sin este análisis, cualquier secret comprometido antes de implantar `block-credential-leak.sh`
sigue presente en el historial y es recuperable con `git log -p`.

## Tesis

Un script `scripts/security/scan-git-history.sh` que ejecuta TruffleHog y Gitleaks sobre el
historial completo de un repositorio target (no sólo el working tree), genera un report N3
consolidado, y puede invocarse manualmente o desde CI. No reemplaza el hook de escritura —
lo complementa cubriendo el eje temporal histórico.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| TruffleHog | Escanea commits buscando entropy alta + 700+ regexes de secrets | `trufflehog git file://$REPO_PATH --only-verified` | Sí (local) |
| Gitleaks | Escaneo rápido con TOML ruleset personalizable | `gitleaks detect --source $REPO_PATH --report-format json` | Sí (local) |

Ambas herramientas se ejecutan en modo lectura pura. Ninguna modifica el repositorio.
TruffleHog prioriza secrets verificados (activos); Gitleaks cubre mayor superficie de patrones.
Usar los dos reduce falsos negativos por complementariedad.

## Diseño

### Integración en pipeline Savia

```
Fase: Auditoría periódica + manual + CI on-demand
Trigger: /scan-git-history [repo_path] | CI scheduled weekly | pre-merge opcional
```

**Script principal**: `scripts/security/scan-git-history.sh`
- Parámetros: `--repo <path>` (obligatorio), `--depth <N>` (default: all), `--since <date>`
- Detecta si TruffleHog/Gitleaks están instalados; si no, instrucciones de instalación
- Ejecuta ambas herramientas secuencialmente
- Deduplica findings por (file, line, secret_type)
- Genera report en `output/security/git-history-scan-YYYYMMDD-{repo}.json` (N3)
- Exit code 1 si findings con severidad HIGH o CRITICAL
- Imprime resumen a stdout: X findings (C/H/M/L), sin mostrar el secret

**Configuración de supresiones**: `.gitleaks.toml` en la raíz del repo target permite
declarar falsos positivos conocidos (paths de test, fixtures). TruffleHog equivalente
via `--exclude-paths`.

**Umbrales conservadores** (zero false positives policy):
- Solo reportar cuando confidence ≥ 0.9 O entropy ≥ 4.5 con regex match
- Excluir por defecto: `*.test.*`, `fixtures/`, `testdata/`, `*.example`

### Integración con agentes existentes

- `security-guardian` puede invocar el script en su pipeline de auditoría
- `security-attacker` lo usa como primer paso de reconnaissance interna
- `commit-guardian` puede invocar con `--since HEAD~1` como sanity check rápido

### Confidencialidad

Los reports son N3: `output/security/` está git-ignorado. El script verifica que
el directorio de salida esté en `.gitignore` antes de escribir. Si no lo está, aborta
y pide confirmación explícita.

## Slices

**S1 — Script base con Gitleaks (3h)**
- `scripts/security/scan-git-history.sh` con Gitleaks únicamente
- Report JSON básico en `output/security/`
- Verificación de .gitignore antes de escribir
- Tests BATS: repo limpio → exit 0, repo con secret → exit 1

**S2 — Integración TruffleHog + deduplicación (3h)**
- Añadir TruffleHog al script
- Deduplicación de findings entre las dos herramientas
- Formato unificado del report
- Parámetros `--depth` y `--since`

**S3 — Integración CI + comando /scan-git-history (4h)**
- Workflow CI opcional (GitHub Actions) ejecutable manualmente (`workflow_dispatch`)
- Comando `/scan-git-history` en `.opencode/commands/`
- Documentación en `docs/rules/domain/`
- Ruleset `.gitleaks.toml` base para proyectos Savia

## Criterios de aceptación

- [ ] `scan-git-history.sh --repo <path>` termina con exit 0 en un repo limpio
- [ ] Detecta al menos un AWS key fixture conocido en repo de prueba
- [ ] Report generado en `output/security/` con naming YYYYMMDD
- [ ] El script aborta si `output/security/` no está en .gitignore (sin flag `--force`)
- [ ] Secrets no se imprimen a stdout (solo tipo + archivo + commit hash truncado)
- [ ] Los dos tools actúan en modo lectura: ningún archivo del repo es modificado
- [ ] BATS tests cubren: repo limpio, repo con secret, repo sin herramientas instaladas
- [ ] `--since 30d` limita el scan a los últimos 30 días
- [ ] Documentación incluye instrucciones de instalación offline (binarios pre-compilados)

## Qué NO incluye

- Remediación automática de secrets (reescritura de historial con `git-filter-repo`) — requiere
  decisión humana explícita
- Integración con servicios de rotación de credenciales (Vault, AWS Secrets Manager) — fuera de scope
- Análisis de secrets en artefactos binarios (JARs, wheels) — cubierto por SE-244
- Substitución del hook `block-credential-leak.sh` — son complementarios
