# Spec Quality Auditor

> Version: v4.8 | Era: 177 | Desde: 2026-04-03

## Que es

Evaluador determinista que puntua especificaciones SDD en una escala 0-100 usando 9 criterios objetivos. Permite evaluar specs individuales o lotes completos, filtrando por puntuacion minima. Genera salida en texto o JSON.

## Requisitos

Preinstalado desde v4.8. Sin dependencias externas.

## Uso basico

```bash
# Evaluar un spec individual
bash scripts/spec-quality-auditor.sh docs/propuestas/SPEC-078.md

# Evaluar todos los specs de un directorio
bash scripts/spec-quality-auditor.sh --batch docs/propuestas/

# Filtrar por puntuacion minima
bash scripts/spec-quality-auditor.sh --batch docs/propuestas/ --min-score 80

# Salida en JSON
bash scripts/spec-quality-auditor.sh docs/propuestas/SPEC-078.md --json
```

Salida tipica:
```
SPEC-078: 85/100
  header:       10/10
  metadata:      8/10
  problem:      10/10
  solution:      9/10
  acceptance:    9/10
  effort:       10/10
  dependencies:  9/10
  testability:   8/10
  clarity:      12/15
```

## Los 9 criterios

| Criterio | Peso | Evalua |
|----------|------|--------|
| header | 10 | Titulo, SPEC number, formato correcto |
| metadata | 10 | Status, autor, fecha, version |
| problem | 10 | Problema definido con claridad |
| solution | 10 | Solucion descrita y viable |
| acceptance | 10 | Criterios de aceptacion medibles |
| effort | 10 | Estimacion de esfuerzo presente |
| dependencies | 10 | Dependencias identificadas |
| testability | 10 | Casos de test o estrategia |
| clarity | 15 | Legibilidad general, sin ambiguedades |

Certificacion: specs con 80+ se consideran "ready for implementation".

## Modo batch

El modo batch escanea todos los ficheros `SPEC-*.md` de un directorio y genera un resumen:
```
21/73 specs certificados (80+)
Media: 72.3 | Mediana: 75 | Min: 34 | Max: 98
```

## Integracion

- **SDD pipeline**: evaluar specs antes de asignar a agentes de implementacion
- **SPEC triage**: usar `--min-score 80` para identificar specs listos para promover a Ready
- **CI**: `bash scripts/spec-quality-auditor.sh --batch --min-score 70 --json` retorna exit code 1 si algun spec no cumple

## Troubleshooting

**Puntuacion baja en "acceptance"**: anadir criterios de aceptacion en formato Given/When/Then con datos concretos

**Puntuacion baja en "metadata"**: verificar que el spec tiene frontmatter con status, autor y fecha

**El batch no encuentra specs**: asegurar que los ficheros siguen el patron `SPEC-*.md`
