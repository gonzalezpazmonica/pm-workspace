# Spec: Adopt Tolaria — Visual markdown knowledge base for Savia's Context As Code

**Task ID:**        SPEC-SE-090-TOLARIA
**PBI padre:**      Era 194 — Context Visualization
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (analisis Tolaria)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion agent:** ~45 min
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      20

---

## 1. Contexto y Objetivo

[Tolaria](https://github.com/refactoringhq/tolaria) (refactoringhq, 8.8k stars, AGPL-3.0)
es una app de escritorio (Tauri + React + TypeScript) para gestionar bases de
conocimiento en markdown. Principios alineados con Savia:

- **Files-first**: notas en markdown plano con YAML frontmatter → mismo formato que specs y reglas de Savia
- **Git-first**: cada vault es un repo git → pm-workspace es un repo git
- **Offline-first, zero lock-in**: sin cuentas, sin cloud → soberania total
- **Types as lenses**: categorias como ayuda a la navegacion, no schemas rigidos → mismo enfoque que SCM categories
- **AI-first but not AI-only**: soporta Claude Code, Codex CLI, Gemini CLI → compatible con OpenCode
- **Keyboard-first**: command palette, navegacion rapida → productividad
- **MCP server**: bridge para agentes AI → puente directo con Savia/OpenCode
- **Desktop app**: macOS, Windows, Linux via Tauri → disponible en el host

Savia genera Context As Code masivamente: reglas (25+), specs (~85), roadmap, skills
(92), comandos (535), agentes (70), hooks (65), CHANGELOG (9000+ lineas). Navegar
esto desde terminal es viable para Savia pero no para un humano. Tolaria proporciona
la capa visual sin alterar el formato de los archivos ni introducir lock-in.

**Objetivo:** Adoptar Tolaria como interfaz visual para el Context As Code de Savia.
Instalar, configurar, mapear tipos de contenido Savia ↔ tipos Tolaria, y documentar
el workflow para Mónica (y cualquier operador futuro).

---

## 2. Requisitos Funcionales

- **REQ-01** Instalar Tolaria en el host. Dos opciones:
  - Via AppImage/`.deb` desde [releases](https://refactoringhq.github.io/tolaria/download/)
  - Via `pnpm dev` si se prefiere compilar localmente
  - Preferencia: binario precompilado para Linux (`.deb` o AppImage)

- **REQ-02** Clonar o symlinkear Savia workspace como vault de Tolaria.
  `tolaria ~/claude` debe abrir el workspace directamente.
  - `.gitignore` de Savia ya excluye archivos temporales
  - `.tolaria/` directorio de config local (no commiteado)

- **REQ-03** Definir tipos de contenido (Tolaria "types") para las entidades de Savia:
  | Tipo Tolaria | Patron de archivo | Color | Icono |
  |-------------|-------------------|-------|-------|
  | `rule` | `docs/rules/**/*.md` | red | shield |
  | `spec` | `docs/specs/**/*.md` | blue | file-text |
  | `roadmap` | `docs/ROADMAP.md` | purple | map |
  | `skill` | `.opencode/skills/*/SKILL.md` | green | zap |
  | `command` | `.opencode/commands/*.md` | orange | terminal |
  | `agent` | `.opencode/agents/*.md` | indigo | bot |
  | `proposal` | `docs/propuestas/**/*.md` | yellow | lightbulb |
  | `changelog` | `CHANGELOG.md` | gray | clock |

- **REQ-04** Configurar MCP server de Tolaria para bridge con Savia/OpenCode.
  - El MCP server expone busqueda, lectura y escritura del vault via JSON-RPC
  - OpenCode puede usar el MCP server para busqueda semantica en specs y reglas
  - Alternativa: usar directamente los archivos (Savia ya los lee sin Tolaria)

- **REQ-05** Documentar workflow en `docs/tolaria-workflow.md`:
  - Como Mónica abre Tolaria y navega el workspace de Savia
  - Como crear/editar specs desde la GUI
  - Como usar la command palette para busqueda rapida
  - Como el MCP server conecta con Savia

- **REQ-06** Anadir comando Savia `/tolaria-open` para abrir vault especifico:
  ```bash
  # /tolaria-open [path] — abre Tolaria en el path especificado (default: ~/claude)
  tolaria ~/claude &
  ```

- **REQ-07** Compatibilidad total con el formato existente. Cero cambios en la
  estructura de archivos de Savia. Tolaria lee markdown + YAML frontmatter que
  ya usamos. No se requiere migracion de contenido.

---

## 3. No se modifica

Tolaria es una herramienta externa adoptada, no un componente de Savia.
No se modifica el codigo de Tolaria. Lo que se crea es:

1. Configuracion de tipos en `.tolaria/types.json` (o equivalente Tolaria)
2. Comando `/tolaria-open` wrapper
3. Documentacion de workflow
4. MCP bridge (opcional, puede ser futuro)

Ningun archivo markdown de Savia necesita cambiar. Los specs, reglas, roadmap
y comandos ya usan el formato que Tolaria espera (markdown + YAML frontmatter).

---

## 4. Criterios de Aceptacion

- **AC-01** Tolaria instalado en el host. `tolaria --version` funciona.
- **AC-02** `tolaria ~/claude` abre el workspace de Savia con todos los archivos visibles.
- **AC-03** Los tipos configurados muestran colores/iconos distintos para specs, rules, skills, etc.
- **AC-04** `/tolaria-open` abre Tolaria desde el CLI de Savia.
- **AC-05** `docs/tolaria-workflow.md` existe con instrucciones claras.
- **AC-06** Ningun archivo de Savia fue modificado por la adopcion de Tolaria.

---

## 5. Ficheros a Crear/Modificar

| Fichero | Accion |
|---------|--------|
| `.opencode/commands/tolaria-open.md` | CREAR — comando `/tolaria-open` |
| `.opencode/commands/tolaria-open.md` | CREAR — mirror para OpenCode |
| `docs/tolaria-workflow.md` | CREAR — guia de uso |
| `~/.tolaria/config.json` | CREAR — config de tipos (via script) |

---

## 6. Dependencias y Riesgos

- **Riesgo**: Tolaria requiere WebKit2GTK 4.1 en Linux. Verificar si esta instalado.
  **Mitigacion**: script de instalacion automatica de dependencias.
- **Riesgo**: Tolaria es un binario precompilado (AppImage). Puede no ejecutarse en
  todas las distros Linux. **Mitigacion**: compilar desde fuente si falla.
- **Depende de**: Nada. Es tooling externo, no modifica codigo Savia.
- **No bloquea**: ningun spec del pipeline. Se puede hacer en paralelo.

---

## 7. Impacto en Roadmap

Este spec agiliza la VISUALIZACION del Context As Code. No cambia como Savia opera
internamente, pero hace que Mónica (y cualquier operador humano) pueda navegar,
buscar y entender el creciente sistema de reglas, specs, roadmap y comandos sin
depender exclusivamente del terminal o del LLM.

Se coloca en slot 6 (entre vendor-refs y UA-Adopt) por ser rapido (~45 min) y de
alto impacto inmediato en la experiencia de uso humano de Savia.
