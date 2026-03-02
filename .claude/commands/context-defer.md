---
name: context-defer
description: Sistema de carga diferida — cargar comandos/reglas solo cuando se necesitan (85% reducción de overhead)
developer_type: all
agent: task
context_cost: high
---

# Comando: context-defer

## Sinopsis

Implementar y gestionar un sistema de carga diferida (lazy loading) de comandos y reglas en pm-workspace. Convertir cargas eager en deferred. Reducir overhead de contexto un 85% cargando solo lo necesario cuando se invoca.

## Sintaxis

```bash
/context-defer [--scan] [--apply] [--status] [--lang es|en]
```

Flags:
- `--scan` — analizar `.claude/profiles/context-map.md` e identificar candidatos para deferred loading
- `--apply` — aplicar conversión de eager → deferred en el context-map
- `--status` — mostrar estado actual de deferred loading (qué está defer, qué eager)
- `--lang es|en` — idioma del output

## Comportamiento

### 1. Cargar perfil (si está activo)

Leer `.claude/profiles/active-user.md` → `active_slug`.
Si hay perfil, cargar identity.md para contexto.

### 2. Escanear context-map (con `--scan`)

Leer `.claude/profiles/context-map.md`. Para cada grupo de comandos:

**Análisis por grupo:**
```
Grupo: Sprint & Daily
  Comandos: 10
  Tokens si cargados: ~500
  Frecuencia estimada: 5/7 días (diario)
  Recomendación: EAGER ✅ (necesarios frecuentemente)

Grupo: Governance & Compliance
  Comandos: 8
  Tokens si cargados: ~400
  Frecuencia estimada: 1/30 días (mensuales)
  Recomendación: DEFERRED 💤 (raramente usados)
```

Salida: tabla con grupos, recomendación defer/eager, tokens ahorrados si se aplica.

### 3. Aplicar conversión (con `--apply`)

Para cada grupo recomendado como DEFERRED:

1. Extraer del context-map los comandos
2. Crear fichero `defer_{grupo}.md` con registro de comandos
3. Reemplazar en context-map con referencia: `@defer:grupo-nombre`
4. Verificar sintaxis resultante

**Ejemplo conversión:**

Antes:
```markdown
### Grupo: Governance & Compliance

**Comandos:** `/governance-audit`, `/governance-report`, ...
```

Después:
```markdown
### Grupo: Governance & Compliance (⏱️ Deferred)

📋 Este grupo se carga bajo demanda al ejecutar un comando.
**Referencia:** `@defer:governance-compliance`
```

Fichero creado: `.claude/profiles/defer_governance-compliance.md`

### 4. Mostrar estado (con `--status`)

```
📊 Estado de Deferred Loading

Grupos EAGER (siempre cargados):
  ✅ Sprint & Daily (500 tokens)
  ✅ PBI & Backlog (300 tokens)

Grupos DEFERRED (bajo demanda):
  💤 Governance & Compliance (descargado, 400 tokens ahorrados)
  💤 Legacy & Capture (descargado, 150 tokens ahorrados)

Beneficio total: 550 tokens ahorrados en sesión inicial
Impacto: 85% de reducción en overhead de contexto startup
```

## Output

### Si `--scan`

Tabla con: grupo | comandos | tokens | frecuencia | recomendación | ahorro potencial

### Si `--apply`

Confirmación de cambios + estadísticas de conversión.

### Si `--status`

Resumen visual de estado EAGER/DEFERRED + tokens ahorrados totales.

## Notas

- **Integración con context-map**: `.claude/profiles/context-map.md` es el source of truth
- **85% reduction**: estimación basada en carga típica (sistema + reglas + conversation)
- **Fallback automático**: si un comando `@defer:grupo` falla, cargarlo inmediatamente
- **Reversible**: ejecutar de nuevo `--apply` para cambiar configuración

## Integración

Conecta con:
- `/context-budget` — medir ahorro de tokens
- `/context-profile` — análisis de consumo por rol
- `/context-compress` — compresión adicional
- `.claude/profiles/context-map.md` — definición de grupos y cargas

