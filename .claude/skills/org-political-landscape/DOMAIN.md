# Org Political Landscape — Dominio y Conocimiento

## Por qué existe este skill

Saber que alguien "está en contra" no es suficiente. El paisaje político interno
revela la estructura de resistencias y apoyos: por qué cada actor tiene la postura
que tiene, qué coaliciones existen, qué condiciones cambiarían la situación.
Sin este análisis, las estrategias de influencia son reactivas y frecuentemente fallan.

---

## Political Landscape Mapping — Fundamentos teóricos

### Kotter: Organizaciones como sistemas de poder

John Kotter (HBR, "Power and Influence") establece que las organizaciones son
sistemas de dependencias interdependientes donde el poder fluye a través de:

1. **Dependencia de recursos**: quien controla presupuesto, headcount o acceso
2. **Dependencia de información**: quien controla flujos de datos críticos
3. **Dependencia de decisión**: quien tiene autoridad formal o informal de veto
4. **Dependencia de legitimidad**: quien representa a grupos con poder simbólico

Para mapear el paisaje político, se identifican qué tipo de dependencia tiene
cada actor sobre los demás y sobre la iniciativa en cuestión.

### McKinsey: Influence Map para iniciativas de cambio

McKinsey Influence Model (Keller & Price) identifica cuatro palancas de cambio:

| Palanca | Descripción | Implicación para mapa político |
|---|---|---|
| Role modeling | Líderes visibles que demuestran el cambio | ¿Hay promotores con credibilidad? |
| Fostering understanding | Explicar el "por qué" con claridad | ¿Los opositores entienden la iniciativa? |
| Developing talent | Capacidades necesarias para el cambio | ¿Hay resistencia por brecha de habilidades? |
| Reinforcing with formal mechanisms | KPIs, incentivos, estructura | ¿Los incentivos existentes contradicen el cambio? |

### ONA básico (Organizational Network Analysis)

ONA mapea relaciones informales mediante tres redes clave:

- **Red de información**: ¿a quién le preguntan cuando necesitan saber algo?
- **Red de influencia**: ¿a quién escuchan cuando toman decisiones?
- **Red de confianza**: ¿a quién piden opinión en temas delicados?

Sin datos cuantitativos de ONA, se puede inferir estas redes observando:
patrones de copia en emails, quién habla después de quién en reuniones,
quién recibe borradores antes de que sean oficiales.

---

## Cómo inferir motivaciones reales

### Método de los tres porqués organizativos

Para cada stakeholder con postura conocida, preguntarse:

1. **¿Qué pierde si esta iniciativa tiene éxito?** (territorio, relevancia, recursos)
2. **¿Qué gana si fracasa?** (posicionamiento relativo, estatus quo conservado)
3. **¿Qué condición cambiaría su postura?** (garantías, compensación, reconocimiento)

### Señales de motivación real vs. motivación declarada

| Motivación declarada | Posible motivación real | Señal |
|---|---|---|
| "Preocupaciones técnicas" | Pérdida de control sobre TI | Bloquea solo cuando decide el proveedor |
| "Falta de recursos" | No quiere priorizar este proyecto | Sí hay recursos para otras iniciativas |
| "Timing incorrecto" | Espera cambio de circunstancias que le beneficie | Ha dicho lo mismo en los últimos 3 proyectos |
| "Necesitamos más datos" | Desacuerdo con la dirección | Los datos nunca son suficientes |
| "Hay que alinear a todo el equipo" | Quiere ganar tiempo o bloquear | Proceso de alineamiento indefinido |

### Confidence levels para inferencias

- `EXTRACTED`: Observable directamente en documentos, citas, comportamiento registrado
- `INFERRED`: Derivado de patrones, historial o señales indirectas — requiere validación
- `AMBIGUOUS`: Información contradictoria o insuficiente — documentar la ambigüedad

---

## Estructura del mapa político

### Dimensiones por actor

```yaml
actor_politico:
  id: "luis-mora-operaciones"
  postura: OPOSITOR_PASIVO
  intensidad: 4  # 1 = tibio, 5 = activo
  motivo_declarado: "El proyecto distrae al equipo de operaciones"
  motivo_real_inferido: "Perdería control sobre el proceso de pedidos; su KPI depende del sistema actual"
  confidence_motivo_real: INFERRED
  coalicion_con: ["jorge-perez-logistica"]
  tension_con: ["ana-garcia-cto"]
  condicion_de_movimiento: "Garantía formal de que su equipo no se reduce + crédito visible en el proyecto"
  riesgo: "Puede activar a Logística en contra si no se gestiona antes del Comité"
  proxima_accion: "Reunión 1:1 antes de la presentación al Comité de Dirección"
```

### Tipos de coalición

| Tipo | Descripción | Gestión |
|---|---|---|
| Alianza natural | Compartición de objetivos estructural | Activar y dar visibilidad |
| Alianza táctica | Común en esta iniciativa, no en general | Cuidado: puede romperse |
| Bloque de resistencia | Coordinados para bloquear | Dividir o aislar |
| Red de influencia silenciosa | No visibles pero coordinados | El más difícil de gestionar |

---

## Secuencias de influencia

### Principio de las conversaciones previas

Las grandes decisiones organizativas se toman en conversaciones informales
antes de la reunión formal. La estrategia óptima es:

1. Identificar quién tiene poder de veto (actor con mayor intensidad de oposición)
2. Entender su condición de movimiento
3. Tener conversación 1:1 antes del evento formal
4. Construir coalición de promotores visible
5. Presentar en el foro formal con la batalla ya ganada

### Orden recomendado

```
[Economic Buyer] → [Veto técnico] → [Sponsors formales] → [Escépticos con influencia] → [Presentación formal]
```

---

## Señales de alerta en el paisaje político

- **Silencio en reuniones**: oposición no expresada = riesgo de bloqueo tardío
- **"Lo estudiaremos"**: veto diferido, no decisión positiva
- **Escalado prematuro**: alguien sube el tema a su propio jefe antes de hablar contigo
- **Petición de "más información"** repetida: la información no es el problema
- **Ausencias estratégicas**: no aparecer en reuniones clave para evitar comprometerse
