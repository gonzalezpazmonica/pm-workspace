# Quick Start — Developer

> 🦉 Hola, Developer. Soy Savia. Te ayudo a saber qué hacer, implementar specs, ejecutar tests y mantener el foco. Tu sprint, tu código, tu ritmo.

---

## Primeros 10 minutos

```
/my-sprint
```
Tu vista personal del sprint: items asignados, estado, cycle time y prioridad.

```
/my-focus
```
Identifico tu item más prioritario y cargo todo su contexto (spec, ficheros relacionados, decisiones previas).

```
/code-patterns
```
Los patterns del proyecto con ejemplos reales del código existente. Útil si acabas de incorporarte.

---

## Tu día a día

**Al empezar** — `/my-focus` para saber por dónde seguir. Si hay una spec SDD asignada, ya tengo todo el contexto cargado.

**Al implementar** — `/spec-implement {spec}` lanza el flujo SDD: implemento handlers, repositorios y tests siguiendo la spec como contrato. Si prefieres hacerlo tú, la spec te dice exactamente qué ficheros crear y qué interfaces seguir.

**Al terminar un bloque** — `/spec-verify {spec}` verifica que la implementación cumple la spec. Los hooks pre-commit validan tamaño, schema y reglas de dominio automáticamente.

**Si te bloqueas** — `/memory-search {tema}` busca decisiones previas. `/entity-recall {componente}` recupera todo lo que sé de ese componente.

**Viernes** — `/my-learning` analiza tu código de la semana y detecta oportunidades de mejora.

---

## Cómo hablarme

| Tú dices... | Yo ejecuto... |
|---|---|
| "¿Qué tengo asignado?" | `/my-sprint` |
| "¿Qué hago ahora?" | `/my-focus` |
| "Implementa esta spec" | `/spec-implement {spec}` |
| "¿Pasan los tests?" | `/spec-verify {spec}` |
| "¿Cómo se hace X en este proyecto?" | `/code-patterns` + `/memory-search` |
| "¿Qué decidimos sobre el módulo auth?" | `/entity-recall auth-service` |
| "Revisa mi código" | `/spec-review {file}` |

---

## Dónde están tus ficheros

```
output/
├── specs/              ← specs SDD generadas (contratos ejecutables)
├── implementations/    ← código generado por agentes
└── .memory-store.jsonl ← memoria con decisiones y contexto

.claude/
├── agents/developer-*.md  ← agentes de implementación (usan worktrees)
├── commands/spec-*.md     ← comandos SDD
└── rules/language/        ← reglas del lenguaje de tu proyecto
```

Los agentes developer trabajan en worktrees aislados (`isolation: worktree`). Esto significa que pueden implementar en paralelo sin conflictos de merge. Cuando terminan, el código se integra vía PR.

---

## Cómo se conecta tu trabajo

Tu código empieza en una spec (`/spec-generate`). La spec define el contrato: qué hacer, qué interfaces seguir, qué tests pasar. Cuando implementas (tú o un agente), el code review automático verifica contra las reglas. Los tests actualizan la cobertura. La cobertura alimenta el QA dashboard. El cycle time de tus items alimenta la velocity del sprint, que el PM usa para forecasting. Si imputas horas, esas horas van a cost-management y de ahí a facturación.

---

## Desde el móvil

Con Savia Mobile puedes consultar tu sprint, preguntar por specs o revisar decisiones de diseño desde el móvil. Útil en reuniones o cuando estás lejos del terminal. Setup: `projects/savia-mobile-android/docs/BRIDGE-GUIDE.md`

---

## Siguientes pasos

- [Spec-Driven Development](../readme/05-sdd.md)
- [Estructura del workspace](../readme/02-estructura.md)
- [Guía de flujo de datos](../data-flow-guide-es.md)
- [Comandos completos](../readme/12-comandos-agentes.md)
- [Savia Mobile](../../projects/savia-mobile-android/README.md)
