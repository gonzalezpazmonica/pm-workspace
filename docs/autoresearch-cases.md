# Autoresearch — Casos de Uso Detallados

> Referencia complementaria de `docs/AUTORESEARCH.md`. Contiene ejemplos concretos de research programs y configuraciones.

---

## 1. Optimización de hiperparámetros overnight

**Objetivo**: Encontrar el mejor learning rate, batch size y warmdown ratio.

```markdown
# program.md
Objetivo: Minimizar val_bpb explorando hiperparámetros.

Estrategia:
1. Probar learning rates: 0.02, 0.04, 0.06, 0.08
2. Con el mejor LR, probar batch sizes: 2^18, 2^19, 2^20
3. Con los mejores LR + batch, probar warmdown ratios: 0.3, 0.5, 0.7
4. Fine-tuning: variaciones ±10% alrededor del mejor punto

Cada combinación = 1 run de 5 minutos.
Estimación: 12 runs/hora × 8 horas = ~96 experimentos.
```

**Resultado**: `results.tsv` con ~96 filas, ordenable por `val_bpb`.

---

## 2. Exploración arquitectónica

```markdown
# program.md
Objetivo: Minimizar val_bpb explorando arquitectura.

Experimentos:
1. Window patterns: "SSSL", "SSLL", "SLSL", "LLLL"
2. Activaciones: relu², GELU, SiLU, relu² + GELU alternados
3. Depth vs width: 4×128, 8×64, 16×32 (mismo parámetro count)
4. GQA ratios: 1, 2, 4 kv_heads
5. Eliminar value embeddings — ¿cuánto aportan?
```

---

## 3. Ablation studies automáticas

```markdown
# program.md
Objetivo: Ablation study — eliminar componentes uno a uno.

Baseline: current train.py (val_bpb = X)

Para cada componente, crear versión sin él y medir impacto:
1. Sin Value Embeddings → medir delta
2. Sin Sliding Window (todo full attention) → medir delta
3. Sin per-layer residual scalars → medir delta
4. Sin Muon (solo AdamW) → medir delta
5. Sin soft-capping → medir delta
6. Sin warmdown → medir delta

Mantener eliminaciones que NO degradan rendimiento (= simplificación gratis).
```

---

## 4. Benchmarking reproducible

Cada run tiene exactamente 5 minutos, resultados directamente comparables:

```
Configuración        | val_bpb | VRAM (GB) | MFU (%)
─────────────────────┼─────────┼───────────┼────────
Baseline (8L, 64AR)  | 0.9979  | 44.0      | 39.8
12L, 43AR (same #P)  | 0.9921  | 43.5      | 38.2
8L, 64AR, LLLL       | 1.0031  | 45.2      | 37.1
8L, 64AR, no ValEmb  | 1.0015  | 42.8      | 41.0
```

---

## Estructura de un research program

```markdown
# Programa de investigación: {tema}

## Setup
- Crear rama git: autoresearch/{tag}
- Leer archivos del scope, verificar prerequisitos

## Scope
- Archivos modificables vs solo lectura
- Dependencias permitidas

## Objetivo
- Métrica principal (ej: val_bpb), métricas secundarias
- Definición de "mejora"

## Restricciones
- Time budget por experimento, recursos máximos, cambios prohibidos

## Bucle
- Ciclo experiment → measure → decide
- Formato de registro (results.tsv)

## Criterios de calidad
- Simplicidad sobre complejidad
- "No preguntes. No pares. Experimenta."
```

---

## Fail-fast y recuperación

| Escenario | Detección | Acción |
|-----------|-----------|--------|
| Loss explosion | `train_loss > 100` → `exit(1)` | Descartar, siguiente experimento |
| Timeout | Run > 10 min (2× budget) | Matar proceso, registrar timeout |
| OOM | Crash por memoria | Descartar, reducir tamaño en siguiente |
| Error de código | Error Python/CUDA | Leer log (50 líneas), intentar fix o skip |
| Repetición | Mismo cambio 3 veces | Forzar cambio de estrategia |

---

## Formato results.tsv

```tsv
commit	val_bpb	memory_gb	status	description
a1b2c3d	0.997900	44.0	keep	baseline
b2c3d4e	0.993200	44.2	keep	increase LR to 0.04
c3d4e5f	1.005000	44.0	discard	switch to GeLU activation
d4e5f6g	0.000000	0.0	crash	double model width (OOM)
```

Columnas: commit (7 chars), val_bpb (6 decimales), memory_gb (0.1), status (keep|discard|crash), description.
