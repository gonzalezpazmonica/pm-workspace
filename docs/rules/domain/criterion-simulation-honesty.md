---
context_tier: L2
token_budget: 600
---

# Criterion Simulation Honesty — SPEC-194

> Esta regla declara explicitamente lo que la Criterion Simulation Layer NO es.
> Cargada junto a criterion-simulation-challenge.sh y al cargar meta-reflection.

## Declaracion principal

**Esta capa NO es criterio real. Es una simulacion heuristica de pausa.**

La cita textual que define la motivacion y el limite de la spec:

> "Un agente que no puede dudar de su propia idea no cierra el loop.
> Lo simula. Esta spec es esa simulacion, declarada como tal."

Y la cita de origen de la usuaria (2026-06-13):

> "Un humano, en la fase de revision, puede concluir que el problema no
> estaba en la ejecucion sino en la idea original. Puede dudar de la pregunta,
> no solo de la respuesta. Un agente, sin ese meta-nivel disenado, revisara
> la aplicacion pero no cuestionara la idea. Optimizara dentro del marco.
> No transformara el marco. Se delega la ejecucion, no el criterio.
> Cuando el humano no mantiene el suyo, el sistema no cierra el loop. Lo simula."

## Limitaciones declaradas

1. **Hora del dia no es fatiga real.**
   El heurístico de fatiga usa la banda horaria (SAVIA_CS_FATIGUE_HOUR_BAND)
   como proxy. Trabajar a las 23:00 no prueba cansancio. La senal es un
   indicador debil, no un diagnostico.

2. **Override-rate alto puede ser legitimo.**
   Un operador que confirma rapidamente muchas tareas puede estar en flujo
   productivo, no relajando el criterio. La tasa de reafirmacion es una
   senal contextual, no una condena.

3. **Falsos positivos son esperados y aceptables.**
   Tareas bien planteadas con score alto activaran la capa. El coste es
   ~30 segundos del operador confirmando el encuadre. El beneficio esperado:
   1 de cada N activaciones, el operador detecta que el encuadre estaba mal.

4. **El judge LLM no tiene criterio.**
   Las 4 meta-preguntas ejecutadas por el judge son heuristicas estructuradas,
   no juicio real. La confianza que reporta es convergencia de senales, no certeza.

5. **La capa no detecta errores de ejecucion.**
   Para eso existe el Recommendation Tribunal (SPEC-125) y el Code Review
   Court. Esta capa solo ataca el slot "encuadre del problema".

## Lo que SI hace

Activa heuristicas de pausa cuando las senales sugieren que el operador puede
haber bajado la guardia. El output es un challenge visible. No una decision.

El operador siempre decide. La capa solo interpela.

## Diferencia entre evaluacion y reflexion

Ver .opencode/skills/meta-reflection/DOMAIN.md para la exposicion completa.

Resumen: evaluar = verificar si la aplicacion fue correcta DADO el problema.
Reflexionar = cuestionar si el problema dado era el problema real.
Esta capa activa el segundo tipo. Sin disenarlo, no ocurre.

## Enforcement

La frase "simulacion de meta-reflexion, no tu criterio" debe aparecer en
CADA banner emitido por el hook. Verificado por tests bats.
