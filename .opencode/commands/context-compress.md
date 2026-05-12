---
name: context-compress
description: Compresión semántica de contexto — mantener significado, reducir tokens (80% reduction)
developer_type: all
agent: task
context_cost: high
---

# Comando: context-compress

## Sinopsis

Aplicar técnicas de compresión semántica sobre el contexto cargado. Mantener significado mientras se reducen tokens. Técnicas: deduplicación, summarización, merge de comandos similares, extracción de patrones compartidos. Reducción target: 80% preservando fidelidad.

## Sintaxis

```bash
/context-compress [--preview] [--apply] [--ratio target] [--lang es|en]
```

Flags:
- `--preview` — mostrar qué se comprimiría sin aplicar cambios
- `--apply` — aplicar compresión (requiere confirmación)
- `--ratio target` — ratio objetivo (default 80%, ej: --ratio 70)
- `--lang es|en` — idioma del output

## Comportamiento

### 1. Cargar perfil (si está activo)

Leer `.claude/profiles/active-user.md` → `active_slug`.
Cargar identity.md para contexto.

### 2. Análisis de compresión (con `--preview`)

Inspeccionar reglas, comandos y perfiles cargados. Identificar candidatos:

**2a. Deduplicación** — referencias idénticas consolidadas (ahorro ~150 tokens)
**2b. Summarización** — reglas verbosas resumidas sin perder esencia (ahorro ~200 tokens)
**2c. Merge patrones** — comandos con solapamiento → patrón base (ahorro ~80 tokens)
**2d. Patrones compartidos** — procedimientos reutilizables (ahorro ~120 tokens)
**2e. Índice semántico** — normalización de términos frecuentes (ahorro ~90 tokens)

Reporte preview:
```
Compresión propuesta:
  ✓ Deduplicación: 150 tokens
  ✓ Summarización: 200 tokens
  ✓ Merge patrones: 80 tokens
  ✓ Patrones base: 120 tokens
  ✓ Índice semántico: 90 tokens
  ────────────────────────────
  Total: 640 tokens (12.2% de 5,240 cargados)
```

### 3. Aplicar compresión (con `--apply`)

1. Crear fichero `.claude/compression-map.md`
2. Registrar mappings: original → versión comprimida
3. Generar índice de conceptos: términos normalizados
4. Validar coherencia: significado preservado
5. Medir impacto: tokens antes/después

Fichero generado:
```markdown
# Compression Map

## Deduplicación
- backup-protocol + pm-config.local → ref única

## Summarización
- backup-protocol.md (180 líneas) → "AES-256 local+nube"

## Patrón base: UserProfileLoad
Reemplaza en 8 comandos

## Índice de conceptos
- [CB] = context-budget
- [CD] = context-defer
```

### 4. Medir impacto

```
Antes: 5,240 tokens
Estimado: 1,048 tokens (80% compresión)
Fidelidad: 98% (sin pérdida semántica significativa)

Medición real: 1,120 tokens (78.6% compresión) ✅
```

## Output

### Si `--preview`

Lista de técnicas + ahorros estimados + ratio total.

### Si `--apply`

Confirmación + fichero `.claude/compression-map.md` + métricas.

## Notas

- **80% target**: alcanzable solo con redundancia significativa
- **Fidelidad**: SIEMPRE preservar significado
- **Reversible**: `/context-decompress` para descomprimir (futuro)

## Integración

Conecta con: `/context-budget`, `/context-defer`, `/context-profile`

