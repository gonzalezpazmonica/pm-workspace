# Org Stakeholder Mapper — Dominio y Conocimiento

## Por qué existe este skill

Las organizaciones operan en dos capas simultáneas: la estructura formal (organigramas,
títulos) y la estructura de poder real (quién influye, quién veta, quién conecta).
La mayoría de iniciativas fracasan porque se trabaja con la capa formal e ignora la real.
Este skill hace explícito lo implícito.

---

## Frameworks de análisis de stakeholders

### Matriz Poder / Interés (Eden & Ackermann)

```
                     ALTO INTERÉS
                          |
          Actores clave   |   Promotores activos
          (gestionar       |   (colaborar estrechamente)
          de cerca)        |
BAJO ─────────────────────┼───────────────────── ALTO
PODER                     |                     PODER
          Ignorar/mínimo  |   Mantener satisfechos
          (monitorizar)   |   (informar, no saturar)
                          |
                     BAJO INTERÉS
```

**Uso**: clasificar a cada stakeholder en uno de los cuatro cuadrantes.
El cuadrante determina la estrategia de engagement.

### Influence Maps (método MIT)

Mapa de relaciones de influencia directa entre personas:
- **Flecha sólida**: influencia establecida y reconocida
- **Flecha punteada**: influencia informal o situacional
- **Bidireccional**: influencia mutua (coalición)
- **Nodo central**: actor con mayor grado de entrada = hub de poder real

Permite detectar *brokers de información*: personas con pocas conexiones de poder
pero que controlan el flujo de información crítica.

### RACI Extendido (más allá del RACI estándar)

| Rol | Significado formal | Señal real a buscar |
|---|---|---|
| Responsible | Ejecuta la tarea | ¿Tiene recursos para hacerlo? |
| Accountable | Firma el resultado | ¿Tiene autoridad real o solo nominal? |
| Consulted | Aporta criterio | ¿Se le consulta de verdad o es protocolo? |
| Informed | Recibe updates | ¿Actúa si no está informado? → poder oculto |
| **Veto** | Puede bloquear sin participar | Detectar por historial de bloqueos |
| **Sponsor** | Protege la iniciativa internamente | Crítico para supervivencia política |

---

## Tipos de conocimiento tácito organizativo

### Conocimiento de relaciones
- Quién come con quién, quién se copia en emails de cortesía
- Quién defiende a quién en reuniones
- Historial de conflictos no resueltos entre departamentos

### Conocimiento de motivaciones reales
- Objetivos formales vs. objetivos de carrera personal
- Qué métricas afectan al bonus de cada líder
- Qué proyectos pasados apoyan u obstaculizan la iniciativa actual

### Conocimiento de procesos informales
- Por dónde circula la información antes de las reuniones
- Qué reuniones previas son donde se decide realmente
- Qué documentos se leen vs. cuáles se archivan sin leer

---

## Señales de comportamiento que revelan poder real

| Señal observable | Interpretación |
|---|---|
| Habla al principio de reuniones | Agenda-setter, poder de encuadre |
| Otros buscan su mirada antes de hablar | Árbitro informal |
| Propuestas regresan "para revisión" cuando él/ella no estaba | Veto silencioso |
| Invitado a reuniones de nivel superior a su cargo | Trusted advisor informal |
| Nunca aparece en reuniones pero sus criterios se citan | Poder por ausencia |
| Cambia de postura cuando X entra en la sala | Dependencia o miedo |
| Primero en recibir borradores para "feedback" | Gatekeeper de información |

---

## Roles formales vs. roles reales — ejemplos tipo

| Cargo formal | Rol real frecuente |
|---|---|
| Director de TI | Veto técnico en compras, bloqueador de proyectos externos |
| Asistente de Dirección | Gatekeeper de agenda, filtro de información al CEO |
| Jefe de Proyecto PMO | Promotor o saboteador según la iniciativa |
| CFO | Economic Buyer real aunque no sea el sponsor nominal |
| Comité de Dirección | Validador formal; la decisión ya está tomada antes |

---

## Taxonomía de posturas

| Postura | Descripción | Estrategia |
|---|---|---|
| PROMOTOR | Activo a favor, invierte energía | Usar como aliado visible |
| SUPPORTER | A favor pero pasivo | Movilizar cuando sea necesario |
| NEUTRAL | Sin postura clara o indiferente | Informar, no saturar |
| ESCÉPTICO | Dubitativo, pide pruebas | Datos y casos de éxito |
| OPOSITOR_PASIVO | En contra pero no actúa | Monitorizar, gestionar en privado |
| OPOSITOR_ACTIVO | En contra y actúa para bloquear | Gestión directa o rodeo |
| DESCONOCIDO | Sin información suficiente | Priorizar obtener información |

---

## Ética en el mapeo de stakeholders

### Qué SÍ capturar
- Roles y responsabilidades formales
- Posturas observadas en reuniones o documentos
- Patrones de comportamiento en contexto profesional
- Relaciones estructurales (reporta a, colabora con)

### Qué NO capturar
- Información personal no profesional (familia, salud, vida privada)
- Motivaciones económicas personales (más allá del rol laboral)
- Especulaciones sobre integridad o carácter
- Rumores sin fuente verificable

### Nivel de confidencialidad
- Todo output: mínimo N3 (interno confidencial)
- Si contiene nombres + posturas: N3 obligatorio
- Si contiene inferencias sobre motivaciones: N4

---

## Formato de nodo YAML

```yaml
stakeholders:
  - id: "ana-garcia-cto"
    nombre: "Ana García"
    cargo_formal: "Chief Technology Officer"
    departamento: "Tecnología"
    rol_real: "Decisora final en arquitectura; veto en compras tech > 50k€"
    motivacion: "Consolidar posición tras cambio de CEO; necesita victorias visibles"
    confidence_motivacion: INFERRED
    postura: ESCÉPTICO
    intensidad: 3  # 1-5
    alianzas: ["elena-ramos-cfo"]
    tensiones: ["luis-mora-operaciones"]
    fuente: "transcripción kick-off 2024-11-15 + observación reunión presupuesto"
    confidence_general: INFERRED
    ultima_actualizacion: "2024-11-20"
    ttl_dias: 90
```
