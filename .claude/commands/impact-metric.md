---
name: impact-metric
description: >
  Gestiona métricas de impacto para organizaciones sin fines de lucro. Define
  indicadores alineados con los ODS, registra mediciones periódicas y genera
  reportes de impacto para donantes, junta directiva y público.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# impact-metric

Comando para administrar métricas de impacto social en proyectos sin fines de lucro.

## Subcomandos

### define
Crea una nueva métrica de impacto con estructura completa.

```
impact-metric define <proyecto> <tipo>
  --name "Nombre de la métrica"
  --description "Descripción detallada"
  --unit "unidad de medida"
  --baseline "valor inicial"
  --target "valor objetivo"
  --sdg "numero ODS (1-17)"
  --source "fuente de datos"
```

Tipos: `output` (conteos directos), `outcome` (cambios conductuales), `impact` (cambios sistémicos)

Almacena en `projects/{proyecto}/impact/metrics/` con ID secuencial IMP-NNN.

### log
Registra una medición periódica de una métrica existente.

```
impact-metric log <proyecto> <metric-id>
  --date "YYYY-MM-DD"
  --value "valor medido"
  --source "referencia de fuente"
  --notes "observaciones adicionales"
```

Valida que el valor esté dentro de rangos razonables.

### report
Genera reporte de impacto para un período específico.

```
impact-metric report <proyecto> [--start YYYY-MM-DD] [--end YYYY-MM-DD]
  [--audience "donors|board|public"]
  [--format "html|pdf|markdown"]
```

Formatos personalizados según audiencia:
- `donors`: énfasis en ROI y resultabilidad
- `board`: análisis de tendencias y riesgos
- `public`: narrativa de impacto accesible

### dashboard
Muestra tablero interactivo con todas las métricas de un proyecto.

```
impact-metric dashboard <proyecto>
  [--filter "sdg|active|behind-target"]
  [--detail]
```

Visualiza progreso hacia metas con indicadores de estado.

### export
Exporta datos de métricas a CSV o informe formateado.

```
impact-metric export <proyecto> <metric-id>
  --format "csv|json|excel"
  [--date-range "YYYY-MM-DD:YYYY-MM-DD"]
```

## Alineación ODS

Las métricas se vinculan con los 17 Objetivos de Desarrollo Sostenible de la ONU:

- 1-5: Personas (pobreza, hambre, salud, educación, género)
- 6-12: Planeta (agua, energía, empleo, industria, consumo)
- 13-17: Paz (clima, vida, paz, justicia, alianzas)

## Estructura de Datos

```yaml
# projects/{proyecto}/impact/metrics/IMP-001.yml
id: IMP-001
type: outcome
name: "Tasa de empleo postformación"
description: "Porcentaje de egresados con empleo formal 6 meses después"
unit: "%"
baseline: 45
target: 75
sdg: 8  # Trabajo decente
data_source: "Encuesta de seguimiento telefónica"
created: 2026-03-06
measurements:
  - date: 2026-02-28
    value: 52
    source: "Q1 2026"
    notes: "Mejora respecto a baseline"
```

## Privacidad y Ética

- No almacenar datos personales de individuos
- Agregar datos a nivel de cohorte mínima (n≥10)
- Reportes públicos sin información identificable
- Respetar marcos de protección de datos locales
