---
name: retro-patterns
description: Análisis de patrones en retrospectivas — temas recurrentes, action items sin resolver
agent: task
context_cost: high
---

# /retro-patterns

> 🦉 Analiza patrones en retrospectivas: temas recurrentes, tendencias, action items no resueltos.

---

## Parámetros

- `--project {nombre}` — Proyecto (obligatorio)
- `--sprints {n}` — Últimos N sprints (defecto: 6)
- `--method {nlp|regex|manual}` — Categorización (defecto: nlp)
- `--action-items` — Enfoque en action items: resolución %, edad
- `--themes` — Enfoque en temas: frecuencia, evolución
- `--export {json|md}` — Formato (defecto: md)

---

## Contexto requerido

1. `projects/{proyecto}/CLAUDE.md` — Config proyecto
2. `projects/{proyecto}/retro-actions.md` — Histórico de actions
3. Retros en `projects/{proyecto}/retros/` o Azure DevOps

---

## Ejecución

### 1. Cargar historial (últimos N sprints)
- Ficheros: `retros/YYYY-NN.md`
- Azure DevOps: Work Items tipo "Retrospective"
- Compilar: {sprint, fecha, temas[], actions[]}

### 2. Analizar temas (NLP)
- Agrupar por similitud semántica
- Categorizar: Development, Process, Culture, Infrastructure, Other
- Calcular: frecuencia, tendencia (↑/→/↓), gravedad (alto/medio/bajo)

### 3. Analizar action items
- Status: done/in progress/pending/overdue
- Edad: sprint_origen → hoy
- Métricas: % completadas/sprint, edad promedio pending, overdue count

### 4. Detectar patrones sistémicos
- **Recurrencia** (3+ sprints) → elevar a iniciativa
- **Escalada** (↑ frecuencia) → intervención inmediata
- **Sin resolución** (>2 sprints) → deuda organizacional
- **Ciclo** (desaparece/reaparece) → raíz causa común

### 5. Generar informe
Salida en `output/retro-patterns/YYYYMMDD-patterns-{proyecto}.md`:
- Temas agrupados por criticidad (🔴/🟡/🟢)
- Tabla de action items sin resolver
- Tendencia resolución por sprint
- Recomendaciones por plazo (corto/medio/largo)
- Export opcional a JSON

---

## Integración

- `/sprint-retro` → sugerir `/retro-patterns --sprints 1` al finalizar
- `/health-dashboard` → incluir patrones detectados
- `/project-audit` → usar score resolución como indicador

---

## Restricciones

- Read-only: NUNCA modificar items automáticamente
- Recomendaciones son sugerencias
- NLP puede tener falsos positivos → validar con PM
