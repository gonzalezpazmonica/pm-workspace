---
name: instinct-manage
description: >
  Gestiona los instintos de Savia — patrones aprendidos de interacciones
  repetidas que se convierten en comportamientos automáticos con scoring
  de confianza.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
---

# /instinct-manage {subcommand} {args}

Subcommands: list, add, disable, stats, decay, export

## Prerequisitos

1. Verificar que `.claude/instincts/` existe (crear si no)
2. Cargar registro: `.claude/instincts/registry.json`

## Ejecución

### /instinct-manage list

1. Banner: `══ /instinct-manage list ══`
2. Leer `.claude/instincts/registry.json`
3. Mostrar instintos ordenados por confianza (descendente)
4. Formato tabla: ID, patrón, acción, confianza (%), activaciones, último uso
5. Marcar: 🟢 >80%, 🟡 50-80%, 🔴 <50%

### /instinct-manage add {patrón} {acción}

1. Banner: `══ /instinct-manage add ══`
2. Crear instinto con:
   - id: INST-NNN (secuencial)
   - pattern: regex o descripción del trigger
   - action: qué hace Savia cuando detecta el patrón
   - confidence: 50 (inicio neutral)
   - activations: 0
   - created: fecha actual
   - enabled: true
3. Guardar en registry.json
4. Banner con ID creado

### /instinct-manage disable {id}

1. Marcar instinto como enabled: false
2. No se borra, solo se desactiva

### /instinct-manage stats

1. Total instintos (activos/inactivos)
2. Confianza media
3. Top-5 más activados
4. Top-5 con mayor confianza
5. Instintos en decay (confianza bajando)

### /instinct-manage decay

1. Aplicar decay a instintos no usados en 30 días
2. Regla: -5% por cada 30 días sin uso (floor: 20%)
3. Mostrar instintos afectados

### /instinct-manage export

1. Exportar registry.json a formato legible (markdown)

## Output

```
.claude/instincts/registry.json
```

## Reglas

- Los instintos NUNCA ejecutan acciones destructivas automáticamente
- Confianza inicial: 50%. Sube +3% por uso exitoso, -5% por fallo o feedback negativo
- Floor de confianza: 20% (nunca baja de ahí)
- Ceiling: 95% (nunca llega a 100% — siempre hay incertidumbre)
- Un instinto con confianza <30% se marca como "en revisión"
- Los instintos NO sustituyen reglas explícitas — son complementarios
- Decay automático: -5% por cada 30 días sin activación
- Máximo 100 instintos activos simultáneos
