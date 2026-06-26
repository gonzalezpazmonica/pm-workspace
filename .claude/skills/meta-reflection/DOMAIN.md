# DOMAIN: meta-reflection — Evaluacion vs Reflexion

> Documento de dominio conceptual para el Criterion Simulation Layer (SPEC-194).
> Cargado junto a SKILL.md cuando el operador o el judge necesitan contexto
> sobre la diferencia fundamental entre evaluar y reflexionar.

## El problema conceptual

Un sistema agentico puede ejecutar tres operaciones:

1. **Ejecutar**: aplicar la solucion propuesta al problema dado.
2. **Evaluar**: verificar si la aplicacion fue correcta DADO el problema dado.
3. **Reflexionar**: cuestionar si el problema dado era el problema real.

Los sistemas actuales hacen 1 y 2 bien. La operacion 3 requiere salir del
marco de referencia. Eso no ocurre de forma espontanea: debe disenarse.

## Evaluacion (correcta aplicacion del criterio dado)

La evaluacion responde a: "¿ejecutamos bien?"

Criterio: coherencia interna entre la solucion y los requisitos.
Limite: solo puede detectar errores dentro del marco. Si el marco esta mal,
la evaluacion lo confirmara como correcto.

Ejemplo: un test que verifica que "el sistema registra el log de acceso"
pasa correctamente. La evaluacion lo confirma. Pero si el problema real era
"reducir la latencia de autenticacion", el log no ayuda. La evaluacion no
vio el error porque el error estaba en el encuadre, no en la ejecucion.

## Reflexion (cuestionar el criterio mismo)

La reflexion responde a: "¿era este el problema correcto?"

Criterio: coherencia externa entre el encuadre del problema y el problema real.
Limite: no puede ejecutarse dentro del mismo marco que usa para evaluar.
Requiere distancia: tiempo, energia, o un interlocutor externo.

Ejemplo: antes de especificar "implementar cache distribuida", preguntarse
"¿el problema real es la cache, o es que estamos consultando la base de
datos N veces por request?". Esa pregunta no emerge del proceso de
evaluacion de la implementacion de cache.

## Por que los sistemas agenticos no reflexionan espontaneamente

Un LLM recibe un problem_statement y una proposed_solution. Su objetivo
es producir output coherente con esos inputs. Maximizar coherencia interna
NO es lo mismo que maximizar correctitud externa.

Para reflexionar, el sistema necesitaria:
1. Tener acceso a una representacion del "problema real" independiente del
   problem_statement recibido.
2. Detectar divergencia entre ambas.
3. Priorizar la correccion del encuadre sobre la eficiencia de la ejecucion.

Ninguno de esos tres pasos ocurre de forma natural en la arquitectura actual.

## Lo que esta spec hace (y lo que no hace)

### LO QUE HACE

Activa heuristicas de pausa cuando las senales sugieren que el operador puede
haber bajado la guardia (hora atipica, presion, alta tasa de confirmaciones,
precedentes de encuadres fallidos). En ese momento, ejecuta las 4 preguntas
que un senior con energia y distancia se haria.

El output es un challenge visible al operador. NO una decision. El operador
sigue siendo responsable.

### LO QUE NO HACE

No genera criterio. No sustituye al operador. No bloquea la ejecucion.
No detecta errores de ejecucion (para eso existe el tribunal).
No juzga si la idea es buena o mala. Solo pregunta si la idea responde
al problema correcto.

## Cita de origen (2026-06-13)

> "Un humano, en la fase de revision, puede concluir que el problema no
> estaba en la ejecucion sino en la idea original. Puede dudar de la pregunta,
> no solo de la respuesta. Un agente, sin ese meta-nivel disenado, revisara
> la aplicacion pero no cuestionara la idea. Optimizara dentro del marco.
> No transformara el marco. Se delega la ejecucion, no el criterio.
> Cuando el humano no mantiene el suyo, el sistema no cierra el loop. Lo simula."

Esta spec es esa simulacion, declarada como tal.

## Implicacion para el operador

Cuando la capa emite un challenge:
- No es una acusacion. Es una pregunta.
- No bloquea. Es una pausa voluntaria.
- No tiene certeza. Tiene convergencia de senales.

La respuesta correcta NO es siempre "reafirmar". A veces es "tienes razon,
el encuadre esta mal". Esa admision, cuando ocurre, es el valor de la capa.

La respuesta correcta NO es nunca "confirmar sin pensar". Eso anula la capa.
Por eso reaffirm requiere razon de >= 20 chars: el friction minimo para que
la confirmacion sea consciente.

## Glosario de dominio

| Termino | Definicion en este contexto |
|---------|----------------------------|
| Frame / Encuadre | El conjunto de supuestos sobre cual es el problema a resolver |
| Frame challenge | Cuestionamiento de si el encuadre captura el problema real |
| Frame drift | Divergencia entre el encuadre de la solucion y el problema real |
| Reaffirmation | Confirmacion consciente y deliberada del encuadre tras el challenge |
| Reframe | Redefinicion del problem statement tras detectar drift |
| Operator state | Conjunto de senales del estado cognitivo del operador (heuristicas locales) |
| Criterion | La capacidad humana de juzgar si algo vale la pena hacerse |
| Simulation | Lo que esta capa hace: imitar la estructura del criterio sin tenerlo |
