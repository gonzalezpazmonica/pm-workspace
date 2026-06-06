---
name: design-an-interface
description: "Skill para disenar una interfaz con N=3 alternativas en paralelo y recomendar la mejor segun vocabulario arquitectonico del proyecto."
maturity: stable
context: fork
context_cost: medium
category: "architecture"
tags: ["architecture", "interface-design", "parallel-agents", "sdd"]
priority: "high"
---

# Skill: Design an Interface

Genera 3 disenos alternativos de interfaz en paralelo y consolida en tabla comparativa con recomendacion justificada.

## Authoritative Paths

> Lee estos paths antes de actuar.

| Para | Lee este path |
|---|---|
| Vocabulario arquitectonico | `docs/rules/domain/architectural-vocabulary.md` |
| Codigo existente del proyecto | `projects/<nombre>/` |
| Specs SDD activas | `docs/propuestas/SPEC-*.md` |
| Reglas de dominio | `docs/rules/domain/` |

## Cuando usar

- Se necesita disenar una interfaz nueva para un modulo y no hay precedente claro.
- Se quiere comparar enfoques antes de comprometerse con uno.
- La spec SDD requiere definicion de interfaz antes de implementar.

## Cuando NO usar

- La interfaz ya existe y solo necesita extension — leer el codigo y ampliar.
- El scope es un metodo privado o una funcion de utilidad (demasiado granular).
- La interfaz tiene un patron establecido en el proyecto — seguir el patron existente.

## Decision Checklist

1. El modulo esta definido con nombre y contexto de uso? Si NO: solicitar antes de continuar.
2. Hay restricciones conocidas (rendimiento, compatibilidad, framework)? Si NO: asumir ninguna y documentarlo.
3. Existe codigo relacionado en el proyecto? Si SI: designar como base para Diseno C.

### Abort Conditions

- Si el nombre del modulo es vago o el contexto insuficiente: pedir aclaracion y abortar.
- Si las restricciones implican un unico diseno posible: no lanzar alternativas, documentar la restriccion.

## Workflow

```
Recibir: modulo + contexto + restricciones
    |
Lanzar 3 sub-agentes en paralelo (Task tool)
    |
Consolidar en tabla comparativa
    |
Recomendar con justificacion
```

### Sub-agentes en paralelo

Lanzar los tres en el mismo mensaje via Task tool (sin dependencias entre ellos):

**Sub-agente A — Maxima simplicidad**
- Filosofia: minimo de metodos, sin estado, maxima facilidad de uso.
- Produce: nombre de interfaz, lista de metodos con tipos, invariantes, trade-offs.

**Sub-agente B — Maxima flexibilidad**
- Filosofia: extensible, plugin-friendly, facil de mockear en tests.
- Produce: nombre de interfaz, lista de metodos con tipos, invariantes, trade-offs.

**Sub-agente C — Pragmatico**
- Filosofia: equilibrio entre A y B, inspirado en codigo existente del proyecto.
- Produce: nombre de interfaz, lista de metodos con tipos, invariantes, trade-offs.

### Formato de output de cada sub-agente

```
Interface: <NombreInterfaz>
Methods:
  - <metodo>(<param>: <tipo>): <retorno>
Invariants:
  - <descripcion>
Trade-offs:
  + <ventaja>
  - <desventaja>
```

### Consolidacion

Tabla comparativa con columnas: Criterio | Diseno A | Diseno B | Diseno C.
Criterios minimos: numero de metodos, estado requerido, testabilidad, extension futura, coherencia con codigo existente.

### Recomendacion

Un parrafo usando vocabulario de `docs/rules/domain/architectural-vocabulary.md`:
- **Module**, **Interface**, **Seam**, **Depth**, **Leverage**, **Locality**.
- Justificar por que el diseno elegido maximiza Depth y Locality para el contexto dado.

## Outputs esperados

- Tabla comparativa de los 3 disenos.
- Recomendacion con justificacion en vocabulario arquitectonico.
- Opcionalmente: fichero `docs/propuestas/<modulo>-interface-design.md` si se requiere trazabilidad.

## Memory hooks

- Diseno completado: guardar en memoria con tipo decision y titulo "interface design: modulo".

## Related

- Rule: `docs/rules/domain/architectural-vocabulary.md`
- Skill: `.opencode/skills/spec-driven-development/SKILL.md`
- Agent: `.opencode/agents/architect.md`
- Roadmap: `docs/ROADMAP.md`
