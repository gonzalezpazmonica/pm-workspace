# Algoritmo de Mapping: Cuestionario → equipo.md

## Objetivo

Convertir las respuestas del cuestionario de competencias (secciones A, B, C) en el campo `expertise` del archivo `equipo.md` que usa el algoritmo de asignación de pm-workspace.

## Entrada

Respuestas del cuestionario: 12 competencias técnicas (A1-A12), 7 transversales (B1-B7), N de dominio (C1-Cn). Cada una con nivel (1-5) e interés (S/N).

## Algoritmo

### Paso 1 — Calcular expertise por módulo del proyecto

Cada módulo del proyecto tiene un conjunto de competencias relevantes. El `expertise[módulo]` es la **media aritmética** de los niveles de las competencias que aplican a ese módulo.

```
PARA CADA módulo del proyecto:
    competencias_relevantes = mapeo_modulo_competencias[módulo]
    niveles = [respuesta.nivel PARA CADA c EN competencias_relevantes]
    expertise[módulo] = REDONDEAR(MEDIA(niveles), 1 decimal)
```

### Paso 2 — Definir el mapeo módulo → competencias

El Tech Lead o Architect define qué competencias aplican a cada módulo. Ejemplo para un proyecto clínico:

| Módulo | Competencias relevantes | Razonamiento |
|--------|------------------------|--------------|
| pacientes | A1, A2, A3, A4, A8, C1 | CRUD completo con queries EF Core |
| citas | A1, A2, A3, A4, A5, A8, C2 | Incluye validaciones complejas |
| facturacion | A1, A2, A4, A9, A10, C3 | SQL avanzado + seguridad |
| testing | A6, A7 | Exclusivamente competencias de test |
| integraciones | A8, A10, A12, C4 | APIs externas + CI/CD |

**Si no hay mapeo definido:** usar la media de A1-A8 como `expertise` general del módulo (sin competencias de dominio C).

### Paso 3 — Identificar growth_areas

```
growth_areas = []
PARA CADA competencia CON interes = "Sí" Y nivel < 3:
    growth_areas.AÑADIR(nombre_competencia)
```

Las growth_areas alimentan el factor `crecimiento × 0.10` del algoritmo de asignación. Cuando un miembro tiene un módulo en su growth_areas, el algoritmo puede asignarle tasks de ese módulo para que crezca (si el peso de growth lo permite).

### Paso 4 — Calcular expertise transversal (opcional)

Para roles que requieren competencias transversales (Tech Lead, QA Lead):

```
expertise_transversal = REDONDEAR(MEDIA(B1, B2, ..., B7), 1 decimal)
```

Este valor no entra directamente en el scoring de asignación pero informa al PM sobre capacidad de mentoring (B6), estimación (B5) y comunicación (B4).

## Output: formato equipo.md

```yaml
miembros:
  - nombre: "Laura Sánchez"
    role: "Full Stack"
    horas_dia: 7.5
    expertise:
      pacientes: 4.2      # Media de A1(5), A2(4), A3(4), A4(5), A8(4), C1(3)
      citas: 3.1           # Media de A1(5), A2(4), A3(4), A4(5), A5(2), A8(4), C2(1)
      facturacion: 2.0     # Media de A1(5), A2(4), A4(5), A9(1), A10(1), C3(1)
      testing: 4.5         # Media de A6(5), A7(4)
      integraciones: 2.8   # Media de A8(4), A10(1), A12(3), C4(3)
    growth_areas:
      - facturacion        # Interés=Sí, nivel<3
      - seguridad          # A10: Interés=Sí, nivel=1
    ultima_evaluacion: "2026-02-26"
```

## Compatibilidad con el algoritmo de asignación

El campo `expertise[módulo]` alimenta directamente el componente `match_expertise` de la fórmula de `assignment-scoring.md`:

```
score = expertise × 0.40 + disponibilidad × 0.30 + balance × 0.20 + crecimiento × 0.10
```

Donde:
- `expertise` (0.40): se busca `expertise[módulo_de_la_task]` en equipo.md
- `crecimiento` (0.10): si el módulo está en `growth_areas`, el factor se incrementa

La tabla de match_expertise de `assignment-scoring.md` mapea el nivel 1-5 a un factor 0.2-1.0.

## Validaciones

- Todos los niveles deben estar en rango 1.0 - 5.0
- Si un módulo tiene 0 competencias relevantes, no generar entrada en expertise
- Si el trabajador no completa la sección C (dominio), todos los módulos de dominio inician en 1.0
- Redondear siempre a 1 decimal (4.166... → 4.2)

## Frecuencia de actualización

- **Primera evaluación:** al incorporarse (Fase 4 del onboarding)
- **Trimestral:** autoevaluación rápida (≤15 min, solo cambios significativos)
- **Anual:** revisión completa con Tech Lead
- **Puntual:** tras formación significativa o liderazgo de módulo nuevo
