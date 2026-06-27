# Sales Pipeline Analyst — Dominio y Conocimiento

## Por qué existe este skill

Los pipelines de ventas tienden al optimismo estructural: los comerciales
sobreestiman las probabilidades de cierre porque son optimistas por naturaleza
y porque el management presiona. El resultado es un forecast que falla
sistemáticamente. Este skill aplica criterios objetivos (MEDDIC) para producir
un forecast más realista y acciones concretas para cada deal.

---

## Metodología MEDDIC — Calificación de oportunidades

MEDDIC es el framework de calificación B2B más utilizado en ventas enterprise.
Cada criterio evalúa un aspecto crítico del deal.

### M — Metrics (Métricas)

¿Sabemos qué métricas de éxito tiene el cliente?
¿Podemos cuantificar el impacto de la solución en sus KPIs?

- **VERDE**: Métricas definidas y aceptadas por el cliente
- **AMARILLO**: Métricas identificadas pero no validadas
- **ROJO**: No hay métricas definidas o el cliente no ha querido compartirlas

### E — Economic Buyer (Decisor económico)

¿Hemos hablado con quien realmente aprueba el presupuesto?

- **VERDE**: Reunión directa con Economic Buyer, alineado con la solución
- **AMARILLO**: Identificado pero no accedido; interlocutor dice que lo apoya
- **ROJO**: Desconocido o solo acceso a nivel técnico/operativo

**Señal predictiva crítica**: si el Economic Buyer no está accesible en etapa
de Negociación, la probabilidad de cierre en el período es < 20%.

### D — Decision Criteria (Criterios de decisión)

¿Sabemos con qué criterios van a elegir entre opciones?

- **VERDE**: Criterios documentados y compartidos por el cliente
- **AMARILLO**: Criterios inferidos de conversaciones; no validados
- **ROJO**: Desconocidos; el cliente no ha querido compartirlos

### D — Decision Process (Proceso de decisión)

¿Sabemos cómo van a tomar la decisión, quién participa y en qué plazos?

- **VERDE**: Proceso documentado: comité, fechas, pasos de aprobación
- **AMARILLO**: Conocemos el proceso general pero no los tiempos exactos
- **ROJO**: No sabemos cómo deciden; las fechas se mueven constantemente

### I — Identify Pain (Pain identificado)

¿Hemos identificado y cuantificado el problema que resolvemos?

- **VERDE**: Pain explícito, cuantificado, expresado por el cliente
- **AMARILLO**: Pain identificado pero no cuantificado o expresado con intensidad baja
- **ROJO**: Solo pain implícito; el cliente no reconoce el problema como urgente

### C — Champion (Campeón interno)

¿Tenemos a alguien dentro que nos defiende activamente?

- **VERDE**: Champion identificado, tiene acceso al EB, nos defiende activamente
- **AMARILLO**: Interlocutor favorable pero sin poder de influencia claro
- **ROJO**: Sin Champion; dependemos de que el cliente nos llame

---

## Semáforo RAG por deal

### Cálculo del color

| Color | Criterio |
|---|---|
| **VERDE** | 5-6 criterios MEDDIC en VERDE; fecha de cierre en el período; siguiente paso confirmado |
| **AMARILLO** | 3-4 criterios en VERDE; fecha de cierre incierta; Champion presente pero no fuerte |
| **ROJO** | < 3 criterios en VERDE; sin Economic Buyer accesible; fecha de cierre > 60 días del período |

### Regla de degradación automática

Un deal se degrada a ROJO independientemente del resto si:
- Economic Buyer (E) está en ROJO
- No hay próximo paso concreto con fecha

---

## Fórmulas de forecast

### Forecast conservador (recomendado)

```
Forecast = Σ(deals_VERDE × 0.90) + Σ(deals_AMARILLO × 0.35) + Σ(deals_ROJO × 0.05)
```

Los % por defecto son conservadores. Se pueden ajustar si hay historial propio
de conversion rate por etapa — en ese caso, **documentar los % usados en el output**.

### % típicos por etapa en contexto español B2B enterprise

| Etapa | % cierre por defecto | Ajustar si... |
|---|---|---|
| Prospección | 5% | Hay Event Trigger claro |
| Calificación | 15% | MEDDIC > 50% completado |
| Propuesta enviada | 35% | Hay reunión de propuesta programada |
| Negociación | 60% | Economic Buyer alineado |
| Acuerdo verbal | 85% | Contrato en revisión legal |

**REGLA**: Siempre documentar qué % se han usado. Si se usan % diferentes a los
por defecto, justificar la razón en el output.

---

## Señal predictiva del Economic Buyer

El criterio **E (Economic Buyer)** tiene el mayor poder predictivo de todos
los criterios MEDDIC. Estudios en ventas enterprise muestran que:

- Deals con acceso al EB: conversion rate promedio 45-60%
- Deals sin acceso al EB: conversion rate promedio 8-15%
- Deals donde el EB rechaza una reunión: conversion rate < 5%

**Acción táctica**: cuando un deal está en AMARILLO o ROJO por el criterio E,
la prioridad número uno es conseguir una reunión con el Economic Buyer,
incluso a costa de ralentizar el proceso con otros stakeholders.

---

## Qué hacer con los deals ROJO

Los deals ROJO no significan automáticamente pérdida. Hay dos estrategias:

### Estrategia 1: Recalificar

Volver al inicio del proceso de discovery:
- ¿Sigue siendo el momento correcto?
- ¿Ha cambiado el stakeholder principal?
- ¿Hay un Event Trigger nuevo que podemos activar?

### Estrategia 2: Aparcar

Si tras recalificar el deal sigue en ROJO y no hay Event Trigger visible:
- Registrar el motivo de cierre probable en el CRM
- Establecer fecha de follow-up en 90 días
- Liberar el tiempo de ese deal para deals AMARILLO o VERDE

**Regla de priorización**: el tiempo invertido en deals ROJO tiene un
coste de oportunidad real sobre deals VERDE y AMARILLO con cierre posible.
