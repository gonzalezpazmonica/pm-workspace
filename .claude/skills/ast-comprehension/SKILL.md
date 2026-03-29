---
name: ast-comprehension
description: Comprensión estructural de código que no hemos escrito. Extrae mapa de clases/funciones, dependencias, call graph, complejidad y superficie API mediante AST multi-lenguaje. Pre-modifica contexto para agentes, legacy assessment y comprehension reports.
summary: |
  Extractor AST de comprensión para 16 lenguajes. Pre-edición inyecta
  estructura del fichero objetivo. Legacy: mapa completo de clases,
  funciones, dependencias, complejidad y API surface. Output JSON unificado.
  Complementa ast-quality-gate (valida output IA) vs comprensión (entiende código ajeno).
maturity: experimental
context: fork
agent: code-reviewer
category: "quality"
tags: ["ast", "comprehension", "legacy", "structural-analysis", "pre-edit"]
priority: "high"
allowed-tools: [Bash, Read, Glob, Grep, Write]
---

# AST Comprehension — Entender Código Que No Hemos Escrito

Extractor estructural multi-lenguaje que da a los agentes contexto sobre código
ajeno antes de modificarlo. Diferente de `ast-quality-gate` (valida output IA):
este skill **comprende código existente** para evitar modificaciones ciegas.

## Cuándo usar

- **Pre-edición**: antes de que un agente edite un fichero existente → contexto estructural
- **Legacy assessment** (`/legacy-assess`): mapear codebase heredado antes de migrar
- **Evaluate repo** (`/evaluate-repo`): entender estructura de un repo externo
- **Comprehension report** (`/comprehension-report`): documentar arquitectura interna
- **Code improvement loop**: saber qué se puede refactorizar y por qué

## Diferencia clave con ast-quality-gate

| Skill | Input | Pregunta | Output |
|-------|-------|----------|--------|
| `ast-quality-gate` | Código generado por IA | ¿Tiene errores? | Score + issues |
| `ast-comprehension` | Código ajeno/legacy | ¿Qué hace y cómo? | Mapa estructural |

## 3 Capas de Extracción

```
Capa 1: Tree-sitter (universal, sin ejecución, todos los lenguajes)
  → tree-sitter parse --output json <fichero>
  → Estructural puro: nodos, funciones, clases

Capa 2: Herramienta nativa semántica por lenguaje
  → Python: ast module  · Go: go doc + go list
  → TypeScript: ts-morph · C#: Roslyn SyntaxWalker
  → Enriquece con tipos, imports, relaciones

Capa 3: Semgrep structural patterns
  → Extrae call graphs y dependencias cruzadas
  → Misma config que quality-gate, modo extracción
```

## Output: Comprehension Report JSON

```json
{
  "meta": { "file": "...", "language": "...", "lines": 250 },
  "structure": {
    "classes": [{ "name": "...", "line": 10, "methods": [...] }],
    "functions": [{ "name": "...", "line": 50, "complexity": 8 }],
    "constants": [{ "name": "...", "line": 5 }]
  },
  "imports": { "internal": [...], "external": [...], "standard": [...] },
  "complexity": {
    "hotspots": [{ "name": "...", "complexity": 12, "line": 100 }]
  },
  "api_surface": { "public": [...], "private": [...] },
  "summary": "Descripción en 1 párrafo de qué hace el fichero"
}
```

Ver schema completo: `references/comprehension-schema.md`

## Uso Manual

```bash
# Fichero individual
bash scripts/ast-comprehend.sh src/Services/AuthService.cs

# Directorio completo
bash scripts/ast-comprehend.sh src/

# Solo estructura superficial (rápido)
bash scripts/ast-comprehend.sh src/ --surface-only

# Para legacy assessment (sin límite de complejidad)
bash scripts/ast-comprehend.sh src/ --legacy-mode

# Output a fichero específico
bash scripts/ast-comprehend.sh src/ --output output/comprehension/report.json
```

## Integración Pre-Edición (hook)

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Edit",
      "command": ".claude/hooks/ast-comprehend-hook.sh",
      "async": false
    }]
  }
}
```

El hook inyecta estructura del fichero destino en el contexto del agente
**antes** de que edite. El agente sabe qué hay en el fichero sin leerlo entero.

## Pipeline de Ejecución

### Paso 1: Detectar lenguaje y modo
Extensión → lenguaje → herramienta nativa disponible.
Si fichero no existe → modo vacío (no hay comprensión que hacer).

### Paso 2: Extracción superficial (siempre)
Tree-sitter o grep-estructural para: clases, funciones, líneas clave.
Sin ejecución de código. < 2 segundos.

### Paso 3: Extracción semántica (si herramienta disponible)
Tipos, imports, call graph. 2-10 segundos según lenguaje.

### Paso 4: Calcular complejidad
Número de ramas (if, for, while, &&, ||) por función.
Identificar hotspots (complejidad > 10).

### Paso 5: Generar summary
1 párrafo en lenguaje natural describiendo el propósito del fichero/directorio.

## Prerrequisitos

- `tree-sitter-cli` (opcional pero recomendado): `npm install -g tree-sitter-cli`
- `jq` para normalización JSON
- Herramienta nativa del lenguaje (ver `references/extraction-commands.md`)

## Esquemas y referencias

- `references/comprehension-schema.md` — Schema JSON completo
- `references/extraction-commands.md` — Comandos por lenguaje para extracción estructural
