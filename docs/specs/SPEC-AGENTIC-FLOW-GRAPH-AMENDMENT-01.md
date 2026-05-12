# Patch: SPEC-AGENTIC-FLOW-GRAPH-AMENDMENT-01

**Aplica a:**       SPEC-AGENTIC-FLOW-GRAPH (en estado Pendiente)
**Tipo:**           Enmienda al spec original, NO spec independiente.
**Fecha creación:** 2026-05-09
**Creado por:**     Mónica
**Inspirado por:**  achetronic/magec, decisión #28 (Flow-shared state and loop exit control). Concepto adoptado, código no.

**Estado:**         ✅ Aplicado 2026-05-10 — integrado a SPEC-AGENTIC-FLOW-GRAPH.spec.md (D-6/D-7/D-8 añadidas, §2.2/2.4/2.7/2.8 actualizadas, Slices 1-2 +1h cada una, riesgos ampliados).

---

## Motivación

Tras revisar Magec (plataforma multi-agente self-hosted publicada por achetronic, en activo desarrollo), dos decisiones técnicas suyas mejoran directamente el diseño actual del SPEC-AGENTIC-FLOW-GRAPH:

1. **CEL en lugar de jq** para evaluar las condiciones `when` de las aristas y los `exit_when` de los bucles.
2. **Namespacing de state compartido** para prevenir contaminación cruzada entre tipos de estado.

Ambos refinamientos son baratos de incorporar antes de implementar el SPEC, y caros de retrofitear después. Esta enmienda los integra al SPEC-AGENTIC-FLOW-GRAPH original.

---

## Cambio 1 — CEL como motor de evaluación de condiciones

### Lo que decía el SPEC original (sección 2.2)

```yaml
edges:
  - from: aggregate
    to: END
    when: "${state.verdict == 'approve'}"
```

Y en sección 2.4: *"La condición `when` es una expresión booleana sobre `${state.*}` y `${nodes.*.*}`, evaluada con `jq`."*

### Problema

`jq` es excelente para extracción de datos pero pobre como motor de evaluación de condiciones:

- Sintaxis booleana cruda: `and` / `or` en lugar de `&&` / `||`, sin operador `!=` consistente.
- No es schema-aware: nada impide que una condición devuelva un número en lugar de un bool y se evalúe como truthy.
- Funciones útiles (`has`, `size`, `contains`) existen pero con sintaxis irregular.
- Pensado para pipelines de transformación, no para evaluación condicional reproducible.

### Solución: CEL (Common Expression Language)

Magec usa CEL (de Google) por las razones que su decisión #28 documenta y que son aplicables aquí literalmente:

- Estándar de facto en Kubernetes, IAM, Envoy.
- Diseñado explícitamente para compile-once / evaluate-many.
- Thread-safe y libre de side-effects.
- Schema-aware: rechaza en compile-time expresiones que no devuelven bool.
- Expresivo (`==`, `!=`, `<`, `>`, `&&`, `||`, `!`, `has()`, `size()`, `.contains()`) pero NO Turing-completo.
- Implementaciones maduras en múltiples lenguajes, incluyendo Python (`cel-python` o `celpy`).

### Cambio en el SPEC

**Sección 2.2 (revisar):**

```yaml
edges:
  - from: aggregate
    to: END
    when: "state.verdict == 'approve' && state.weighted_score > 70"
  - from: aggregate
    to: human-review
    when: "state.verdict != 'approve' || size(state.findings) > 5"
```

Nótese: sin `${...}`. CEL evalúa expresiones directamente sobre el contexto provisto por el motor.

**Sección 2.4 (revisar):**

> 3. **Aristas condicionadas evaluadas al terminar el nodo origen**. La condición `when` es una expresión CEL que recibe en su contexto `state` (mapa con el estado compartido del flujo) y `nodes` (mapa nodo_id → outputs). El motor compila la expresión una vez al cargar el flujo (vía `cel-python`) y la evalúa tras cada terminación de nodo. Una expresión que no compile a tipo `bool` en compile-time hace fallar la carga del flujo (rechazo temprano, no en runtime).

**Sección 2.7 (revisar):**

`/flow-validate` adicionalmente verifica:
- Toda expresión CEL en `when` y `exit_when` compila correctamente.
- Toda expresión CEL devuelve `bool`.

### Decisión arquitectónica añadida (D-7)

**(D-7) CEL como motor de evaluación de condiciones.** Las expresiones `when` (en aristas) y `exit_when` (en guards de bucle) son CEL, no jq. Implementación Python: librería `celpy`. Compilación al cargar el flujo, evaluación tras cada nodo. Expresiones no-bool rechazadas en compile-time.

### Impacto en dependencias

- Añadir `celpy` (o `cel-python`) a `requirements.txt` de la lib AFG.
- Sin cambio en bash. CEL se compila y evalúa íntegramente en Python (consistente con Rule #26).

### Impacto en riesgos

Riesgo nuevo a documentar:

| Riesgo | Mitigación |
|---|---|
| **Curva de aprendizaje de CEL.** Quien escribe flows debe aprender un mini-lenguaje nuevo. | CEL tiene documentación oficial extensa de Google y Kubernetes. Se cubre con 1 página de cheat-sheet en `docs/agentic-flow-graph.md`. La sintaxis es familiar (similar a expresiones de cualquier lenguaje C-like). |

---

## Cambio 2 — Namespacing del state compartido

### Lo que decía el SPEC original (sección 2.2)

```yaml
state:
  scores: {}
  verdict: null
```

Y en sección 2.4: *"Estado compartido inmutable por nodo. Cada nodo recibe una copia del estado, devuelve un patch JSON que el motor aplica antes de pasar al siguiente."*

### Problema

El estado del flujo es un único mapa plano. Si en el futuro se añaden capacidades transversales (memoria por flujo, summaries de contexto, metadata de telemetría, anotaciones del runtime), todas compiten por el mismo namespace. Un nodo bien intencionado puede escribir en una clave reservada por accidente.

Magec resolvió este problema con prefijos: `flow:` para state shared explícitamente por el flujo, `app:` para state global de aplicación, `user:` para state por usuario. Los nodos solo escriben en `flow:` y el toolset (`set_state`/`get_state`) añade/quita el prefijo transparentemente.

### Solución

Adoptar el mismo patrón en AFG:

- Estado declarado en `state:` del flow.yaml vive bajo el namespace `flow:` internamente.
- Los nodos ven solo claves planas (`scores`, `verdict`).
- El motor añade/quita el prefijo transparentemente.
- Los namespaces `runtime:` y `meta:` quedan reservados para el motor: trazas, profile resuelto, summaries de ContextGuard (cuando se implemente SPEC-CONTEXT-GUARD), etc.
- Hooks que validan el state pueden inspeccionar todos los namespaces; los nodos NO.

### Cambio en el SPEC

**Sección 2.4 (añadir):**

> 7. **Namespacing del state**. El state compartido tiene tres namespaces internos: `flow:` (declarado en `state:` del flow.yaml, escribible por nodos), `runtime:` (reservado al motor para trazas, profile, summaries), `meta:` (reservado para extensiones futuras). Los nodos solo ven y escriben el namespace `flow:`, sin prefijo. Cualquier intento de escritura a `runtime:` o `meta:` desde un nodo es bloqueado por el motor con error explícito.

### Decisión arquitectónica añadida (D-8)

**(D-8) Namespacing del state compartido.** Tres namespaces internos: `flow:` (nodos), `runtime:` (motor), `meta:` (reservado). Los prefijos son transparentes para nodos. El motor valida intentos de escritura cruzada y los rechaza.

### Impacto en sección 2.8 (hook `flow-state-gate.sh`)

Pre-write hook ahora valida también:
- Que la clave escrita pertenece al namespace `flow:` (sin permitir intentos de `runtime:` o `meta:`).
- Que la clave existe en el `state:` declarado del flow.yaml (campos no declarados rechazados, comportamiento original).

### Impacto en riesgos

Riesgo nuevo:

| Riesgo | Mitigación |
|---|---|
| **Confusión sobre qué namespace está disponible.** Un autor de flow se confunde entre `flow:`, `runtime:`, `meta:`. | Los nodos solo ven `flow:`. El resto es invisible desde la declaración. La documentación cubre la distinción explícitamente. |

---

## Resumen de cambios

| Sección del SPEC original | Cambio |
|---|---|
| 2.2 (esquema YAML) | Quitar `${...}` en ejemplos `when`. Sintaxis CEL directa. |
| 2.4 (reglas del motor) | Punto 3: `jq` → CEL. Punto 7 nuevo: namespacing del state. |
| 2.7 (`/flow-validate`) | Añadir validación de compile-time CEL. |
| 2.8 (`flow-state-gate.sh`) | Validar namespace `flow:` exclusivo para nodos. |
| Decisión arquitectónica | Añadir D-7 (CEL) y D-8 (namespacing). |
| Riesgos | Añadir dos riesgos: curva CEL y confusión de namespaces. |
| Dependencias | Añadir `celpy` a la lib Python AFG. |

## Esfuerzo añadido al SPEC original

Marginal: ~1h adicional al Slice 1 (validador integra compile de CEL) y al Slice 2 (resolver evalúa CEL en lugar de jq). El esquema YAML no cambia más allá de la ausencia de `${...}`.

## Por qué incorporarlo antes de implementar

- **CEL en compile-time evita errores en runtime** que jq solo descubriría tras horas de ejecución.
- **Namespacing es difícil de retrofitear**. Una vez que hay flows escribiendo en el namespace plano, cambiar la convención es disruptivo. Mejor adoptarlo desde el primer flow.
- **Coste marginal**. La librería CEL para Python es estable. El cambio en el motor es localizado.
