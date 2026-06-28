# Org Meeting Capture — Dominio y Conocimiento

## Por qué existe este skill

Las reuniones son el lugar donde la organización real se manifiesta: quién interrumpe
a quién, qué se decide antes de que acabe la frase, qué compromiso se asume de forma
ambigua para no decir que no. La mayor parte de este conocimiento desaparece porque
nadie lo estructura. Este skill convierte conversaciones en inteligencia organizativa.

---

## Qué buscar en una reunión

### Indicadores de poder en el lenguaje verbal

| Patrón lingüístico | Señal |
|---|---|
| "Yo decidiré..." / "Lo que haremos es..." | Autoridad asumida (formal o informal) |
| "¿Podemos hacer eso sin que yo tenga que...?" | Delegación descendente, actitud ejecutiva |
| "Hablé con X ayer y me dijo que..." | Acceso privado = influencia bilateral |
| "Como dijimos en el comité..." | Referencia a contexto del que otros no participaron |
| "Esto no es negociable" | Línea roja explícita |
| "Lo veo difícil, pero..." | Veto suavizado — no significa sí |
| "Habría que estudiarlo más" | Freno sin compromiso de fecha = veto diferido |

### Indicadores de poder en la dinámica de la reunión

| Comportamiento | Señal |
|---|---|
| Alguien habla y todos toman nota | Speaker con mayor autoridad percibida |
| Opinión solo expresada cuando se le pregunta | Postura reservada — poder latente |
| Cambio de tema justo cuando uno llega a sus límites | Control de agenda implícito |
| Reunión dentro de la reunión (susurros, notas) | Coalición activa no declarada |
| Pregunta que en realidad es una orden | Autoridad indirecta |
| Interrupción tolerada sin reacción | Jerarquía real más alta de la nominal |

### Acuerdos informales — tipos

| Tipo | Ejemplo | Riesgo |
|---|---|---|
| Compromiso velado | "Nos ocuparemos de eso" | Sin fecha, sin responsable = no existe |
| Acuerdo condicional | "Si X, entonces Y" | La condición nunca se cumple explícitamente |
| Compromiso por presión social | Asiente para no parecer el bloqueador | Deshará el acuerdo cuando salga de la sala |
| Delegación ambigua | "Tú te encargas ¿verdad?" | El receptor no confirmó explícitamente |
| Acuerdo fuera de registro | Decisión tomada fuera del acta formal | No quedará documentada salvo aquí |

---

## Estructura del output de captura

### Niveles de confidence para insights

- **EXTRACTED**: información literal de la transcripción, con cita textual
- **INFERRED**: patrón observable pero no explícito; derivado de comportamiento o contexto
- **AMBIGUOUS**: señal contradictoria o insuficiente — se documenta la ambigüedad, no se resuelve

### Formato de insight

```yaml
insights:
  - id: "insight-001"
    tipo: "poder_real"        # poder_real | acuerdo_informal | tension | alianza | señal_alerta | rol_real
    contenido: "Luis Mora tomó la palabra para definir el alcance antes de que Ana García terminara su propuesta."
    fuente: "cita_textual"    # cita_textual | patrón_observado | inferencia
    cita: "—Mira, lo que vamos a hacer es limitar el rollout a Operaciones primero..."
    confidence: EXTRACTED
    participante_clave: "Luis Mora"
    implicacion: "Mora ejerce autoridad de facto sobre el alcance, aunque el project sponsor es García"
    confidence_implicacion: INFERRED
```

### Formato de nodo propuesto

```yaml
nodos_propuestos:
  - id: "pedro-sanchez-director-compras"
    nombre: "Pedro Sánchez"
    cargo_formal: "Director de Compras"
    detectado_en: "reunión 2024-11-20"
    rol_real_propuesto: "Gatekeeper de validaciones de presupuesto para proyectos > 100k€"
    confidence: INFERRED
    fuente: "Referenciado 3 veces como aprobador necesario por distintos participantes"
    status: PENDIENTE_APROBACION
```

---

## Señales de alerta específicas de reunión

### Bloqueos futuros probables

- Alguien que debía estar no fue invitado o no acudió
- El "sponsor" no intervino en toda la reunión
- Las preguntas de implementación generaron evasivas
- Se fijó fecha de "siguiente reunión" sin agenda concreta

### Coaliciones emergentes

- Dos o más personas coordinadas visiblemente (misma postura, se citan mutuamente)
- Alguien que refuerza argumentos de otro sin que se lo pidieran
- Pausa larga antes de responder = consulta interna no verbal

### Compromisos que probablemente no se cumplirán

- Sin responsable nombrado explícitamente
- Sin fecha concreta ("pronto", "cuando podamos", "en cuanto...")
- El responsable asignado no confirmó verbalmente
- El compromiso se tomó en los últimos 5 minutos de la reunión (prisa por cerrar)

---

## Ética y límites de la captura

### Qué capturar

- Declaraciones profesionales en contexto de reunión de trabajo
- Comportamientos observables en la dinámica de grupo
- Compromisos y acuerdos (formales e informales)
- Señales de estructura de poder en contexto organizativo

### Qué NO capturar

- Comentarios fuera de contexto profesional (conversación antes/después)
- Expresiones emocionales sin relevancia organizativa
- Información sobre terceros no presentes en la reunión
- Datos de salud, situación personal o familiar de participantes

### Regla de la cita literal

Solo se puede etiquetar como `EXTRACTED` con `fuente: cita_textual` si la cita
aparece literalmente en la transcripción. No se pueden parafrasear ideas como citas.
Si la transcripción es imprecisa, usar `fuente: patrón_observado` + `confidence: INFERRED`.

---

## Flujo de aprobación antes de escribir al grafo

```
CAPTURA → revisión_humana → aprobación_explícita → ingesta_en_grafo
                ↓ si rechazado
         descarte_o_reformulación
```

Este flujo es innegociable. Los nodos propuestos son siempre `status: PENDIENTE_APROBACION`
hasta que un humano confirme explícitamente su inclusión.
