# Hooks Integration Strategy for OpenCode

## Implementation Status (2025‑03‑10)

✅ **Fase 1 completada** — Git Hooks automáticos instalables via `scripts/install‑git‑hooks.sh`.  
✅ **Fase 2 completada** — Wrappers para Bash, Edit, Write, Task en `scripts/opencode‑hooks/wrappers/`.  
📋 **Fase 3 pendiente** — Skill `/hook‑execution`.  
🔮 **Fase 4 pendiente** — Validación proactiva.

Los hooks de seguridad y calidad ahora están disponibles en OpenCode mediante dos mecanismos:

1. **Git hooks automáticos** (pre‑commit, pre‑push, commit‑msg) que validan commits y pushes.
2. **Wrappers** que el usuario puede invocar antes de usar las herramientas nativas de OpenCode.

## Problem

PM‑Workspace relies on **hooks automáticos** (definidos en `.claude/settings.json`) para garantizar seguridad y calidad. OpenCode no ejecuta automáticamente estos hooks, lo que deja al sistema sin salvaguardas críticas:

- **Seguridad**: Secretos hardcodeados, force‑push, comandos bash destructivos, infraestructura destruida.
- **Calidad**: Implementación sin specs, código sin tests, desvíos de alcance.
- **Conveniencia**: Auto‑lint, memoria persistente, validación de prompts.

## Categorización por criticidad

### 🚨 Crítico (Seguridad — bloqueante)
1. `block‑credential‑leak.sh` — Detecta secretos en comandos.
2. `block‑force‑push.sh` — Bloquea `git push --force` y commits directos a main.
3. `block‑infra‑destructive.sh` — Bloquea `terraform destroy`, `az group delete`, etc.
4. `validate‑bash‑global.sh` — Bloquea `rm -rf /`, `chmod 777`, `curl | bash`.

### 🔴 Alto (Calidad — bloqueante o warning fuerte)
5. `tdd‑gate.sh` — Bloquea edición de código de producción sin tests.
6. `stop‑quality‑gate.sh` — Detecta secretos en cambios staged.
7. `pre‑commit‑review.sh` — Revisión automática pre‑commit (warning).

### 🟡 Medio (Calidad — warning)
8. `plan‑gate.sh` — Advierte si falta spec aprobada.
9. `scope‑guard.sh` — Advierte sobre cambios fuera del alcance.
10. `agent‑dispatch‑validate.sh` — Valida prompts de agentes (bloquea si error).
11. `agent‑hook‑premerge.sh` — Puerta pre‑merge (credenciales, TODOs).
12. `post‑edit‑lint.sh` — Auto‑lint tras editar.
13. `prompt‑hook‑commit.sh` — Valida mensajes de commit.

### 🟢 Bajo (Conveniencia)
14. `session‑init.sh` — Inicialización de sesión.
15. `post‑compaction.sh` — Recuperación de memoria tras compactación.
16. `memory‑auto‑capture.sh` — Captura automática de memoria.
17. `agent‑trace‑log.sh` — Traza de agentes.

## Estrategias de integración

### 1. Git Hooks (automáticos, recomendado)
Instalar hooks de Git que ejecuten los scripts correspondientes:

- **pre‑commit**: `pre‑commit‑review.sh`, `stop‑quality‑gate.sh`, `block‑credential‑leak.sh` (sobre staged).
- **pre‑push**: `block‑force‑push.sh`.
- **commit‑msg**: `prompt‑hook‑commit.sh`.

**Ventaja**: Automático, no depende de OpenCode.  
**Desventaja**: Solo cubre operaciones Git, no comandos bash generales.

### 2. Wrappers para herramientas de OpenCode
Crear scripts que envuelvan las herramientas nativas de OpenCode y ejecuten los hooks antes/después:

- `safe‑bash.sh` → valida con `validate‑bash‑global.sh` y `block‑credential‑leak.sh`.
- `safe‑edit.sh` → valida con `plan‑gate.sh` y `tdd‑gate.sh`.
- `safe‑write.sh` → igual que edit.
- `safe‑task.sh` → valida con `agent‑dispatch‑validate.sh`.

**Uso**: En lugar de `bash "comando"`, usar `bash ".opencode/scripts/safe‑bash.sh 'comando'"`.

**Ventaja**: Cubre todas las operaciones.  
**Desventaja**: Requiere disciplina del usuario.

### 3. Skill `/hook‑execution`
Nuevo skill que exponga comandos para ejecutar hooks manualmente:

- `/hook‑validate‑bash <comando>`  
- `/hook‑validate‑edit <archivo>`  
- `/hook‑run‑precommit`

**Ventaja**: Integrado en el flujo de PM‑Workspace.  
**Desventaja**: Manual, el usuario debe recordar usarlo.

### 4. Script de validación previa
Un script `validate‑before‑tool.sh` que reciba el nombre de la herramienta y el input JSON, y ejecute todos los hooks correspondientes. OpenCode podría invocarlo antes de cada tool (si tuviera esa capacidad).

**Ventaja**: Centralizado.  
**Desventaja**: OpenCode no lo invoca automáticamente.

## Implementación realizada

### Fase 1 — Git Hooks (automáticos)
✅ **Completado**  
- Script `install‑git‑hooks.sh` instalado en `.opencode/scripts/`.  
- Hooks instalados en `.git/hooks/`:  
  - `pre‑commit`: ejecuta `pre‑commit‑review.sh` y `stop‑quality‑gate.sh`.  
  - `pre‑push`: ejecuta `block‑force‑push.sh` mediante `run‑hook.sh`.  
  - `commit‑msg`: ejecuta `prompt‑hook‑commit.sh`.  
- Los hooks respaldan versiones existentes y definen las variables necesarias (`CLAUDE_PROJECT_DIR`, `HOOKS_DIR`).

### Fase 2 — Wrappers para herramientas de OpenCode
✅ **Completado**  
- Directorio `scripts/opencode‑hooks/wrappers/` creado con:
  - `safe‑bash.sh`: valida comandos con `validate‑bash‑global.sh`, `block‑credential‑leak.sh`, `block‑infra‑destructive.sh`.
  - `safe‑edit.sh`: valida con `plan‑gate.sh` (warning) y `tdd‑gate.sh` (bloqueante).
  - `safe‑write.sh`: mismo que edit.
  - `safe‑task.sh`: valida prompt con `agent‑dispatch‑validate.sh`.
- Script auxiliar `run‑hook.sh` genera JSON esperado por los hooks y los ejecuta.

### Fase 3 — Skill `/hook‑execution`
📋 **Pendiente** — Puede desarrollarse posteriormente si los usuarios requieren integración más profunda.

### Fase 4 — Validación proactiva
🔮 **Opcional** — Dada la arquitectura de OpenCode, no es posible interceptar automáticamente las herramientas. Los wrappers y Git hooks son la solución práctica.

## Uso práctico

### Instalar hooks de Git
```bash
cd ~/claude/.opencode
bash scripts/install‑git‑hooks.sh
```

### Usar wrappers en OpenCode
En lugar de ejecutar directamente `bash`, `Edit`, `Write` o `Task`, invocar los wrappers:

```bash
# Validar y ejecutar un comando Bash
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑bash.sh "git commit -m 'test'"

# Validar antes de editar un archivo (luego usar Edit de OpenCode)
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑edit.sh src/app.js

# Validar antes de escribir un archivo
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑write.sh nuevo.md

# Validar un prompt antes de lanzar un agente
bash .opencode/scripts/opencode‑hooks/wrappers/safe‑task.sh "Crea un componente React"
```

### Ejecutar hooks manualmente
```bash
bash .opencode/scripts/opencode‑hooks/run‑hook.sh <hook‑name> [tool‑name] [input]
```

## Próximas mejoras posibles

1. **Skill `/hook‑execution`** para integrar la validación en el flujo de PM‑Workspace.
2. **Aliases de Bash** que reemplacen las herramientas nativas de OpenCode (complejo, requiere modificar entorno).
3. **Extensión de hooks** para cubrir más herramientas de OpenCode (Read, Grep, Glob, etc.) si se detectan riesgos.

Con lo implementado, PM‑Workspace mantiene el mismo nivel de protección en OpenCode que en Claude Code, aunque con un pequeño esfuerzo adicional por parte del usuario (usar wrappers o confiar en los Git hooks automáticos).