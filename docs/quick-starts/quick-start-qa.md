# Quick Start — QA

> 🦉 Hola, QA. Soy Savia. Te ayudo con planes de pruebas, cobertura, regresión y quality gates. La calidad es mi obsesión tanto como la tuya.

---

## Primeros 10 minutos

```
/qa-dashboard MiProyecto
```
Panel de calidad: cobertura actual, tests flaky, bugs abiertos y escape rate.

```
/testplan-generate --sprint
```
Genero un plan de pruebas basado en los items del sprint actual y sus specs SDD.

```
/qa-regression-plan --pr {número}
```
Analizo el impacto de los cambios de un PR y recomiendo qué tests ejecutar.

---

## Tu día a día

**Al empezar el sprint** — `/testplan-generate --sprint` para tener el plan de pruebas desde el día 1. Cada spec SDD ya define los criterios de aceptación.

**Ante cada PR** — `/qa-regression-plan --pr {n}` calcula qué tests son necesarios. El code review automático ya verifica reglas de dominio.

**Cuando llegan bugs** — `/qa-bug-triage {bug-id}` clasifica por severidad y detecta duplicados.

**Mitad de sprint** — `/qa-dashboard --trend` para ver tendencias. Si la cobertura baja o los flaky tests suben, es momento de actuar.

**Al cerrar sprint** — `/testplan-results` consolida los resultados. Estos datos alimentan el informe de dirección.

---

## Cómo hablarme

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Cómo está la calidad?" | `/qa-dashboard` |
| "Genera un plan de pruebas" | `/testplan-generate` |
| "¿Qué tests necesita este PR?" | `/qa-regression-plan --pr` |
| "Clasifica este bug" | `/qa-bug-triage {id}` |
| "¿Hay tests flaky?" | `/qa-dashboard --trend` |
| "¿La spec cubre todos los casos?" | `/spec-verify {spec}` |

---

## Dónde están tus ficheros

```
output/
├── testplans/          ← planes de pruebas generados
├── test-results/       ← resultados consolidados
└── reports/            ← informes de calidad

.claude/
├── commands/
│   ├── qa-*.md         ← dashboard, regression, bug triage
│   ├── testplan-*.md   ← generación y seguimiento de testplans
│   └── spec-verify*.md ← verificación de specs
├── commands/check-coherence.md ← validación de coherencia spec↔implementación
└── rules/domain/
    └── eval-criteria.md ← criterios de evaluación (tipo: code)
```

---

## Cómo se conecta tu trabajo

Los specs SDD definen los criterios de aceptación que tú verificas. Cuando un agente implementa, los tests que genera siguen esos criterios. Tu `/qa-dashboard` agrega cobertura y escape rate, que alimentan las métricas DORA (change failure rate). Si un quality gate falla, bloquea el merge — eso lo ven el Tech Lead y el PM. Los resultados de tus testplans aparecen en el `/report-executive` que recibe dirección.

---

## Siguientes pasos

- [Spec-Driven Development](../readme/05-sdd.md)
- [KPIs y reglas](../readme/10-kpis-reglas.md)
- [Guía de flujo de datos](../data-flow-guide-es.md)
- [Comandos completos](../readme/12-comandos-agentes.md)
