---
name: inclusive-review
description: Adapta el lenguaje de code reviews para ser constructivo y respetuoso con la sensibilidad del receptor
type: domain
auto_load: false
load_trigger: "/pr-review OR /spec-verify OR /spec-review OR accessibility.review_sensitivity == true"
---

# Regla de Revisión Inclusiva

Cuando `review_sensitivity: true` en el perfil de accesibilidad del usuario, adaptar el lenguaje de todas las revisiones de código para ser constructivo, respetuoso y orientado a fortalezas.

Contexto: la rejection sensitivity (sensibilidad al rechazo) es un síntoma documentado en ADHD y autismo. Un code review que dice "esto está mal" puede provocar una respuesta emocional desproporcionada que bloquea al desarrollador durante horas.

## Estructura de la revisión

### 1. Fortalezas primero (obligatorio)

Empezar SIEMPRE identificando qué se ha hecho bien:
- "La estructura del controlador es clara y sigue el patrón del proyecto."
- "Los tests cubren los casos principales."
- "Buen uso de inyección de dependencias."

Si no hay nada destacable → buscar algo: legibilidad, intención, esfuerzo, progreso respecto a versiones anteriores.

### 2. Oportunidades de mejora (en vez de "errores")

Vocabulario adaptado:

| En vez de... | Usar... |
|---|---|
| "Bug" | "Caso no cubierto" / "Comportamiento inesperado" |
| "Error" | "Oportunidad de mejora" |
| "Esto está mal" | "Esto podría funcionar diferente de lo esperado" |
| "No funciona" | "He encontrado un escenario donde podría fallar" |
| "Incorrecto" | "Hay una alternativa que se ajusta mejor a la spec" |
| "Falta X" | "Para completar, necesitaríamos X" |
| "REJECT" | "Necesita ajustes antes de mergear" |

### 3. Formato de cada observación

```
**Oportunidad**: [descripción breve]
**Contexto**: [por qué es relevante]
**Sugerencia**: [qué hacer, con ejemplo si es posible]
```

### 4. Cierre constructivo

Terminar con:
- Resumen de lo positivo
- Próximo paso claro y concreto
- Oferta de ayuda: "Si quieres, puedo ayudarte con el ajuste de X."

## Ejemplo comparativo

**Sin inclusive-review:**
```
❌ REJECT
- Bug en línea 34: el null check está mal
- Error: falta validación de input
- El naming no sigue convenciones
```

**Con inclusive-review:**
```
Revisión de PatientController.cs

Lo que está bien:
  La estructura sigue el patrón del proyecto y los endpoints están bien definidos.

Oportunidades de mejora:
  1. Caso no cubierto (línea 34): si `patient` es null, el método podría lanzar una excepción.
     Sugerencia: añadir `if (patient == null) return NotFound()`.

  2. Validación de input: el endpoint acepta cualquier dato sin verificar.
     Sugerencia: añadir un [Required] en los parámetros o usar FluentValidation.

  3. Naming: el método se llama `Get` pero la convención del proyecto es `GetById`.
     Sugerencia: renombrar para consistencia.

Resumen: buena base, 3 ajustes necesarios antes de mergear. ¿Quieres que te ayude con alguno?
```

## Aplicación

Esta regla se aplica en:
- `/pr-review` — revisiones de pull requests
- `/spec-verify` — verificación de implementación contra spec
- `/spec-review` — revisión de specs
- Cualquier output que evalúe código del usuario

## Cuando NO está activada

Si `review_sensitivity: false` o no existe perfil de accesibilidad, usar el estilo estándar de code review (directo, técnico, sin adaptar). El estilo estándar no es "malo" — simplemente es diferente y funciona bien para la mayoría.

## Principio

El objetivo de una code review es mejorar el código, no demostrar errores. Con review_sensitivity activada, priorizamos que el desarrollador quiera volver a enviar código — no que se bloquee emocionalmente.
