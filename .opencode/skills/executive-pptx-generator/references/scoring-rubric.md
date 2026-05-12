# Scoring Rubric — 8 dimensiones, 100 puntos

> Score mínimo aceptable para entrega a directivo: **95/100**.

## Aplicación

1. Renderizar PPTX a PNG (o leer XML) y abrir visualmente.
2. Por cada dimensión, asignar puntos según criterios.
3. Listar findings priorizados (CRITICAL <50% / HIGH <80% / MEDIUM <100%).
4. Si score <95 → iterar. No entregar.

## Dimensiones

### 1. Pyramid principle — 20 pts

- Idea principal en título (10): SÍ todos los slides / parcial / NO
- Soporte coherente con título (10): SÍ / parcial / NO

Resta:
- Slide con título "genérico" tipo "Resumen": -5
- Slide donde el body contradice o ignora el título: -10

### 2. Una idea por slide — 15 pts

- 0 slides "mixtos" (15) — cada slide se puede resumir en 1 frase.
- 1 slide mixto: 10
- 2+ slides mixtos: 5
- >3: 0

### 3. Jerarquía tipográfica — 15 pts

- 3 niveles claros (título 28pt / subtítulo 15pt / body 12-14pt): 15
- 2 niveles: 8
- 1 nivel: 0

Resta:
- Body >16pt (parece colegio): -5
- Título <22pt (no destaca): -5

### 4. Imágenes/iconos — 15 pts

- Cada slide tiene visual relevante (15)
- 1-2 slides solo-texto: 10
- 3+ slides solo-texto: 5
- Mayoría solo-texto: 0

Resta:
- Icono decorativo sin relación con contenido: -3 por icono

### 5. Paleta consistente — 10 pts

- 0 colores fuera de paleta cliente: 10
- 1-2 colores extra (justificados): 7
- 3+ colores aleatorios: 3
- Caos cromático: 0

### 6. Titulares afirmativos — 10 pts

- Todos verbos presente + punto: 10
- 1-2 títulos genéricos: 6
- 3+: 3
- Mayoría genéricos: 0

### 7. Densidad informativa — 10 pts

- Ni vacío ni saturado: 10
- 1-2 slides con problema de densidad: 7
- 3+ con problema: 3
- Densidad caótica: 0

Indicador rápido:
- Vacío: <20% área cubierta con contenido relevante.
- Saturado: >80% área cubierta.

### 8. Cero marketing — 5 pts

- 0 frases vacías: 5
- 1-2 leves: 3
- 3+ o "revolucionario/disruptivo": 0

## Plantilla de informe de score

```markdown
# Score: NN/100 — [APROBADO ≥95 / RECHAZADO <95]

| Dimensión | Score | Notas |
|---|---:|---|
| Pyramid | XX/20 | ... |
| Una idea | XX/15 | ... |
| Jerarquía | XX/15 | ... |
| Visuales | XX/15 | ... |
| Paleta | XX/10 | ... |
| Titulares | XX/10 | ... |
| Densidad | XX/10 | ... |
| Cero mkt | XX/5 | ... |
| **TOTAL** | **NN/100** | |

## Findings priorizados

### CRITICAL (bloquean entrega)
- [Slide N] descripción · fix propuesto

### HIGH
- ...

### MEDIUM
- ...
```

## Checklist final pre-entrega

- [ ] Score ≥95
- [ ] PPTX abre sin errores en PowerPoint del cliente
- [ ] Fuentes Aptos fallback Calibri verificadas
- [ ] No hay placeholders ("Lorem ipsum", "TBD")
- [ ] No hay screenshots con datos N4b visibles
- [ ] Footer correcto (autor, fecha, cliente)
- [ ] Tamaño <15 MB (envío email)
