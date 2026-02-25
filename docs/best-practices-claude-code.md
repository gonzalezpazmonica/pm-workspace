# Buenas Prácticas de Claude Code
# ── Referencia Extendida ──────────────────────────────────────────────────────

> Fuentes:
> - https://code.claude.com/docs/en/best-practices (oficial Anthropic)
> - https://github.com/shanraisshan/claude-code-best-practice (comunidad)
> Incorporadas y adaptadas para proyectos .NET el 2026-02-25.

---

## 1. LA RESTRICCIÓN FUNDAMENTAL: LA VENTANA DE CONTEXTO

El contexto es el recurso más crítico de Claude Code. Se llena rápido y el
rendimiento **degrada** conforme se acerca al límite. Un solo ciclo de debugging
puede consumir decenas de miles de tokens.

**Gestión activa obligatoria:**
- Monitorizar uso continuo con `/statusline` (configurar para mostrar % de contexto)
- `/compact` manualmente al llegar al **50% de capacidad**
- `/clear` entre tareas no relacionadas para resetear completamente
- Subagentes para investigaciones largas (no consumen el contexto principal)
- Si Claude empieza a ignorar instrucciones o comete más errores: el contexto está lleno

---

## 2. DAR A CLAUDE FORMA DE VERIFICAR SU TRABAJO

El cambio de mayor impacto posible. Claude rinde dramáticamente mejor cuando
puede verificar su trabajo de forma autónoma.

### En proyectos .NET
```bash
# Incluir SIEMPRE en los prompts de implementación:
dotnet build --configuration Release              # ¿Compila?
dotnet test --filter "Category=Unit"              # ¿Pasan los tests?
dotnet format --verify-no-changes                 # ¿Respeta el estilo?
dotnet list package --outdated                    # ¿Dependencias actualizadas?
```

### Patrones de verificación

| Estrategia | Sin verificación | Con verificación |
|---|---|---|
| **Tests** | *"implementa validación de email"* | *"implementa ValidateEmail. Casos: user@domain.com=true, invalid=false. Crea tests xUnit y ejecútalos"* |
| **Build** | *"el build falla"* | *"el build falla con este error: [pegar error]. Corrígelo y verifica con `dotnet build`. Ataca la raíz, no suprimas el error"* |
| **UI** | *"mejora el dashboard"* | *"[pegar screenshot] implementa este diseño. Haz screenshot del resultado y compara. Lista diferencias y corrígelas"* |
| **Regresión** | *"refactoriza este método"* | *"refactoriza `CalculateCapacity()`. Los tests existentes deben seguir pasando: `dotnet test --filter FullyQualifiedName~CapacityTests`"* |

**Regla de oro:** Si no puedes verificarlo, no lo envíes.

---

## 3. FLUJO DE TRABAJO: EXPLORAR → PLANIFICAR → IMPLEMENTAR → COMMIT

Separar la investigación de la ejecución evita resolver el problema equivocado.

```
Fase 1 — EXPLORAR (Plan Mode activado con /plan)
  Claude lee ficheros y responde preguntas SIN hacer cambios.
  Ejemplo: "Lee /src/Services y entiende cómo gestionamos las sesiones de usuario"

Fase 2 — PLANIFICAR (sigue en Plan Mode)
  Claude crea un plan de implementación detallado.
  Ctrl+G → abre el plan en el editor para editarlo antes de proceder.
  Ejemplo: "Quiero añadir autenticación OAuth. ¿Qué ficheros cambian? Crea un plan."

Fase 3 — IMPLEMENTAR (volver a Normal Mode)
  Claude codifica verificando contra su propio plan.
  Ejemplo: "Implementa el flujo OAuth del plan. Escribe tests para el callback,
           ejecuta la suite y corrige los fallos. Verifica con `dotnet build`."

Fase 4 — COMMIT
  Claude hace commit con mensaje descriptivo y abre PR.
  Ejemplo: "Commit con mensaje descriptivo y abre PR"
```

**Cuándo saltarse la planificación:**
Si puedes describir el diff en una sola frase, ve directamente a implementar.
La planificación añade overhead — úsala cuando la tarea toca múltiples ficheros
o cuando no estás seguro del enfoque.

---

## 4. PROMPTS PRECISOS Y RICOS EN CONTEXTO

### Patrones de prompting

| Estrategia | Vago | Preciso |
|---|---|---|
| **Delimitar el alcance** | *"añade tests a OrderService.cs"* | *"escribe tests xUnit para OrderService.cs cubriendo el caso donde el usuario no tiene stock. sin mocks de base de datos, usa TestContainers"* |
| **Señalar la fuente** | *"¿por qué OrderRepository tiene esa API tan rara?"* | *"mira el historial de git de OrderRepository y resume cómo llegó a tener esa API"* |
| **Referenciar patrones existentes** | *"añade un nuevo endpoint"* | *"mira cómo están implementados los endpoints en `Controllers/OrdersController.cs` como ejemplo. Sigue ese patrón para crear `POST /api/v1/reservations`. Sin librerías extra, solo las ya usadas"* |
| **Describir el síntoma** | *"arregla el bug de login"* | *"los usuarios reportan que el login falla tras timeout de sesión. Revisa `Services/AuthService.cs` especialmente el refresh de tokens. Escribe un test que reproduzca el fallo, luego corrígelo"* |

### Formas de enriquecer el contexto

- **`@fichero`** → Claude lee el fichero antes de responder
- **Imágenes** → copiar/pegar o arrastrar capturas de pantalla
- **URLs** → documentación, APIs de referencia (añadir a `/permissions`)
- **Pipe de datos** → `cat error.log | claude` para enviar contenido directo
- **Que Claude busque** → *"usa `dotnet nuget list` para ver los paquetes y luego..."*

---

## 5. ARQUITECTURA: Command → Agent → Skills

El patrón central de Claude Code — progresión de responsabilidad:

```
Usuario → /command → Agent (orquesta) → Skills (conocimiento)
```

- **Commands** (`.claude/commands/*.md`) — puntos de entrada ligeros; delegan
- **Agents** (`.claude/agents/*.md`) — orquestan con herramientas y permisos propios
- **Skills** (`.claude/skills/<nombre>/SKILL.md`) — módulos de conocimiento reutilizables
- **Rules** (`.claude/rules/*.md`) — instrucciones modulares con alcance opcional
- **Hooks** (`.claude/hooks/`) — acciones deterministas garantizadas en cada evento

Los subagentes **nunca se invocan por bash** — siempre con la herramienta `Task`.

### Cuándo usar cada uno

| Necesidad | Usar |
|---|---|
| Flujo de trabajo reutilizable | Command + Agent |
| Tarea específica con herramientas propias | Subagent |
| Conocimiento de dominio reutilizable | Skill |
| Instrucción persistente con alcance | Rule |
| Acción determinista en cada evento | Hook |
| Acción garantizada sin excepciones | Hook (no CLAUDE.md) |

---

## 6. FRONTMATTER DE AGENTS, SKILLS Y COMMANDS

### Agents (`.claude/agents/*.md`)
```yaml
---
name: nombre-agente
description: "Cuándo invocarlo. Añadir PROACTIVELY para auto-invocación."
tools: [Read, Write, Bash, Task]
model: sonnet          # haiku | sonnet | opus
permissionMode: acceptEdits
maxTurns: 20
color: cyan
---
```

### Skills (`.claude/skills/<nombre>/SKILL.md`)
```yaml
---
name: nombre-skill
description: "Cuándo se invoca."
disable-model-invocation: false   # true = solo usuario puede invocarla
user-invocable: true              # false = solo Claude, automáticamente
allowed-tools: [Read, Bash]
---
```

### Subagente para review de seguridad (.NET)
```markdown
---
name: dotnet-security-reviewer
description: Revisa código .NET para vulnerabilidades de seguridad
tools: Read, Grep, Glob, Bash
model: opus
---
Eres un senior security engineer especializado en .NET.
Revisa en busca de: SQL injection, XSS, command injection,
problemas de autenticación/autorización, secrets en código,
deserialización insegura, CORS mal configurado, dependencias con CVEs.
Proporciona referencias de línea específicas y correcciones sugeridas.
```

---

## 7. JERARQUÍA DE CONFIGURACIÓN

### Precedencia de settings (mayor a menor)
1. Flags de línea de comandos (sesión actual)
2. `.claude/settings.local.json` (proyecto, git-ignorado)
3. `.claude/settings.json` (proyecto, versionado en git)
4. `~/.claude/settings.local.json` (global personal)
5. `~/.claude/settings.json` (global personal)

### Permisos con wildcards (.NET)
```json
{
  "permissions": {
    "allow": [
      "Bash(dotnet build *)",
      "Bash(dotnet test *)",
      "Bash(dotnet run *)",
      "Bash(dotnet format *)",
      "Bash(dotnet restore *)",
      "Bash(dotnet add package *)",
      "Bash(dotnet ef *)",
      "Bash(az devops *)",
      "Bash(git *)",
      "Edit(./**)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(chmod *)"
    ]
  }
}
```

Las reglas `deny` tienen prioridad máxima — no pueden ser anuladas.

---

## 8. CLAUDE.md EFECTIVO

### Incluir / Excluir

| ✅ Incluir | ❌ Excluir |
|---|---|
| Comandos bash que Claude no puede adivinar | Lo que Claude puede inferir del código |
| Reglas de estilo que difieren del default | Convenciones estándar del lenguaje |
| Comandos de test y runners preferidos | Documentación detallada de APIs (enlazar) |
| Convenciones del repo (branches, PRs, commits) | Información que cambia frecuentemente |
| Decisiones arquitectónicas del proyecto | Explicaciones largas o tutoriales |
| Quirks del entorno dev (variables requeridas) | Descripciones fichero por fichero |
| Errores comunes no obvios | Prácticas autoevidententes como "escribe código limpio" |

### Señales de CLAUDE.md problemático
- Claude ignora una regla → el fichero es demasiado largo, la regla se pierde
- Claude pregunta cosas ya respondidas → la redacción es ambigua
- Claude hace algo incorrecto repetidamente → reforzar con "IMPORTANT" o "YOU MUST"

**Límite: 150 líneas.** Tratar como código: revisar cuando algo va mal, podar regularmente.

### Imports en CLAUDE.md
```markdown
Ver @README.md para visión del proyecto y @package.json para comandos npm.

# Instrucciones adicionales
- Git workflow: @docs/git-instructions.md
- Configuración personal: @~/.claude/my-project-instructions.md
```

---

## 9. CARGA DE CLAUDE.md EN MONOREPOS

```
/raíz/                  ← se carga al inicio (directorio actual)
  CLAUDE.md             ← carga inmediata (ancestro)
  /frontend/
    CLAUDE.md           ← carga lazy (al acceder a ficheros de frontend)
  /backend/
    CLAUDE.md           ← carga lazy (al acceder a ficheros de backend)
```

- **Carga ancestral**: todos los CLAUDE.md desde cwd hasta `/` se cargan al iniciar
- **Carga descendente**: lazy, solo cuando se accede a ficheros de ese subdirectorio
- **`CLAUDE.local.md`**: preferencias personales → añadir a `.gitignore`

---

## 10. GESTIÓN DE SESIÓN Y CONTEXTO

### Corregir pronto y a menudo
- **`Esc`** → detiene a Claude mid-acción; el contexto se preserva para redirigir
- **`Esc + Esc` / `/rewind`** → abre menú de rewind; restaura conversación, código o ambos
- **`"Undo that"`** → Claude revierte sus cambios
- **`/clear`** → resetea contexto entre tareas no relacionadas

### Patrón de corrección
Si has corregido a Claude 2+ veces en el mismo fallo → el contexto está contaminado
con enfoques fallidos. Hacer `/clear` y empezar con un prompt mejor que incorpore
lo aprendido.

### Checkpoints
Claude crea checkpoints automáticamente antes de cada cambio.
`Esc + Esc` → `/rewind` → restaurar conversación / código / ambos.
Los checkpoints persisten entre sesiones.

### Reanudar sesiones
```bash
claude --continue      # reanudar la conversación más reciente
claude --resume        # elegir entre sesiones recientes
/rename                # dar nombre descriptivo: "oauth-migration", "fix-capacity-bug"
```

---

## 11. "ENTREVISTA PRIMERO" — PARA FEATURES GRANDES

Para features complejas, dejar que Claude te entreviste antes de implementar:

```
Quiero construir [descripción breve]. Entrevístame en detalle
usando la herramienta AskUserQuestion.

Pregunta sobre implementación técnica, UX, casos límite,
compromisos y riesgos. No preguntes lo obvio, profundiza en
las partes difíciles que quizá no he considerado.

Sigue entrevistando hasta cubrirlo todo, luego escribe una
especificación completa en SPEC.md.
```

Una vez completada la spec, iniciar una sesión nueva para implementarla
(contexto limpio, enfocado solo en implementación).

---

## 12. PATRONES DE VERIFICACIÓN PARA .NET

### Hooks para .NET — garantizar calidad en cada cambio
```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "run": "dotnet build --no-restore 2>&1 | tail -5"
    }],
    "PreToolUse": [{
      "matcher": "Bash(git commit*)",
      "run": "dotnet test --no-build --filter 'Category=Unit'"
    }]
  }
}
```

### Skill de convenciones .NET
```yaml
---
name: dotnet-conventions
description: Convenciones de código C# y .NET para este proyecto
---
# Convenciones C#
- Usar async/await en toda la cadena — nunca .Result o .Wait()
- Preferir record types para DTOs inmutables
- Inyección de dependencias: siempre por constructor
- Entity Framework: usar IQueryable<T>, no cargar todo en memoria
- Migrations: siempre revisar antes de aplicar en producción
```

---

## 13. AUTOMATIZACIÓN Y ESCALADO

### Modo headless
```bash
claude -p "Explica qué hace este proyecto"
claude -p "Lista todos los endpoints de la API" --output-format json
claude -p "Analiza este log" --output-format stream-json
```

### Patrón Writer/Reviewer (.NET)
```
Sesión A (Writer):  "Implementa un rate limiter para los endpoints de la API"
Sesión B (Reviewer): "Revisa la implementación en @src/Middleware/RateLimiter.cs.
                       Busca race conditions, casos límite y coherencia con los
                       middleware patterns de ASP.NET existentes."
Sesión A:           "Aquí el feedback del review: [output B]. Corrige los problemas."
```

### Fan-out para migraciones .NET a escala
```bash
# Ejemplo: actualizar paquetes NuGet en todos los proyectos de la solución
dotnet sln list | grep .csproj > projects.txt
for project in $(cat projects.txt); do
  claude -p "Actualiza los paquetes NuGet obsoletos en $project.
             Ejecuta dotnet test después. Devuelve OK o FAIL con el motivo."
    --allowedTools "Edit,Bash(dotnet *),Bash(git commit *)"
done
```

---

## 14. PATRONES DE FALLO COMUNES (Y SUS CORRECCIONES)

| Fallo | Síntoma | Corrección |
|---|---|---|
| **Sesión "kitchen sink"** | Mezclas tareas no relacionadas | `/clear` entre tareas |
| **Corrección infinita** | Corriges 2+ veces el mismo fallo | `/clear` + prompt mejor |
| **CLAUDE.md inflado** | Claude ignora la mitad de las reglas | Podar sin piedad (150 líneas max) |
| **Trust sin verify** | Código plausible que no funciona en edge cases | Siempre tests/scripts de verificación |
| **Exploración infinita** | Claude lee cientos de ficheros, contexto lleno | Acotar investigaciones o usar subagentes |
| **Bash bloqueado en .NET** | Timeouts en `dotnet test` largas | `--filter "Category=Unit"` para tests rápidos |

---

## 15. MCP SERVERS ESENCIALES

| MCP | Para qué |
|---|---|
| **Context7** | Documentación actualizada de librerías (evita APIs alucinadas) |
| **Playwright** | Automatización de UI, testing y verificación con capturas |
| **Claude in Chrome** | Inspección en vivo de DOM, consola y red del navegador |
| **DeepWiki** | Documentación estructurada de repositorios GitHub |
| **Azure DevOps MCP** | Operaciones avanzadas encadenadas en Azure DevOps |

---

## 16. TIPS DE BORIS CHERNY (febrero 2026)

1. **Terminal**: `/config` para tema, `/terminal-setup` para shift+enter, `/vim` para vim mode
2. **Esfuerzo**: `/model` → High recomendado para máxima inteligencia
3. **Plugins**: instalar LSPs, MCPs y skills desde el marketplace de Anthropic
4. **Agentes**: `.claude/agents/*.md` con nombre, color, herramientas y modelo propio
5. **Permisos**: `/permissions` + wildcards + `settings.json` en git para el equipo
6. **Sandbox**: `/sandbox` para aislamiento y menos prompts de permiso
7. **Status line**: `/statusline` para mostrar modelo, contexto, coste, métricas propias
8. **Keybindings**: `/keybindings` con recarga en vivo
9. **Hooks**: interceptar lifecycle para logging, notificaciones, auto-continuar
10. **Output styles**: `/config` → Explanatory (aprendizaje), Learning (coaching), Custom
11. **Versionar settings**: `settings.json` en git = configuración compartida con el equipo

---

## 17. COMANDOS CLI DE REFERENCIA

```bash
# Inicio y gestión de sesión
claude --continue                  # reanudar última sesión
claude --resume                    # elegir sesión reciente
claude --model opus                # seleccionar modelo
claude --max-turns 50              # límite de turnos
claude -p "prompt"                 # modo headless (scripts, CI)
claude -p "prompt" --output-format json   # output estructurado

# Durante la sesión
/plan                              # activar modo plan (explorar sin modificar)
/compact                           # compactar contexto manualmente (hacer al 50%)
/compact "preservar lista de ficheros modificados"
/rewind                            # menú de checkpoints
/clear                             # resetear contexto
/doctor                            # diagnóstico de Claude Code
/permissions                       # gestionar permisos
/sandbox                           # activar sandbox
/model                             # cambiar modelo / nivel de esfuerzo
/config                            # configurar terminal y output style
/statusline                        # configurar barra de estado
/hooks                             # configurar hooks interactivamente
/memory                            # ver y editar memoria persistente
/rename                            # nombrar la sesión actual
/cost                              # ver coste de la sesión actual
/init                              # generar CLAUDE.md inicial desde el proyecto
```
