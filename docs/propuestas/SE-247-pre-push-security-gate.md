---
id: SE-247
title: "Pre-push security gate — Gitleaks como hook automático antes de cada push"
status: IMPLEMENTED
priority: P1
effort: S (6h — S1 2h + S2 2h + S3 2h)
origin: Análisis defensivo hackingtool-plugin (AKCodez, 2026-06-28)
author: Savia
related:
  - SE-239 (git-history-secret-scanning — historial completo, auditoría periódica)
  - block-credential-leak.sh (hook pre-write, tiempo de edición)
  - security-guardian agent
  - commit-guardian agent
proposed_at: "2026-06-28"
resolved_at: "2026-07-02"
implementation_pr: "#890"
era: 237
tools_from_hackingtool:
  - Gitleaks
---

# SE-247 — Pre-push security gate

## Problema

La cadena de hooks de seguridad de Savia tiene dos capas hoy:
1. `block-credential-leak.sh`: actúa en tiempo de edición (pre-write hook)
2. SE-239: escanea el historial git completo bajo demanda

Existe un gap en el medio: **el momento del push**. Un secret puede escapar si:
- Se edita directamente con un editor externo (bypassa pre-write hook)
- Se hace `git add` de un fichero con un secret que no pasó por el hook de escritura
- Se usa `--no-verify` en el commit (bypassa pre-commit hooks)
- El push incluye múltiples commits generados en otra rama donde el hook no estaba activo

El pre-push hook es la última línea de defensa antes de que el código llegue a GitHub.
No existe este hook en pm-workspace para ningún proyecto generado por Savia.

## Tesis

Un hook `pre-push` que ejecuta Gitleaks sobre los commits que van a subirse (el diff
entre el remote y el local), interceptando secrets de forma determinista antes de que
lleguen al repositorio remoto. Mínimo overhead: sólo escanea los commits nuevos, no
el historial completo. Instalable en cualquier proyecto generado por Savia via un script
de setup.

## Herramientas

| Herramienta | Qué hace | Modo de uso en Savia | Offline |
|---|---|---|---|
| Gitleaks | Escanea commits por secrets con ruleset TOML personalizable | `gitleaks protect --staged` (pre-commit) y `gitleaks protect` (pre-push sobre diff) | Sí (binario local, sin cloud) |

Gitleaks en modo `protect` analiza sólo el diff pendiente de push, no el historial
completo (eso es SE-239). Es rápido: < 1 segundo en diffs normales.

## Diseño

### Diferencia con hooks existentes

| Hook | Momento | Qué analiza | Herramienta |
|---|---|---|---|
| `block-credential-leak.sh` | Pre-write (edición) | Contenido nuevo del fichero | Regex custom |
| `commit-guardian` | Pre-commit | Staged diff | LLM + regex |
| **SE-247 (este)** | **Pre-push** | **Commits locales no pusheados** | **Gitleaks** |
| SE-239 | On-demand | Historial completo | Gitleaks + TruffleHog |

Las cuatro capas son complementarias. SE-247 no reemplaza ninguna.

### Hook `pre-push`

Fichero: `.git/hooks/pre-push` (o `.opencode/hooks/pre-push-security.sh` instalable)

Lógica del hook:
```
1. Leer stdin del hook (formato: <local_ref> <local_sha> <remote_ref> <remote_sha>)
2. Calcular el rango de commits nuevos: remote_sha..local_sha
3. gitleaks detect --log-opts="remote_sha..local_sha" --report-format json
4. Si findings: mostrar summary (tipo, archivo, commit hash truncado — NO el secret)
5. Preguntar: "Abort push? [Y/n]" (default: Y — conservador)
6. Exit 1 aborta el push; exit 0 permite continuar
```

El hook NO impide el push con `--no-verify` (esto es intencional — la regla existe,
el override es responsabilidad del humano y queda registrado en el audit log).

### Script de instalación: `scripts/security/install-pre-push-hook.sh`

- Parámetro: `--repo <path>` (instala en el repo especificado)
- Sin parámetro: instala en el repositorio actual (cwd)
- Verifica que Gitleaks está instalado; si no, instrucciones de instalación
- Hace backup del pre-push existente si hay uno
- Genera `.gitleaks.toml` base si no existe
- Idempotente: no sobreescribe si la versión ya es la correcta

### Instalación global via git template

Para proyectos nuevos generados por agentes, el script puede configurar
`git config --global core.hooksPath` apuntando a una carpeta con los hooks de Savia.
Esto instala el hook automáticamente en cualquier `git init` futuro.

### Configuración `.gitleaks.toml`

Ruleset base para proyectos Savia, incluyendo supresión de:
- Fixtures de test (paths `**/testdata/**`, `**/*.test.*`)
- Ejemplos de documentación (`docs/examples/`)
- Variables de entorno de ejemplo (`.env.example`)

El equipo puede añadir supresiones específicas del proyecto en `.gitleaks.toml`.

### Confidencialidad del output

El hook muestra al usuario:
- Tipo de secret detectado (ej: "AWS Access Key")
- Fichero y línea aproximada
- Commit hash (truncado a 8 chars)

**Nunca muestra el valor del secret en el output.**

### Integración con pm-workspace

El hook pre-push de pm-workspace se instala en pm-workspace propio durante el S3.
Los proyectos generados por agentes reciben el hook vía `install-pre-push-hook.sh`
como parte del proceso de setup del proyecto.

## Slices

**S1 — Hook pre-push + Gitleaks (2h)**
- `.opencode/hooks/pre-push-security.sh`
- Lógica de rango de commits nuevos
- Output: tipo + archivo + commit hash (sin valor del secret)
- BATS test: push con secret → exit 1; push limpio → exit 0

**S2 — Script de instalación + .gitleaks.toml base (2h)**
- `scripts/security/install-pre-push-hook.sh`
- Backup de pre-push existente
- `.gitleaks.toml` base para proyectos Savia
- Instrucciones de instalación offline de Gitleaks

**S3 — Instalación en pm-workspace + git template + comando (2h)**
- Instalar el hook en pm-workspace propio
- `git config --global core.hooksPath` opcional para proyectos futuros
- Comando `/install-security-hooks [repo_path]`
- Documentación de `--no-verify` bypass y sus implicaciones

## Criterios de aceptación

- [ ] Push con AWS key fixture → hook intercepta y muestra tipo + archivo (no el valor)
- [ ] Push sin secrets → hook permite el push sin interrupción
- [ ] `install-pre-push-hook.sh` instala el hook en un repo de prueba vacío
- [ ] `install-pre-push-hook.sh` hace backup del pre-push existente
- [ ] `.gitleaks.toml` suprime correctamente ficheros en `testdata/`
- [ ] El hook es < 1 segundo para un diff de 50 ficheros normales
- [ ] El hook funciona offline (sin conectividad)
- [ ] BATS tests cubren: push limpio, push con secret, push con secret suprimido en .gitleaks.toml
- [ ] `--no-verify` no es bloqueado (es bypass intencional; se documenta)

## Qué NO incluye

- Bloqueo de `git push --no-verify` — es bypass intencional del desarrollador
- Sustitución de `block-credential-leak.sh` ni de SE-239 — capas complementarias
- Escaneo del historial completo — eso es SE-239
- Análisis de contenido no-secret (código malicioso, licencias) — fuera de scope
- Integración con gestores de secrets (Vault, AWS Secrets Manager) para rotación automática
