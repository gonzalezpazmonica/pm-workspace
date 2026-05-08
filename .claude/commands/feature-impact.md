---
name: feature-impact
description: Análisis de impacto de features — esfuerzo vs valor, ROI, priorización
developer_type: all
agent: task
context_cost: high
---

# /feature-impact

> 🦉 Savia analiza qué features aportan más valor por esfuerzo invertido.

---

## Cargar perfil de usuario

Grupo: **Reporting** — cargar:

- `identity.md` — nombre, rol
- `preferences.md` — language, detail_level, report_format
- `projects.md` — proyecto target
- `tone.md` — formality

---

## Subcomandos

- `/feature-impact` — análisis completo de features del sprint/release actual
- `/feature-impact --epic {nombre}` — impacto de un epic específico
- `/feature-impact --roi` — ranking por retorno de inversión estimado
- `/feature-impact --compare` — comparar features planificadas vs entregadas

---

## Flujo

### Paso 1 — Recopilar features y métricas

Para cada feature/epic del backlog o release:

1. Esfuerzo real (story points o horas consumidas)
2. Esfuerzo estimado original
3. Valor de negocio (Business Value field o WSJF)
4. Estado actual (completada, en progreso, pendiente)
5. Dependencias y bloqueos

### Paso 2 — Calcular indicadores

```
📊 Feature Impact Analysis — {proyecto}

| Feature | Esfuerzo | Valor | ROI Score | Estado |
|---|---|---|---|---|
| {feature 1} | {SP} pts | {BV}/10 | ⭐ {roi} | ✅ Done |
| {feature 2} | {SP} pts | {BV}/10 | ⭐ {roi} | 🔄 WIP |
| {feature 3} | {SP} pts | {BV}/10 | ⭐ {roi} | 📋 Planned |

ROI Score = Business Value / Esfuerzo (normalizado 1-5 ⭐)
```

### Paso 3 — Análisis de desviaciones

```
📈 Desviaciones
  Features con mejor ROI: {top 3}
  Features sobreestimadas: esfuerzo real >> estimado
  Features infraestimadas: esfuerzo real << estimado
  Features de alto valor sin empezar: {lista}
  Features de bajo valor consumiendo recursos: {lista}
```

### Paso 4 — Recomendaciones del Product Owner

1. **Priorizar**: Features de alto valor y bajo esfuerzo
2. **Reevaluar**: Features de bajo valor con alto esfuerzo en curso
3. **Descartar**: Features con ROI < umbral y sin compromiso externo
4. **Dividir**: Features grandes en incrementos de valor entregable

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: feature_impact
project: sala-reservas
features_analyzed: 12
avg_roi_score: 3.2
top_roi_feature: "booking-calendar"
overestimated: 2
underestimated: 3
high_value_not_started: 1
```

---

## Restricciones

- **NUNCA** inventar Business Value — usar datos reales o pedir al PO
- **NUNCA** recomendar cancelar features con compromisos externos sin avisar
- ROI Score es orientativo, no reemplaza el juicio del Product Owner
- Presentar datos objetivamente — la decisión final es del PO
