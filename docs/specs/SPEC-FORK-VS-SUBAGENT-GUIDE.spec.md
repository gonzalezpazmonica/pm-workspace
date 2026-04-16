# Spec: Fork vs Subagent Guide — Arbol de decision y documentacion

**Task ID:**        SPEC-FORK-VS-SUBAGENT-GUIDE
**PBI padre:**      Agent orchestration clarity (research: claude-code-from-source)
**Sprint:**         2026-15
**Fecha creacion:** 2026-04-10
**Creado por:**     Savia (research: claude-code-from-source Ch08/Ch10)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     2h
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Max turns:**      15
**Modelo:**         claude-sonnet-4-6

---

## 1. Contexto y motivacion

Claude Code nativo distingue dos patrones de orquestacion multi-agent:

- **Fork agents**: el child hereda el historial completo de la conversacion,
  system prompt y array de tools del padre. Objetivo: prefijos byte-identicos
  entre children paralelos para explotar prompt cache al 90%.
- **Subagents (Task tool)**: instancia Claude aislada con su propio context
  window. Lee ficheros en su contexto y retorna solo el resumen al padre.

pm-workspace usa Task (subagent) para cada invocacion multi-agent. Esto es
correcto cuando se busca aislamiento, pero es caro (sin cache) cuando N
invocaciones comparten prefijo. Los usuarios y agentes del workspace necesitan
un arbol de decision claro para elegir el patron adecuado en cada situacion.

Fuentes:
- https://claude-code-from-source.com/ch08-sub-agents/
- https://claude-code-from-source.com/ch10-coordination/

## 2. Objetivo

Documentar el arbol de decision fork vs subagent en
`docs/rules/domain/dev-session-protocol.md` y actualizar
`docs/rules/domain/handoff-templates.md` con una tabla comparativa y 5
ejemplos concretos de uso. Integrar con SPEC-FORK-AGENT-PREFIX.

## 3. Requisitos funcionales

- **REQ-01** Nueva seccion "Fork vs Subagent — Decision Tree" en
  `dev-session-protocol.md`.
- **REQ-02** Arbol de decision ASCII/texto con 4 preguntas clave:
  1. "¿N items similares con mismo prompt base?" → si → fork
  2. "¿Contexto contaminado o demasiado lleno?" → si → subagent
  3. "¿Necesita su propio state/tools?" → si → subagent
  4. "¿Se puede paralelizar ganando cache hit?" → si → fork
- **REQ-03** Tabla comparativa en `handoff-templates.md` con columnas: dimension,
  fork, subagent. Filas: contexto, aislamiento, cache, output, velocidad, coste.
- **REQ-04** 5 ejemplos concretos con snippets bash/markdown:
  1. Batch file analysis (10 .cs files) → fork
  2. Deep research (investigar un tema complejo) → subagent
  3. Security audit multi-file (scan N endpoints) → fork
  4. Architecture review (decidir patron) → subagent
  5. Parallel test run (ejecutar N test suites) → fork
- **REQ-05** Seccion "Anti-patterns" listando usos incorrectos:
  - Usar subagent para N items identicos (pierde cache)
  - Usar fork cuando el contexto del padre esta contaminado
  - Usar fork cuando cada item necesita state propio
- **REQ-06** Referencia cruzada con SPEC-FORK-AGENT-PREFIX y
  `fork-agent-protocol.md`.
- **REQ-07** El documento mantiene el formato y estilo del resto de reglas del
  workspace (frontmatter, max 150 lineas).

## 4. Criterios de aceptacion

- **AC-01** `grep -q "Fork vs Subagent" docs/rules/domain/dev-session-protocol.md` devuelve match.
- **AC-02** `grep -q "Fork.*Subagent.*Decision" docs/rules/domain/handoff-templates.md` devuelve match.
- **AC-03** Tabla comparativa incluye las 6 dimensiones (contexto, aislamiento, cache, output, velocidad, coste).
- **AC-04** Los 5 ejemplos tienen nombre, descripcion breve, decision (fork/subagent) y justificacion.
- **AC-05** Los ficheros modificados respetan el limite de 150 lineas (Rule #11).
- **AC-06** Test BATS `test-fork-vs-subagent-docs.bats` certificado por el auditor.

## 5. Test scenarios

1. **Presencia de seccion**: grep busca "Fork vs Subagent" en dev-session-protocol.md → debe matchear.
2. **Tabla comparativa**: grep busca headers de tabla markdown en handoff-templates.md.
3. **5 ejemplos**: cuenta numero de ejemplos (mediante headers en la seccion de ejemplos).
4. **Anti-patterns**: verifica presencia de seccion "Anti-patterns" con >=3 entradas.
5. **Max 150 lineas**: `wc -l` de los ficheros modificados.

## 6. Arquitectura / ficheros afectados

**Modificados:**
- `docs/rules/domain/dev-session-protocol.md`: +seccion "Fork vs Subagent"
- `docs/rules/domain/handoff-templates.md`: +tabla comparativa + referencia

**Nuevos:**
- `tests/test-fork-vs-subagent-docs.bats`

## 7. Ejemplo del arbol de decision (snippet)

```
                    +---------------------+
                    | Necesitas N agentes |
                    | paralelos           |
                    +----------+----------+
                               |
                +--------------+--------------+
                |                             |
         mismo prompt base?            contexto diferente?
                |                             |
           SI --+                             +-- SI
                |                                  |
                v                                  v
       +----------------+               +------------------+
       | FORK           |               | SUBAGENT         |
       | (cache 90%)    |               | (contexto fresco)|
       +----------------+               +------------------+
```

## 8. Fuera de alcance

- No implementa el helper `fork-agents.sh` (ver SPEC-FORK-AGENT-PREFIX).
- No modifica el comportamiento del Task tool (sigue funcionando igual).
- Solo documentacion y guia; no cambios de codigo runtime.

## 9. Referencias

- SPEC-FORK-AGENT-PREFIX (helper implementation)
- [claude-code-from-source Ch08](https://claude-code-from-source.com/ch08-sub-agents/)
- [claude-code-from-source Ch10](https://claude-code-from-source.com/ch10-coordination/)
- `docs/rules/domain/prompt-caching.md`
