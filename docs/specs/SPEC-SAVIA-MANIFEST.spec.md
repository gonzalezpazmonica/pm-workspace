# Spec: Skill Registry Manifest — Manifest + lockfile para componentes de Savia

**Task ID:**        WORKSPACE
**PBI padre:**      Era próxima — Distribución modular de Savia
**Sprint:**         2026-29
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica

**Developer Type:** agent-team
**Asignado a:**     claude-agent-team
**Estimación:**     12h (3 slices × 4h)
**Estado:**         Pendiente

**Depende de:**     Rule #26 Language Boundaries
**Inspirado por:**  Microsoft APM (Agent Package Manager), Genesis (danielmeppiel/genesis), npm/Cargo manifest+lockfile pattern. Concepto adoptado, código no.

**Contexto de ejecución:** Savia opera dentro de OpenCode. Los comandos slash (`/savia-init`, `/savia-install`, `/savia-sync`, `/savia-lock`, `/savia-verify`) son ficheros markdown en `.opencode/commands/` interpretados como prompts. Cada uno instruye al modelo para invocar la tool Bash, que ejecuta wrappers en `scripts/`, que llaman a Python. El indexado canónico que respeta el manifest es leído por OpenCode para decidir qué componentes cargar.

**Decisión arquitectónica registrada:**
- (D-1) Manifest específico de Savia, NO compatible binaria con APM. La compatibilidad llega vía exporter opcional (Slice 4, fuera de alcance).
- (D-2) El manifest es OPCIONAL. Sin manifest, Savia carga todo como hoy. Esto preserva la experiencia actual.
- (D-3) El lockfile incluye hashes SHA-256 de cada componente para reproducibilidad determinista.
- (D-4) Los packs distribuidos respetan la confidencialidad declarada en los componentes. Un componente N3 no puede empaquetarse en un pack público.
- (D-5) El instalador opera sobre un workspace existente. NO genera workspaces desde cero. El bootstrap inicial sigue siendo `install.sh`.
- (D-6) Toda la lógica de manifest, lockfile, packs, validación, hashes, resolución de versiones se implementa en Python. Bash solo orquesta invocaciones desde la tool Bash de OpenCode. Conforme a Rule #26.
- (D-7) **El módulo `savia_manifest` se expone también como MCP server** (`savia-manifest`). Tools: instalar pack, verificar lockfile, listar componentes activos, validar manifest. Cualquier frontend compatible con MCP gestiona la configuración Savia sin pasar por OpenCode.
- (D-8) El módulo Python está diseñado como paquete empaquetable con `setuptools` o `hatch`, sentando las bases de un futuro `savia-cli` unificado.

---

## 1. Contexto y Objetivo

### 1.1 Problema

pm-workspace acumula 544 comandos, 70 agentes, 96 skills, 68 hooks. La cifra crece cada semana. Tres consecuencias operativas:

1. **Adopción todo-o-nada.** Una consultora que quiere usar 20 comandos para un cliente concreto hereda los otros 524. No hay forma documentada de instalar solo lo necesario.
2. **Imposibilidad de distribución modular.** Un "pack healthcare" o "pack industrial" tendría que vivir en un fork, perdiendo actualizaciones. No hay canal para publicar packs sin fragmentar.
3. **Sin reproducibilidad cross-machine.** El equipo A clona hoy, el equipo B mañana. Si entre medias se actualizó algún componente, ambos equipos operan con configuraciones distintas sin saberlo.

Microsoft APM, Genesis y npm/Cargo resolvieron este problema en sus dominios con manifest + lockfile. La industria de agentes IA está adoptando el patrón. Savia necesita su versión, alineada con sus principios fundacionales.

### 1.2 Objetivo

Introducir tres ficheros y cinco comandos slash que permiten instalación selectiva, distribución de packs y reproducibilidad determinista:

1. **`savia.manifest.yaml`** — declaración de qué componentes están activos.
2. **`savia.lock`** — snapshot determinista del estado actual.
3. **`savia.packs/` (opcional)** — directorio de packs publicables.
4. **Cinco comandos slash** que orquestan el ciclo de vida.

### 1.3 No-Goals

- ❌ NO se crea un registry centralizado tipo npm. Distribución vía git + URL.
- ❌ NO se gestiona resolución transitiva compleja en este slice.
- ❌ NO se mueve nada de `.opencode/` ni `.claude/`. El manifest es una capa de declaración por encima.
- ❌ NO se cubre desinstalación quirúrgica.
- ❌ NO se reemplaza `install.sh`.
- ❌ NO se construye o parsea YAML/JSON con jq/yq en bash.

---

## 2. Requisitos Funcionales

### 2.1 Estructura del manifest

```yaml
# savia.manifest.yaml (root del workspace)
manifest_version: 1
workspace_id: pm-workspace-mgp
description: Configuración personal de Mónica.

components:
  agents:
    enabled: all
    exclude: []
  commands:
    enabled: listed
    list:
      - sprint-status
      - pr-review
      - flow-run
  skills:
    enabled: all
  hooks:
    enabled: all

packs:
  - name: savia-core
    source: builtin
    version: ">=4.0.0"
  - name: pack-healthcare
    source: github:gonzalezpazmonica/savia-pack-healthcare
    version: "1.2.0"
    confidentiality_max: N2
```

### 2.2 Estructura del lockfile

```yaml
# savia.lock (autogenerado, NO se edita a mano)
lock_version: 1
generated_at: "2026-05-09T14:30:00Z"
generated_by: savia-manifest@0.1.0

components:
  - id: command:sprint-status
    version: 4.92.0
    sha256: "a1b2c3..."
    source: builtin
  - id: agent:code-judge-correctness
    version: 4.92.0
    sha256: "d4e5f6..."
    source: builtin

packs:
  - name: pack-healthcare
    version: 1.2.0
    sha256: "9f8e7d..."
    resolved_from: "https://github.com/gonzalezpazmonica/savia-pack-healthcare#v1.2.0"
```

Generación determinista: mismo workspace → mismo `sha256` global. Implementación en Python con orden canónico de claves y `hashlib`.

### 2.3 Estructura de un pack publicable

```
savia-pack-healthcare/
├── pack.yaml
├── agents/
├── commands/
├── skills/
├── hooks/
└── README.md
```

```yaml
# pack.yaml
pack_version: 1
name: pack-healthcare
version: 1.2.0
description: Componentes específicos del dominio sanitario.
license: MIT
confidentiality_declared: N2
requires_savia: ">=4.0.0"
components:
  agents: [hipaa-auditor, fhir-validator]
  commands: [hipaa-scan, fhir-export]
  skills: [hipaa-rules, fhir-r5]
```

### 2.4 Arquitectura de la herramienta

Conforme a Rule #26 y al contexto OpenCode:

**Comandos slash — `.opencode/commands/savia-*.md`** (markdown, no código):
- Cinco ficheros, uno por comando.
- Cada uno describe al modelo cómo invocar el wrapper bash correspondiente.

**Wrappers bash** (≤ 25 líneas cada uno):
- `scripts/savia-init.sh` → invoca `python3 -m savia_manifest.cli init`.
- `scripts/savia-install.sh` → orquesta `git clone` del pack + invoca Python para validar e instalar.
- `scripts/savia-sync.sh` → invoca `python3 -m savia_manifest.cli sync`.
- `scripts/savia-lock.sh` → invoca `python3 -m savia_manifest.cli lock`.
- `scripts/savia-verify.sh` → invoca `python3 -m savia_manifest.cli verify`.

**Módulo Python — `scripts/lib/savia_manifest/`:**
- `__init__.py`
- `cli.py` — punto de entrada con argparse, despacha a sub-módulos.
- `manifest.py` — carga, validación contra schema, normalización.
- `lockfile.py` — generación determinista, comparación, detección de drift.
- `pack.py` — validación de pack, cálculo de hash, verificación de confidencialidad.
- `version.py` — comparación semver con `packaging.version`.
- `installer.py` — aplica manifest al workspace (activa/desactiva en índice canónico).
- `resolver.py` — resuelve referencias `github:user/repo#tag` a URLs concretas.
- `mcp_server.py` — expone tools como MCP server.
- `requirements.txt` — `pyyaml`, `jsonschema`, `packaging`, MCP SDK.

**MCP server — `savia-manifest`:**
- Tools: `install_pack(spec)`, `verify_lockfile()`, `list_components(filter)`, `validate_manifest()`, `regenerate_lock()`.
- Cualquier frontend MCP-compatible gestiona la configuración Savia.

### 2.5 Comandos slash

| Comando | Acción |
|---|---|
| `/savia-init` | Genera `savia.manifest.yaml` por defecto |
| `/savia-install {pack-spec}` | Añade pack al manifest, descarga, valida hash |
| `/savia-sync` | Aplica manifest al workspace |
| `/savia-lock` | Regenera `savia.lock` |
| `/savia-verify` | Verifica que workspace coincide con lock (CI gate) |

### 2.6 Modelo de activación

- **Activado** → componente disponible para los agentes.
- **Desactivado** → componente presente en disco pero ignorado.

La desactivación no borra ficheros: marca el componente como excluido en el índice canónico (`.context-index/WORKSPACE.ctx`). OpenCode lee el índice y respeta la activación.

### 2.7 Validación obligatoria

`/savia-install` rechaza un pack si:
- No tiene `pack.yaml` válido contra schema (validación con `jsonschema` en Python).
- Declara componentes con confidencialidad superior a la permitida.
- Su hash no coincide con el publicado.
- Su `requires_savia` no se satisface (comparación con `packaging.version`).

### 2.8 Gate de CI

`/savia-verify` retorna código no-cero si el workspace difiere del lockfile. Integrable en pre-commit y CI.

---

## 3. No se modifica

- Estructura de `.opencode/` y `.claude/`. El manifest es capa de declaración por encima.
- Mecanismo de carga de agentes/skills por OpenCode. La activación se materializa en el índice canónico que OpenCode ya lee.
- Sistema de confidencialidad N1-N4b.
- `install.sh` y bootstrap inicial.

---

## 4. Criterios de Aceptación

**Slice 1 — Schema y validador:**
- [ ] Módulo `savia_manifest` con `manifest.py`, `version.py`, schemas JSON.
- [ ] Schemas `manifest.schema.json` y `lock.schema.json`.
- [ ] `/savia-init` genera manifest por defecto.
- [ ] `/savia-verify` detecta drift entre manifest y workspace.
- [ ] Tests pytest: 20 casos.
- [ ] Tests bats: 3 casos cubriendo wrappers.

**Slice 2 — Instalación de packs:**
- [ ] `installer.py`, `pack.py`, `resolver.py` implementados.
- [ ] `/savia-install github:user/repo#v1.0.0` funciona end-to-end.
- [ ] Pack publicable `savia-pack-example` como referencia.
- [ ] Hash SHA-256 verificado antes de aplicar.
- [ ] Componentes accesibles tras `savia-sync`.
- [ ] Tests pytest: 15 casos.

**Slice 3 — Lockfile, MCP y reproducibilidad:**
- [ ] `lockfile.py` produce lockfile determinista.
- [ ] Tras clonar el repo en otra máquina, `savia-sync` reproduce el estado exacto.
- [ ] MCP server `savia-manifest` funcional, registrable en frontends compatibles.
- [ ] CI workflow `verify-lock.yml` que valida lockfile en cada PR.
- [ ] Documentación: `docs/savia-manifest.md`.
- [ ] Tests pytest: 10 casos sobre determinismo y MCP.

---

## 5. Ficheros a Crear/Modificar

**Crear (Python — lógica):**
- `scripts/lib/savia_manifest/__init__.py`
- `scripts/lib/savia_manifest/cli.py`
- `scripts/lib/savia_manifest/manifest.py`
- `scripts/lib/savia_manifest/lockfile.py`
- `scripts/lib/savia_manifest/pack.py`
- `scripts/lib/savia_manifest/version.py`
- `scripts/lib/savia_manifest/installer.py`
- `scripts/lib/savia_manifest/resolver.py`
- `scripts/lib/savia_manifest/mcp_server.py`
- `scripts/lib/savia_manifest/requirements.txt`
- `tests/python/test_manifest.py`
- `tests/python/test_lockfile.py`
- `tests/python/test_pack.py`
- `tests/python/test_version.py`
- `tests/python/test_installer.py`
- `tests/python/test_mcp_server.py`
- `tests/python/fixtures/manifests/`
- `tests/python/fixtures/packs/`

**Crear (Bash — envoltorios):**
- `scripts/savia-init.sh` (≤ 25 líneas)
- `scripts/savia-install.sh`
- `scripts/savia-sync.sh`
- `scripts/savia-lock.sh`
- `scripts/savia-verify.sh`
- `tests/savia-wrappers.bats`

**Crear (markdown OpenCode — prompts):**
- `.opencode/commands/savia-init.md`
- `.opencode/commands/savia-install.md`
- `.opencode/commands/savia-sync.md`
- `.opencode/commands/savia-lock.md`
- `.opencode/commands/savia-verify.md`

**Crear (datos y docs):**
- `schemas/manifest.schema.json`
- `schemas/lock.schema.json`
- `schemas/pack.schema.json`
- `docs/savia-manifest.md`
- `.github/workflows/verify-lock.yml`
- `examples/savia-pack-example/`

**Modificar:**
- `.context-index/WORKSPACE.ctx`: respetar manifest al exponer componentes.
- `README.md`: sección "Distribución modular".
- `CHANGELOG.md`.

---

## 6. Dependencias y Riesgos

**Dependencias:** Python ≥ 3.10, `pyyaml`, `jsonschema`, `packaging`, MCP SDK Python. Ya presentes o estándar.

**Riesgos:**

| Riesgo | Mitigación |
|---|---|
| **Contradicción con principio "monorepo simple".** Introducir packs fragmenta el ecosistema. | Manifest opcional. Sin manifest, comportamiento idéntico al actual. La fragmentación es elección consciente. |
| **Packs maliciosos.** Un pack distribuido vía git puede contener hooks dañinos. | Validación obligatoria de hash. Recomendación de revisar antes de instalar. Slice futuro opcional: `--require-signed` con firma GPG. |
| **Fuga de confidencialidad vía pack público.** Un pack incluye accidentalmente un componente N3. | `confidentiality_max` en manifest del consumidor + `confidentiality_declared` en pack. Doble guard. Pre-publish hook escanea el pack contra los frontmatter. |
| **Drift silencioso.** El lockfile queda obsoleto. | `/savia-verify` en pre-commit y CI. Aviso explícito si manifest cambió pero lock no. |
| **Resolución transitiva compleja.** Un pack depende de otro pack que depende de otro. | Slice actual: solo dependencias planas. YAGNI por ahora. |
| **Sobrecoste de mantenimiento.** Cada nueva skill/agente exige actualizar manifest. | Auto-update opcional: `/savia-lock --auto-include-new` añade componentes nuevos al manifest tras release. |
| **El módulo `savia_manifest` es la base de un futuro `savia-cli`.** Si se diseña mal, condicionará la CLI. | Diseño modular desde el inicio con módulos disjuntos. Cada módulo testeable independientemente. Estructura del paquete pensada para empaquetarse con `setuptools` o `hatch`. |

---

## 7. Impacto en Roadmap

- **Habilita Savia Enterprise.** El despliegue organizacional declarado en propuesta requiere instalación selectiva por equipo.
- **Habilita marketplace orgánico.** Cualquier consultor o equipo puede publicar su pack vía git público o privado. No hay registry que mantener.
- **Reduce superficie de ataque.** Una organización que solo necesita 50 comandos no expone los otros 494.
- **MCP server reutilizable.** El gestor de manifest está disponible para cualquier frontend MCP-compatible, no solo OpenCode.
- **Compatibilidad futura con APM.** Slice 4 opcional: exporter `savia-to-apm` que genera `apm.yml` desde `savia.manifest.yaml`.
- **Base de `savia-cli` futuro.** El módulo Python queda diseñado para ser el corazón de una CLI unificada.
