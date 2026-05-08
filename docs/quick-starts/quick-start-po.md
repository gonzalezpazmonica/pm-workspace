# Quick Start — Product Owner

> 🦉 Hola, Product Owner. Soy Savia. Te ayudo a medir el impacto de lo que entregas, gestionar stakeholders y mantener el backlog alineado con la estrategia. Aquí tienes lo esencial.

---

## Primeros 10 minutos

```
/value-stream-map --bottlenecks
```
Mapeo el flujo de valor end-to-end y detecto cuellos de botella. Verás dónde se pierde tiempo.

```
/backlog-prioritize --strategy-aligned
```
Priorizo el backlog alineándolo con los objetivos estratégicos (OKRs si están definidos).

```
/feature-impact --roi
```
Analizo el impacto de las features entregadas: ROI estimado, engagement y carga técnica generada.

---

## Tu día a día

**Al empezar el sprint** — `/backlog-groom --top 10` revisa los 10 items más prioritarios. `/pbi-decompose` descompone los que están listos para desarrollo.

**Semanal** — `/stakeholder-report` genera el informe para stakeholders con métricas de entrega y alineación de objetivos.

**Antes de release** — `/release-readiness` verifica que todo está listo: capacidad técnica, riesgos mitigados, comunicación preparada.

**Cada sprint** — `/outcome-track --release` registra los resultados de negocio de lo entregado. Esto es lo que demuestra valor.

**Trimestralmente** — `/okr-track --trend` revisa el progreso de los OKRs. `/strategy-map` visualiza dependencias entre iniciativas.

---

## Cómo hablarme

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Qué priorizo en el backlog?" | `/backlog-prioritize` |
| "¿Cuál es el impacto de esta feature?" | `/feature-impact` |
| "Prepara el informe para stakeholders" | `/stakeholder-report` |
| "¿Estamos listos para la release?" | `/release-readiness` |
| "Descompón este PBI" | `/pbi-decompose {id}` |
| "¿Dónde perdemos tiempo en el flujo?" | `/value-stream-map --bottlenecks` |

---

## Dónde están tus ficheros

```
output/
├── reports/           ← informes de stakeholders, feature impact
├── backlog-snapshots/ ← snapshots del estado del backlog
└── okr-tracking/      ← seguimiento de OKRs

.opencode/commands/
├── backlog-*.md       ← groom, prioritize, patterns
├── feature-*.md       ← feature impact analysis
├── stakeholder-*.md   ← reporting para stakeholders
├── okr-*.md           ← definición y tracking de OKRs
└── release-*.md       ← readiness checks
```

---

## Cómo se conecta tu trabajo

Los PBIs que priorizas se descomponen en tasks que el equipo implementa. La velocity de esos items alimenta el sprint forecast del PM. El feature impact que mides se agrega en el portfolio overview del CEO. Los OKRs que defines alinean el backlog con la estrategia, y el value stream map muestra si el flujo es eficiente. Si detectas un cuello de botella, eso se traduce en acciones concretas para el Tech Lead (deuda técnica) o el PM (redistribución de carga).

---

## Siguientes pasos

- [Sprints e informes](../readme/04-uso-sprint-informes.md)
- [Flujo de datos](../data-flow-guide-es.md)
- [Guías por escenario](../guides/README.md)
- [Comandos completos](../readme/12-comandos-agentes.md)
