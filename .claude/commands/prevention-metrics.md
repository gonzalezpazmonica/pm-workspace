---
name: "prevention-metrics"
description: "Métricas de prevención: bugs prevenidos vs encontrados, shift-left effectiveness, early detection rate. Paradigma QA de prevención sobre detección."
developer_type: all
agent: task
---

# /prevention-metrics

**QA Preventivo: Bugs Prevenidos antes de Detectados**

Mide la efectividad de tu estrategia shift-left. Cambio de paradigma: de "encontrar bugs en QA" a "prevenir bugs en desarrollo".

## Sintaxis

```
/prevention-metrics [--dashboard] [--trend] [--compare] [--lang es|en]
```

## Paradigma Shift

**Modelo Reactivo** (caro):
Código → QA Testing → Bug Found (costo 10-100x fix)

**Modelo Preventivo** (eficiente):
Código → Static Analysis → Code Review → Unit Tests → CI Gates → Nunca llega QA

Bugs PREVENIDOS: static analysis, pre-commit hooks, code review, TDD, CI gates
Bugs ENCONTRADOS: llegan a QA (fracaso de prevención)
Bugs ESCAPADOS: llegan a producción (fracaso total)

## Opciones

- `--dashboard`: Actual prevention vs. detection para este sprint
- `--trend`: Tendencias últimas 6 sprints + análisis drivers
- `--compare`: Benchmarks industria vs. tu equipo
- `--lang es|en`: Idioma del reporte

## /prevention-metrics --dashboard

Output: 
- Total prevenidos (desglose por: static, pre-commit, review, tests, CI)
- Total encontrados en QA
- Total escapados a producción
- Prevention Rate = Prevenidos / (Prevenidos + Encontrados + Escapados)
- Shift-Left Effectiveness = (Static + Pre-commit + Review) / Total prevenidos
- Early Detection Rate = (Static + Pre-commit) / Total prevenidos
- Cost analysis: costo por etapa × bugs, ahorro total vs. sin prevención

## /prevention-metrics --trend

Histórico 6 sprints con:
- Prevention rate trend (target: >90%)
- Early detection trend (target: >50%)
- Escape rate trend (target: <0.5%)
- Cost savings acumulativo
- Drivers de mejora (qué cambió)
- Próximos focos

## /prevention-metrics --compare

Compara tu equipo vs. industria:
- Prevention: tu 93.8% vs. industria 75-85%, benchmark 95%+
- Early Detection: tu 55% vs. industria 40-50%, benchmark 70%+
- Escape Rate: tu 0.74% vs. industria 1-3%, benchmark <0.5%
- Posición en percentiles (top 20%, etc.)

## Componentes de Prevención

1. **Static Analysis** (SonarQube, eslint): violaciones detectadas automáticamente
2. **Pre-Commit Hooks**: formato, lint, type safety, forbidden patterns
3. **Code Review**: lógica, diseño, edge cases, seguridad
4. **Unit Testing**: boundary conditions, state transitions, error handling
5. **CI/CD Gates**: build, tests, security scans

## Persona Savia

He visto equipos que pasan horas cazando bugs en QA cuando la verdadera magia es evitarlos. Ese cambio mental — de "encontrar bugs" a "nunca escribirlos" — te libera. Las métricas de prevención te muestran dónde eres fuerte y dónde hay grietas. 🦉

---

**Versión**: v0.66.0 | **Grupo**: dx-metrics | **Era**: 12 — Team Excellence & Enterprise
