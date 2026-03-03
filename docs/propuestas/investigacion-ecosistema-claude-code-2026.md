# Investigación: Ecosistema Claude Code — Mejoras para pm-workspace y Savia

**Fecha:** 2026-03-03
**Alcance:** GitHub, foros, documentación Anthropic, blogs especializados
**Repositorios analizados:** 12 (excluyendo claude-code-templates y claude-code-best-practice ya investigados en Eras 19-20)

---

## Repositorios investigados

| # | Repositorio | Estrellas | Foco principal |
|---|---|---|---|
| 1 | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | — | Agent harness: instincts, security, performance |
| 2 | [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | — | Índice curado: 75+ repos, skills, hooks, plugins |
| 3 | [trailofbits/claude-code-config](https://github.com/trailofbits/claude-code-config) | — | Seguridad: defaults opinados, sandbox, deny rules |
| 4 | [ChrisWiles/claude-code-showcase](https://github.com/ChrisWiles/claude-code-showcase) | — | Showcase: skill-eval engine, GitHub Actions, hooks |
| 5 | [nwiizo/ccswarm](https://github.com/nwiizo/ccswarm) | — | Multi-agente con git worktree isolation |
| 6 | [Yeachan-Heo/oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | — | Teams-first orchestration, staged pipeline |
| 7 | [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) | — | 127+ subagentes categorizados por dominio |
| 8 | [ruvnet/ruflo](https://github.com/ruvnet/ruflo) | — | Swarm orchestration, RAG, 175+ MCP tools |
| 9 | [bobmatnyc/claude-mpm](https://github.com/bobmatnyc/claude-mpm) | — | Multi-Agent PM: 47+ agentes especializados |
| 10 | [wshobson/agents](https://github.com/wshobson/agents) | — | 112 agentes, 16 orchestrators, 146 skills |
| 11 | [jarrodwatts/claude-code-config](https://github.com/jarrodwatts/claude-code-config) | — | Config personal: rules, hooks, agents, skills |
| 12 | [catlog22/Claude-Code-Workflow](https://github.com/catlog22/Claude-Code-Workflow) | — | JSON-driven multi-agent cadence-team framework |

**Fuentes adicionales:** Anthropic docs (code.claude.com), blog sshh.io, claudefa.st, dev.to, platform.claude.com/cookbook

---

## Hallazgos clave por categoría

### 1. Sistema de Instintos — Aprendizaje continuo (everything-claude-code)

**Qué es:** Sistema de extracción automática de patrones con puntuación de confianza (0-100). Los "instintos" son comportamientos aprendidos del historial de git y sesiones previas.

**Comandos:** `/learn` (extracción manual), `/instinct-status` (ver instintos activos), `/evolve` (promover instinto a skill permanente).

**¿Lo tenemos?** NO. Nuestros 22 skills son estáticos y manuales.

**Propuesta:** Implementar ciclo learn → evaluate → evolve para convertir patrones repetitivos de nuestros 288 comandos en skills auto-generados.

**Impacto:** Alto — transforma pm-workspace de herramienta estática a sistema que aprende.

---

### 2. Seguridad adversarial — AgentShield (everything-claude-code + trail-of-bits)

**everything-claude-code:** Pipeline de 3 agentes adversariales:
- **Attacker Agent** — identifica vulnerabilidades explotables
- **Defender Agent** — propone mitigaciones concretas
- **Auditor Agent** — verifica parches, asigna grado de seguridad (A-F, 0-100)
- 102 reglas de seguridad en 5 categorías (secrets, permissions, hooks, MCPs, agent configs)
- Cobertura OWASP Agentic Top 10

**trail-of-bits (empresa de seguridad líder):** Modelo de defensa en 3 capas:
- **Capa 1:** Sandbox OS (Seatbelt macOS / bubblewrap Linux)
- **Capa 2:** Deny rules en settings.json (bloqueo de ~/.ssh, ~/.aws, ~/.kube, ~/.gnupg, etc.)
- **Capa 3:** Aislamiento completo (devcontainers/droplets efímeros)
- Filosofía: "Los hooks son barandillas, no muros. Prompt injection puede vencerlos."

**¿Lo tenemos?** PARCIAL. Tenemos SAST/SBOM/Gitleaks + `/security-review` OWASP, pero no pipeline adversarial ni deny rules de filesystem.

**Propuesta:**
- Adoptar deny rules de Trail of Bits para proteger credenciales del sistema
- Implementar pipeline Attacker/Defender/Auditor para auditorías de nuestros 24 agentes
- Detectar zero-width Unicode y memory poisoning en configuraciones

**Impacto:** Alto — cierra vector de ataque que no cubrimos (exfiltración de credenciales via agentes).

---

### 3. Anti-racionalización — Stop Hook (trail-of-bits)

**Qué es:** Hook en evento `Stop` que ejecuta evaluación con modelo rápido (Haiku) para detectar trabajo incompleto antes de cerrar sesión. Detecta frases como "estos son errores preexistentes", "fuera de alcance", "demasiados para arreglar".

**Implementación:** Prompt hook → Haiku evalúa → JSON raw (sin markdown) → bloquea si detecta racionalización.

**¿Lo tenemos?** PARCIAL. Tenemos `stop-quality-gate.sh` pero solo detecta secrets en staged changes, NO racionalización de trabajo incompleto.

**Propuesta:** Extender `stop-quality-gate.sh` con evaluación Haiku para detectar racionalización además de secrets.

**Impacto:** Medio — mejora calidad de entrega sin intervención humana.

---

### 4. Skill Evaluation Engine — Activación inteligente (claude-code-showcase)

**Qué es:** Motor de evaluación Node.js que puntúa skills contra 7 criterios (keywords, patrones regex, paths, directorios, intención, contenido, contexto). Activa automáticamente los skills relevantes por prompt.

**Características:**
- Puntuación multi-dimensional (keyword: 2pts, directory match: 5pts, intent: 4pts)
- Mapeo directorio→skill (src/graphql/ → graphql-schema skill)
- Límite de 5 skills máximo por activación
- Grafo de skills relacionados (graphql-schema → react-ui-patterns)

**¿Lo tenemos?** NO. Nuestros skills se activan manualmente o por convención.

**Propuesta:** Implementar motor de evaluación para nuestros 22 skills que sugiera activaciones automáticas basadas en el prompt y los archivos involucrados.

**Impacto:** Alto — reduce fricción y garantiza que se usen los skills correctos.

---

### 5. GitHub Actions automatizados — Quality sweeps (claude-code-showcase)

**Patrones descubiertos:**
- **Sweep semanal de calidad:** Domingo 8AM, muestrea 3 directorios, Claude ARREGLA (no reporta), crea PRs
- **Sync mensual de docs:** 1º de cada mes, detecta código cambiado vs docs desactualizadas
- **Auditoría quincenal de dependencias:** 1 y 15 de cada mes, npm audit + npm outdated, conservador
- **Review de PR con @claude:** Mención en comentario de PR invoca revisión ad-hoc

**¿Lo tenemos?** PARCIAL. Tenemos PR Guardian (8 gates) pero no sweeps programados ni sync de docs.

**Propuesta:**
- Añadir GitHub Action de quality sweep semanal para nuestros 288 comandos
- Añadir sync de documentación mensual (README español/inglés, CHANGELOG)
- Permitir @savia en PRs para invocar revisión contextual

**Impacto:** Medio — automatiza tareas de mantenimiento que ahora hacemos manualmente.

---

### 6. Optimización granular de tokens (everything-claude-code + Anthropic docs)

**Patrones descubiertos:**
- **Jerarquía de modelos:** Haiku para exploración → Sonnet para coding → Opus para seguridad
- **Thinking cap a 10K tokens** (reducción ~70% vs default 31,999)
- **Auto-compact a 50%** (no esperar al 95% de emergencia)
- **Compactación en breakpoints lógicos** (tras exploración, debugging, no en emergencia)
- **MCP < 10 activos** por proyecto, < 80 tools totales
- **Métricas pass@k / pass^k** para calidad de agentes

**¿Lo tenemos?** PARCIAL. Tenemos `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50` y modelo por comando (v0.94.0) pero no thinking cap ni métricas pass@k.

**Propuesta:**
- Implementar thinking_budget en frontmatter de comandos pesados
- Definir pass@k para los 24 agentes (medir tasa de éxito)
- Statusline con contexto usado, coste de sesión y cache hit rate (patrón Trail of Bits)

**Impacto:** Medio — optimización de costes y rendimiento medible.

---

### 7. Orquestación multi-agente avanzada (ccswarm + oh-my-claudecode)

**ccswarm:** Aislamiento por git worktree con message passing asíncrono. Cada agente trabaja en su propio worktree sin conflictos de archivos. Colas de prioridad (High/Medium/Low).

**oh-my-claudecode:** Pipeline staged: plan → prd → exec → verify → fix (loop). Routing automático por complejidad. 32 agentes especializados.

**¿Lo tenemos?** PARCIAL. Tenemos Agent Teams con worktree isolation y SDD pipeline, pero no colas de prioridad ni verify/fix loops.

**Propuesta:**
- Añadir colas de prioridad para ceremonias Scrum (blocker > daily > backlog refinement)
- Implementar verify/fix loop post-ceremonia (retrospectiva → action items → verificación en siguiente sprint)
- Event broker para notificaciones entre agentes (sprint-started, blocker-detected)

**Impacto:** Medio — mejora coordinación en equipos con múltiples ceremonias paralelas.

---

### 8. Audit trail de mutaciones (trail-of-bits)

**Qué es:** PostToolUse hook que registra cada comando Bash ejecutado con timestamp en log inmutable. Clasifica operaciones como read vs write usando patrones de verbos.

**¿Lo tenemos?** PARCIAL. Tenemos `/ai-audit-log` para generar reportes de trazas existentes (compliance EU AI Act), pero no un hook automático que registre cada mutación en tiempo real.

**Propuesta:** Hook PostToolUse que registre todas las operaciones write (git, az devops, file edits) en `.claude/audit.log` con timestamp. Complementa el comando `/ai-audit-log` existente.

**Impacto:** Bajo-Medio — útil para compliance y retrospectivas de sesión.

---

### 9. Herramientas de ecosistema destacadas (awesome-claude-code)

**Innovaciones relevantes para pm-workspace:**
- **RIPER Workflow** — Research, Innovate, Plan, Execute, Review (variante de nuestro RPI)
- **HCOM (Hook Comms)** — Comunicación real-time entre agentes vía hooks
- **ClaudeCTX** — Switch completo de configuración con un comando (útil para perfiles de cliente)
- **parry** — Scanner de prompt injection para hooks (detecta ataques y exfiltración)
- **TSK** — Task manager Rust que delega a agentes sandboxed en Docker
- **VoiceMode MCP** — Voice-to-command (alineado con nuestro backlog de voice integration)

---

### 10. Formato AGENTS.md universal (everything-claude-code)

**Qué es:** Formato estándar para definir agentes que funciona cross-platform (Claude Code, Cursor, Codex, OpenCode). Single source of truth para despliegue multi-IDE.

**¿Lo tenemos?** NO. Nuestros agentes están en formato propietario.

**Propuesta:** Evaluar adopción de AGENTS.md para futuras integraciones con Codex/OpenCode.

**Impacto:** Bajo ahora, alto a futuro si pm-workspace se expande a otros entornos.

---

## Matriz de priorización — Propuestas para Era 21

| # | Propuesta | Fuente | Prioridad | Esfuerzo | Impacto |
|---|---|---|---|---|---|
| 1 | **Sistema de Instintos** (learn/evolve) | everything-claude-code | P0 | Alto | Alto |
| 2 | **Pipeline adversarial de seguridad** | everything-claude-code + trail-of-bits | P0 | Alto | Alto |
| 3 | **Skill Evaluation Engine** | claude-code-showcase | P1 | Medio | Alto |
| 4 | **Stop Hook anti-racionalización** | trail-of-bits | P1 | Bajo | Medio |
| 5 | **Quality sweeps programados** | claude-code-showcase | P1 | Medio | Medio |
| 6 | **Deny rules de filesystem** | trail-of-bits | P1 | Bajo | Alto |
| 7 | **Métricas pass@k para agentes** | everything-claude-code | P2 | Medio | Medio |
| 8 | **Verify/fix loops post-ceremonia** | oh-my-claudecode | P2 | Medio | Medio |
| 9 | **Audit trail de mutaciones** | trail-of-bits | P2 | Bajo | Bajo-Medio |
| 10 | **AGENTS.md universal** | everything-claude-code | P3 | Bajo | Bajo (futuro alto) |
| 11 | **VoiceMode MCP** | awesome-claude-code | P3 | Medio | Medio |
| 12 | **Event broker inter-agentes** | ccswarm | P3 | Alto | Medio |

---

## Propuesta de Era 21 — Self-Learning & Adversarial Security

Basada en esta investigación, la Era 21 podría estructurarse así:

### v0.99.0 — Deny Rules & Stop Hook
- Deny rules de filesystem (Trail of Bits pattern) en settings.json
- Stop Hook anti-racionalización con evaluación Haiku
- Audit trail de mutaciones (PostToolUse → `.claude/audit.log`)

### v0.100.0 — Skill Evaluation Engine
- Motor Node.js de puntuación multi-dimensional para 22 skills
- Mapeo directorio→skill automático
- Integración con UserPromptSubmit hook

### v0.101.0 — Adversarial Security Pipeline
- 3 agentes: attacker, defender, auditor
- Grading A-F para seguridad de agentes y hooks
- Cobertura OWASP Agentic Top 10 extendida
- Zero-width Unicode detection

### v0.102.0 — Instincts System Foundation
- `/learn` — extracción de patrones desde historial git
- `/instinct-status` — instintos activos con confianza
- Checkpoint evaluation con métricas pass@k

### v0.103.0 — Adaptive Learning & Quality Sweeps
- `/evolve` — promover instintos a skills permanentes
- GitHub Action: quality sweep semanal de comandos
- GitHub Action: sync mensual de documentación
- @savia mention en PRs para revisión contextual

### v0.104.0 — Ceremony Orchestration 2.0
- Verify/fix loops para ceremonias Scrum
- Colas de prioridad para eventos simultáneos
- Event broker básico inter-agentes

---

## Reconocimientos

Esta investigación se benefició del trabajo de:
- [Affaan M](https://github.com/affaan-m) — everything-claude-code (instincts, AgentShield)
- [Trail of Bits](https://github.com/trailofbits) — claude-code-config (sandbox, deny rules, anti-rationalization)
- [Chris Wiles](https://github.com/ChrisWiles) — claude-code-showcase (skill-eval engine, GitHub Actions)
- [hesreallyhim](https://github.com/hesreallyhim) — awesome-claude-code (índice curado)
- [nwiizo](https://github.com/nwiizo) — ccswarm (worktree isolation)
- [Yeachan Heo](https://github.com/Yeachan-Heo) — oh-my-claudecode (staged pipelines)
- [VoltAgent](https://github.com/VoltAgent) — awesome-claude-code-subagents (taxonomía)
