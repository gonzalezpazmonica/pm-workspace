# Intent Catalog — NL → Command Mapping

> Referencia para resolución NL. Carga por `/nl-query` y regla `nl-command-resolution.md`.

## Formato

| intent_pattern | command | confidence | category |

---

## Sprint & Reporting

| ¿cómo va el sprint? / sprint status | /sprint-status | 90 | sprint |
| ¿llegaremos a tiempo? / will we make it? | /risk-predict | 85 | sprint |
| planificar siguiente sprint / plan next sprint | /sprint-autoplan | 92 | sprint |
| cerrar sprint / close sprint | /sprint-close | 90 | sprint |
| informe sprint / sprint report | /sprint-report | 90 | sprint |
| velocidad del equipo / team velocity | /sprint-velocity | 88 | sprint |
| burndown / gráfica avance | /sprint-burndown | 88 | sprint |
| daily / standup / resumen diario | /daily-generate | 90 | sprint |
| daily del equipo / team standup | /daily-team | 88 | sprint |
| previsión entrega / delivery forecast | /sprint-forecast | 85 | sprint |

## PBI & Discovery

| crear historia / new user story | /pbi-create | 92 | pbi |
| detalle de item / item detail | /pbi-detail | 90 | pbi |
| priorizar backlog / prioritize | /backlog-prioritize | 88 | pbi |
| grooming / refinar backlog | /backlog-groom | 88 | pbi |
| patrones del backlog / backlog patterns | /backlog-patterns | 85 | pbi |
| descomponer historia / decompose story | /pbi-decompose | 85 | pbi |

## SDD & Specs

| generar spec / specification | /spec-create | 93 | sdd |
| revisar spec / spec review | /spec-review | 90 | sdd |
| estado specs / spec status | /spec-status | 88 | sdd |
| arquitectura / architecture decision | /arch-detect | 85 | sdd |

## Quality & PRs

| revisar PR / review pull request | /pr-review | 92 | quality |
| crear PR / create pull request | /pr-create | 90 | quality |
| PRs pendientes / pending PRs | /pr-pending | 88 | quality |
| cobertura / coverage status | /coverage-status | 85 | quality |

## Team

| carga equipo / team workload | /team-workload | 90 | team |
| capacidad / team capacity | /team-capacity | 88 | team |
| burnout / fatiga equipo / team burnout | /burnout-radar | 88 | team |
| ¿quién está bloqueado? / who is blocked | /sprint-status --blocked | 88 | team |

## Memory & Context

| guardar en memoria / save memory | /memory-save | 90 | memory |
| buscar en memoria / search memory | /memory-search | 90 | memory |
| contexto proyecto / project context | /memory-context | 86 | memory |
| consolidar sesión / consolidate session | /memory-consolidate | 85 | memory |
| recordar / recall | /savia-recall | 88 | memory |
| estadísticas memoria / memory stats | /memory-stats | 85 | memory |
| grafo memoria / memory graph | /memory-graph | 83 | memory |

## Messaging & Inbox

| bandeja entrada / inbox | /savia-inbox | 90 | messaging |
| enviar mensaje / send message | /savia-send | 88 | messaging |
| anuncio empresa / company announce | /savia-announce | 85 | messaging |

## Company Savia

| directorio / company directory | /savia-directory | 88 | company |
| mi perfil / my profile | /savia-profile | 85 | company |
| organigrama / org chart | /savia-org-chart | 85 | company |

## Flow & Board

| tablero / kanban board | /savia-board | 90 | flow |
| asignar tarea / assign task | /savia-flow-assign | 88 | flow |
| registrar horas / log time / timesheet | /savia-flow-timesheet | 88 | flow |
| crear tarea / create task | /savia-flow-create | 88 | flow |

## Infra & DevOps

| estado deploy / deploy status | /pipeline-status | 92 | infra |
| logs del sistema / system logs | /infra-logs | 85 | infra |
| salud sistema / system health | /infra-health | 88 | infra |

## Diagrams

| generar diagrama / draw diagram | /diagram-generate | 90 | diagrams |
| diagrama arquitectura / arch diagram | /diagram-architecture | 88 | diagrams |

## Governance

| auditoría / governance audit | /governance-audit | 88 | governance |
| cumplimiento AEPD / AEPD compliance | /aepd-compliance | 88 | governance |

## Utilities

| ayuda / help / ¿qué puedes hacer? | /help | 95 | util |
| cargar contexto / load context | /context-load | 86 | util |
| salud contexto / context health | /context-health | 85 | util |
| informe excel / excel report | /excel-report | 88 | util |

---

## Patrones Coloquiales

| dame un resumen rápido / quick summary | /sprint-report --format brief | 82 | sprint |
| ¿hay problemas? / any issues? | /risk-predict | 83 | sprint |
| ¿cuánta deuda? / how much debt? | /debt-summary | 85 | quality |
| ¿qué hizo Ana ayer? / what did Ana do? | /daily-generate --person Ana | 80 | sprint |
| resume la retro / retro summary | /meeting-summarize --type retro | 82 | sprint |
| próximo qué hacer / what's next | /sprint-autoplan | 85 | sprint |

---

## Calibración

- **Base**: 70-95% (del catálogo)
- **Bonus contexto**: +0-5% (proyecto/sprint resueltos)
- **Bonus historial**: +0-3% (mapeo previo exitoso en memoria)
- **Penalización**: -10-15% (ambigüedad, negación)

Umbrales: <50% sugerir top 3 | 50-79% confirmar | ≥80% ejecutar directo.

Ver `nl-command-resolution.md` para lógica detallada.
