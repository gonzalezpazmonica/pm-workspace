# TDD vertical-slices — Dominio

## Por qué existe esta skill

pm-workspace tiene `test-architect`, `test-engineer` y `test-runner` agents, pero ninguno enuncia explícitamente el anti-pattern de horizontal slicing. El error es real y reincidente: cuando un agente Claude recibe una spec con N acceptance criteria, la tendencia natural es escribir N tests en bloque antes de implementar. Resultado: tests que verifican estructuras de datos en vez de behavior, brittle a refactor.

Este skill formaliza la disciplina vertical: **1 test → 1 implementation → repeat**. Es una regla de cabeza, no requiere infraestructura, sólo invocable cuando un agente o la usuaria aplica TDD.

## Conceptos de dominio

- **Tracer bullet**: el primer test que prueba que el path end-to-end funciona. Te da feedback inmediato sobre si el approach va a aguantar antes de invertir en N tests más.
- **Horizontal slicing (anti-pattern)**: tratar RED como "todos los tests" y GREEN como "todo el código". Produce tests-de-mentira.
- **Vertical slicing (pattern)**: red-green por behavior individual. Cada test informa el siguiente.
- **Behavior observable**: lo que un caller (o un test que cruza el seam público) puede observar. Se diferencia de "estado interno" (que NO se testea — es implementation detail).

## Reglas de negocio que implementa

- 1 test cada vez. NO batch.
- Sólo el código mínimo para pasar el test actual. NO anticipar futuros.
- Refactor sólo en GREEN, nunca en RED.
- Tests describen behavior, no estructura de datos ni signatures.
- Si un test se rompe en un refactor donde el behavior no cambia, el test estaba mal cortado.

## Relación con otras skills

- **Upstream**: SE-082 architectural-vocabulary (Module/Interface/Seam/Adapter) — vocabulario que aplica cuando diseñas la interface antes de escribir el primer test.
- **Downstream**: `test-architect` agent (genera suites) — consulta este skill antes de generar tests para asegurar disciplina vertical.
- **Downstream**: `test-engineer` agent (ejecuta tests) — sin acoplamiento directo; ejecuta lo que llegue.
- **Adyacente**: `test-runner` agent (post-commit gate) — sin acoplamiento; verifica suite tras commits.

## Decisiones clave

- **NO sustituye al flujo SDD existente**: TDD aplica DENTRO de un slice ya specced, no como reemplazo de la spec.
- **NO impone TDD universal**: aplica a behavior nuevo. Specs sin behavior testable (docs, configs) no aplican.
- **Anti-pattern explícito**: la prosa nombra el horizontal-slicing con "DO NOT" — lección sharp documentada.
- Atribución MIT a `mattpocock/skills/tdd/SKILL.md`.

## Limitaciones conocidas

- No aplica a structure-tests del workspace (verifican muchos files a la vez por diseño — ratchet) — la disciplina vertical es para TDD de behavior nuevo, no para tests structural.
- No detecta automáticamente si el agente está cayendo en horizontal slicing — depende de que el agente invoque el skill al inicio de un ciclo TDD.
- Requiere que los tests tengan un seam claro con la public interface; código legacy sin seams puede necesitar refactor antes (test-architect lo identificará).
