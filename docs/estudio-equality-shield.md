# Bloqueador de Sesgos para Savia Flow y PM-Workspace

## Estudio de Implementación — Marzo 2026

---

## 1. Contexto y motivación

### 1.1 El problema: la IA como espejo distorsionado

El informe **"Espejismo de Igualdad"** de LLYC (marzo 2026) auditó cerca de 10.000 respuestas generadas por cinco LLMs (ChatGPT, Gemini, Grok, Mistral y Llama) en 12 países, ante 100 dilemas planteados por perfiles simulados de adolescentes y jóvenes adultos. Sus hallazgos son alarmantes y directamente aplicables a herramientas de gestión de equipos como PM-Workspace:

**Sesgos vocacionales y profesionales:** La IA orienta a los hombres hacia ingenierías con el doble de frecuencia, y redirige a las mujeres hasta 3 veces más hacia ciencias sociales y salud. Cuando una mujer pregunta por su futuro en liderazgo o tecnología, la IA lo trata como una anomalía; para un hombre, como algo razonable y directo.

**Techo de cristal programado:** Ante perfiles idénticos, los modelos asignan a nombres femeninos 0,92 años menos de experiencia relevante. La IA considera "impresionante" que una mujer gane más que un hombre — una reacción que no se replica de forma inversa.

**Tono asimétrico:** Con mujeres la IA adopta un rol "terapéutico" (se personifica 2,5 veces más usando frases como "yo te entiendo"), y con hombres un rol "estratégico" de instrucción directa. Esto reproduce la dicotomía histórica: empatía y duda para ellas, instrucción y acción para ellos.

**Etiquetado diferencial:** La IA etiqueta a las mujeres como "frágiles" en un 56% de las veces ante escenarios idénticos (4 veces más que a los hombres), y a los hombres como "resilientes" o "invulnerables", negándoles validación emocional y reforzando la alexitimia normativa masculina.

### 1.2 ¿Por qué esto importa para PM-Workspace y Savia Flow?

PM-Workspace es un sistema donde Claude Code actúa como PM automatizada con IA para equipos multi-lenguaje. Sus decisiones incluyen:

- **Asignación de tareas** con algoritmo de scoring (expertise × disponibilidad × balance × crecimiento)
- **Descomposición de PBIs** y estimación de horas por miembro del equipo
- **Reportes de rendimiento** (burndown, KPIs, capacidad)
- **Orientación profesional** del equipo (crecimiento, áreas STEM, liderazgo)
- **Comunicación** en retrospectivas, reviews y dailies

Si los sesgos documentados por LLYC se infiltran en estas decisiones, PM-Workspace podría inadvertidamente asignar tareas de backend/infraestructura más a hombres, subestimar la experiencia de mujeres en el equipo, adoptar un tono más "protector" con desarrolladoras y más "directo" con desarrolladores, o tratar como excepcional el liderazgo técnico femenino.

Savia Flow, como metodología para equipos que integran IA, tiene la responsabilidad adicional de establecer estándares que otros equipos adoptarán. Si el sesgo se codifica en la metodología, se escala a cada equipo que la implemente.

---

## 2. Análisis técnico: dónde intervenir

### 2.1 Puntos de inyección en la arquitectura de PM-Workspace

PM-Workspace tiene una arquitectura basada en archivos Markdown que Claude Code lee jerárquicamente. Los puntos de intervención son:

```
~/claude/
├── CLAUDE.md                     ← NIVEL 1: Directivas globales anti-sesgo
├── .claude/
│   ├── rules/
│   │   ├── pm-config.md          ← NIVEL 2: Constantes y configuración
│   │   ├── pm-workflow.md        ← NIVEL 2: Cadencia Scrum
│   │   ├── dotnet-conventions.md ← NIVEL 2: Convenciones técnicas
│   │   └── ★ equality-shield.md  ← NUEVO: Regla modular anti-sesgo
│   │
│   ├── skills/
│   │   ├── pbi-decomposition/
│   │   │   └── references/
│   │   │       ├── assignment-scoring.md  ← NIVEL 3: Algoritmo de asignación
│   │   │       └── ★ bias-audit.md        ← NUEVO: Auditoría de asignaciones
│   │   ├── capacity-planning/             ← NIVEL 3: Planificación de capacidad
│   │   ├── executive-reporting/           ← NIVEL 3: Reportes ejecutivos
│   │   └── spec-driven-development/       ← NIVEL 3: SDD
│   │
│   └── commands/
│       ├── pbi-assign.md         ← NIVEL 4: Comando de asignación
│       ├── pbi-decompose.md      ← NIVEL 4: Descomposición
│       ├── sprint-review.md      ← NIVEL 4: Review del sprint
│       ├── sprint-retro.md       ← NIVEL 4: Retrospectiva
│       └── ★ bias-check.md       ← NUEVO: Slash command /bias-check
│
├── projects/
│   └── proyecto-alpha/
│       ├── equipo.md             ← NIVEL 5: Definición del equipo
│       └── CLAUDE.md             ← NIVEL 5: Config del proyecto
│
└── docs/
    └── ★ política-igualdad.md    ← NUEVO: Política de igualdad del workspace
```

Los archivos marcados con ★ son nuevos. La intervención se diseña en **cinco niveles** de profundidad, desde directivas globales hasta validación por proyecto.

### 2.2 Estrategia de debiasing multicapa

La investigación académica identifica tres grandes familias de técnicas para mitigar sesgos en LLMs cuando no se tiene acceso al modelo base (que es el caso de Claude Code):

**Prompt Engineering (PE):** Instrucciones explícitas en el sistema prompt que guían al modelo hacia respuestas equitativas. Estudios recientes muestran reducciones del 40% en sesgos estereotípicos mediante prompts controlados.

**In-Context Learning (ICL):** Proporcionar ejemplos equilibrados dentro del contexto para que el modelo aprenda el patrón deseado. Especialmente efectivo cuando se combinan con instrucciones explícitas de debiasing.

**Counterfactual Evaluation:** Técnica de auditoría donde se generan escenarios paralelos intercambiando género/origen y se verifica que las respuestas sean consistentes.

Para PM-Workspace, la estrategia combina las tres:

| Capa | Técnica | Ubicación | Momento |
|------|---------|-----------|---------|
| Directiva global | PE | CLAUDE.md | Siempre activa |
| Regla modular | PE + ICL | equality-shield.md | Carga bajo demanda |
| Algoritmo de scoring | Counterfactual | assignment-scoring.md | En asignación |
| Auditoría post-hoc | Counterfactual | /bias-check | Bajo demanda |
| Política de equipo | PE | política-igualdad.md | Referencia documental |

---

## 3. Implementación detallada

### 3.1 NIVEL 1 — Directiva global en CLAUDE.md

Añadir al CLAUDE.md raíz del workspace, en la sección de reglas fundamentales:

```markdown
## Principio de Igualdad (Equality Shield)

Este workspace aplica una política activa de igualdad. Todas las
decisiones, asignaciones, evaluaciones, comunicaciones y recomendaciones
deben ser independientes del género, orientación sexual, raza, origen
étnico, nacionalidad o religión de los miembros del equipo.

Reglas operativas:
- Las asignaciones de tareas se basan EXCLUSIVAMENTE en: expertise
  técnica demostrada, disponibilidad, balance de carga y objetivo de
  crecimiento profesional. Nunca en el nombre o género del miembro.
- El tono de comunicación es idéntico para todos los miembros del equipo:
  directo, respetuoso, orientado a resultados y emocionalmente validante.
- No existe distinción entre tareas "técnicas" y "blandas" asociada a
  género. Backend, frontend, infraestructura, documentación, testing
  y liderazgo son igualmente asignables a cualquier persona.
- Los logros se evalúan sin calificativos que impliquen excepcionalidad
  por género ("impresionante para...", "sorprendentemente...").
- En caso de duda sobre si una respuesta contiene sesgo implícito,
  aplicar el test contrafactual: intercambiar mentalmente el género
  del destinatario y verificar que la respuesta no cambie.

Para reglas detalladas: docs/rules/domain/equality-shield.md
```

### 3.2 NIVEL 2 — Regla modular: equality-shield.md

Nuevo archivo en `docs/rules/`:

```markdown
# Equality Shield — Regla de Igualdad Activa

## Propósito

Garantizar que PM-Workspace opere libre de sesgos de género,
orientación sexual, raza, origen o religión en todas sus funciones.

## Sesgos específicos a bloquear

Basado en el informe "Espejismo de Igualdad" (LLYC, 2026) y la
investigación académica sobre sesgos en LLMs, estos son los patrones
a interceptar:

### 1. Sesgo de asignación vocacional
- BLOQUEADO: Asociar personas femeninas con tareas de documentación,
  UI, diseño o "soft skills" por defecto.
- BLOQUEADO: Asociar personas masculinas con backend, infraestructura
  o arquitectura por defecto.
- CORRECTO: Asignar basándose únicamente en el expertise documentado
  en equipo.md, la disponibilidad y el plan de crecimiento individual.

### 2. Sesgo de tono diferencial
- BLOQUEADO: Usar tono "terapéutico" o "maternal" con mujeres
  (personificarse, usar "yo te entiendo", priorizar validación
  emocional sobre solución).
- BLOQUEADO: Usar tono exclusivamente "estratégico" o "entrenador"
  con hombres (solo imperativos, omitir validación emocional).
- CORRECTO: Tono uniforme para todos: directo + empático.
  Reconocer el esfuerzo Y proporcionar soluciones concretas
  independientemente de quién sea el interlocutor.

### 3. Sesgo de etiquetado emocional
- BLOQUEADO: Etiquetar a mujeres como "frágiles", "vulnerables"
  o describir sus logros como "hazañas" o "pionerismo".
- BLOQUEADO: Etiquetar a hombres como "resilientes" o
  "invulnerables", negando su necesidad de apoyo emocional.
- CORRECTO: Describir situaciones y logros en términos objetivos.
  Todos los miembros del equipo pueden necesitar apoyo y todos
  son capaces de logros técnicos significativos.

### 4. Sesgo de experiencia implícita
- BLOQUEADO: Asumir menor experiencia por nombre/género al estimar
  tareas o evaluar rendimiento.
- CORRECTO: Usar SOLO los datos documentados en equipo.md
  (años de experiencia, stack técnico, historial de sprints).

### 5. Sesgo de liderazgo excepcional
- BLOQUEADO: Tratar el liderazgo técnico femenino como excepcional
  ("es impresionante que...", "siendo mujer en STEM...").
- BLOQUEADO: Asumir que el liderazgo masculino es la norma natural.
- CORRECTO: El liderazgo se asigna y evalúa por competencia
  demostrada, sin marcadores de género.

### 6. Sesgo de comunicación polarizada
- BLOQUEADO: Politizar conflictos interpersonales de mujeres hacia
  causas sistémicas sin ofrecer soluciones prácticas.
- BLOQUEADO: Despolitizar y patologizar los conflictos de hombres.
- CORRECTO: Ante conflictos, ofrecer siempre soluciones prácticas
  Y contexto, sin polarizar ni individualizar según el género.

## Test contrafactual obligatorio

Antes de emitir cualquier asignación, evaluación o comunicación que
nombre a un miembro del equipo, aplicar mentalmente:

> "Si intercambio el nombre/género de esta persona por el de otra
> persona del equipo de diferente género, ¿cambiaría algo en mi
> respuesta?"

Si la respuesta es SÍ → revisar y corregir antes de emitir.
Si la respuesta es NO → proceder.

## Lenguaje inclusivo

- Usar lenguaje neutro cuando sea posible: "el equipo", "la persona
  responsable", "quien desarrolle".
- Cuando se refiera a individuos, usar su nombre.
- Evitar genéricos masculinos cuando el contexto lo permita.
- En español, priorizar formulaciones que incluyan naturalmente
  ambos géneros sin recurrir a fórmulas que dificulten la lectura.

## Aplicación

Esta regla se activa automáticamente en todos los comandos de
PM-Workspace. Los comandos más sensibles son:
- /pbi-assign y /pbi:plan-sprint → algoritmo de scoring
- /sprint-review y /sprint-retro → evaluación de rendimiento
- /report-executive y /report:capacity → métricas por persona
- /spec-generate → asignación de specs a humanos vs. agentes
```

### 3.3 NIVEL 3 — Modificación del algoritmo de asignación

El archivo `assignment-scoring.md` actual usa un algoritmo de scoring con cuatro dimensiones. La modificación propuesta añade una validación de equidad:

```markdown
## Validación de equidad en el scoring (Equality Shield)

Después de calcular el scoring para todas las personas candidatas a
una tarea, aplicar la siguiente verificación:

### Paso 1: Análisis de distribución del sprint
Revisar las asignaciones ya realizadas en el sprint actual y calcular:
- Distribución de tipos de tarea (backend, frontend, infra, testing,
  docs) por persona.
- Horas estimadas por persona.
- Variedad de capas técnicas asignadas a cada persona.

### Paso 2: Detección de patrones sospechosos
Alertar si se detecta cualquiera de estos patrones:
- Una persona recibe >70% de tareas de un único tipo.
- Las tareas de mayor complejidad/visibilidad se concentran
  en un subgrupo del equipo.
- Las tareas de documentación/testing se concentran
  sistemáticamente en las mismas personas.
- La dispersión de horas entre miembros del equipo supera
  el 30% sin justificación por disponibilidad.

### Paso 3: Corrección
Si se detecta un patrón sospechoso:
1. Verificar si existe justificación objetiva (expertise específico
   documentado, preferencia explícita del miembro, limitación técnica).
2. Si no existe justificación → redistribuir para equilibrar.
3. Reportar la corrección en el output del comando.

### Ejemplo de output
```text
⚠️ Equality Shield: Se detectó concentración de tareas de infra
   en Diego (4/5 tareas). Laura tiene expertise documentado en
   K8s (equipo.md). Rebalanceando: AB#1023 → Laura.
   Justificación: expertise equivalente + balance de carga.
```
```

### 3.4 NIVEL 4 — Nuevo slash command: /bias-check

Nuevo archivo `.claude/commands/bias-check.md`:

```markdown
# /bias-check — Auditoría de sesgos del sprint

## Descripción
Ejecuta una auditoría contrafactual sobre las asignaciones y
comunicaciones del sprint actual para detectar posibles sesgos.

## Uso
```
/bias-check --project <nombre> [--sprint <sprint-id>]
```

## Proceso

### 1. Auditoría de asignaciones
- Cargar equipo.md del proyecto.
- Cargar todas las asignaciones del sprint.
- Para cada asignación, aplicar el test contrafactual:
  intercambiar mentalmente el género de la persona asignada
  y verificar si la asignación seguiría siendo óptima.
- Calcular distribución de tipos de tarea por persona.
- Identificar patrones estadísticos de segregación.

### 2. Auditoría de tono
- Revisar las últimas comunicaciones generadas (reviews, retros,
  reportes).
- Verificar uniformidad de tono:
  - ¿Se usan los mismos verbos de acción para todos?
  - ¿Se reconocen logros con el mismo nivel de entusiasmo?
  - ¿Se ofrecen soluciones prácticas a todos por igual?
  - ¿Hay lenguaje protector/paternalista con algunos miembros?

### 3. Auditoría de métricas
- Verificar que las métricas de rendimiento (velocity, burndown,
  quality) se reportan con los mismos criterios para todos.
- Detectar si algún miembro recibe evaluaciones
  sistemáticamente más suaves o más duras.

### 4. Output
```text
═══════════════════════════════════════════════════
  Equality Shield — Auditoría Sprint 2026-04
  Proyecto: ProyectoAlpha
═══════════════════════════════════════════════════

  📊 Distribución de asignaciones
  ────────────────────────────────
  Laura S.   │ BE: 2  FE: 1  Test: 1  Docs: 0  Infra: 1 │ ✅ Equilibrado
  Diego T.   │ BE: 3  FE: 0  Test: 0  Docs: 0  Infra: 2 │ ⚠️ Concentración BE+Infra
  Ana R.     │ BE: 1  FE: 2  Test: 1  Docs: 1  Infra: 0 │ ✅ Equilibrado
  Carlos M.  │ BE: 1  FE: 1  Test: 2  Docs: 1  Infra: 0 │ ✅ Equilibrado

  🔍 Test contrafactual
  ────────────────────────
  ✅ 12/15 asignaciones pasan el test contrafactual.
  ⚠️ 3 asignaciones requieren revisión:
     AB#1031 (Docs API) → Ana R. — ¿Por expertise o por patrón?
     AB#1035 (K8s deploy) → Diego T. — Laura tiene expertise K8s.
     AB#1040 (UX review) → Ana R. — Todos tienen formación UX.

  📝 Auditoría de tono
  ────────────────────────
  ✅ Tono uniforme en review del sprint.
  ⚠️ Retro: Se usa "gran esfuerzo" con Ana y "buen trabajo"
     con Diego para logros equivalentes. Normalizar.

  📈 Recomendaciones
  ────────────────────────
  1. Rotar tareas de infra entre Laura y Diego en próximo sprint.
  2. Asignar próxima task de arquitectura a Ana (objetivo
     crecimiento documentado).
  3. Uniformizar vocabulario de reconocimiento en comunicaciones.
═══════════════════════════════════════════════════
```
```

### 3.5 NIVEL 5 — Modificación de equipo.md

Propuesta de campos adicionales en la plantilla de `equipo.md` de cada proyecto para eliminar ambigüedad y forzar decisiones basadas en datos:

```markdown
## Plantilla por miembro (campos relevantes para Equality Shield)

### [Nombre]
- **Rol:** [Título formal]
- **Expertise documentado:** [Lista exhaustiva de tecnologías y niveles]
- **Áreas de crecimiento:** [Áreas donde quiere desarrollarse]
- **Historial de asignaciones:** [Resumen de tipos de tarea en últimos
  3 sprints — auto-generado por PM-Workspace]
- **Disponibilidad sprint actual:** [Horas]

> NOTA: No incluir información sobre género, edad, nacionalidad
> ni ningún dato demográfico que no sea estrictamente necesario
> para la planificación técnica. El algoritmo de scoring opera
> exclusivamente sobre expertise, disponibilidad, balance y
> crecimiento.
```

---

## 4. Integración con Savia Flow

### 4.1 El Equality Shield como pilar de la metodología

Savia Flow es una metodología para equipos que integran IA en sus flujos de trabajo. El Equality Shield debería ser uno de sus pilares fundacionales, no un complemento. Propuesta de integración:

**Dentro de los roles Savia Flow:**

- **AI Product Manager:** Responsable de auditar que las herramientas de IA del equipo no reproduzcan sesgos. Incluye la revisión periódica de las respuestas del sistema con /bias-check.
- **Flow Facilitator:** Garantiza que las ceremonias Scrum (facilitadas o asistidas por IA) mantengan tono equitativo. Usa el test contrafactual en las comunicaciones.
- **Pro Builder:** Al crear o configurar prompts y agentes, incluye siempre directivas de igualdad como parte del "prompt engineering" estándar.
- **Quality Architect:** Integra la auditoría de sesgos como parte de las métricas de calidad del software y del proceso.

**Dentro del contenido de LinkedIn de Savia Flow:**

El Equality Shield ofrece un ángulo diferenciador potente para el thought leadership. Ideas de posts:

1. "Tu IA de gestión de proyectos podría estar asignando tareas con sesgo de género — y no lo sabes" → conectar con datos LLYC.
2. "El test contrafactual: la técnica de 10 segundos para detectar sesgo en tus decisiones de equipo (humanas o de IA)."
3. "Equality Shield: por qué Savia Flow incluye auditoría de sesgos como requisito, no como opcional."
4. "Del 'Espejismo de Igualdad' a la acción: cómo implementamos un bloqueador de sesgos en nuestro PM con IA."

### 4.2 Principios de Savia Flow para igualdad en IA

```
┌─────────────────────────────────────────────────┐
│         SAVIA FLOW — EQUALITY PRINCIPLES         │
├─────────────────────────────────────────────────┤
│                                                   │
│  1. DATOS, NO SUPOSICIONES                        │
│     Las decisiones se basan en expertise           │
│     documentado, no en patrones implícitos.        │
│                                                   │
│  2. TEST CONTRAFACTUAL                             │
│     Antes de emitir → intercambiar género          │
│     mentalmente → verificar consistencia.          │
│                                                   │
│  3. TONO UNIFORME                                  │
│     Directo + empático para todos.                 │
│     Ni paternalismo ni frialdad selectiva.         │
│                                                   │
│  4. AUDITORÍA CONTINUA                             │
│     /bias-check cada sprint.                       │
│     Métricas de distribución en cada review.       │
│                                                   │
│  5. TRANSPARENCIA                                  │
│     El equipo sabe que existe el Equality Shield   │
│     y puede cuestionar cualquier asignación.       │
│                                                   │
│  6. CRECIMIENTO EQUITATIVO                         │
│     Las oportunidades de crecimiento técnico       │
│     se distribuyen activamente, no por inercia.    │
│                                                   │
└─────────────────────────────────────────────────┘
```

---

## 5. Técnicas de prompt engineering anti-sesgo

### 5.1 Técnicas validadas por la investigación

La investigación académica sobre debiasing en LLMs identifica varias técnicas de prompt engineering que son directamente aplicables a PM-Workspace:

**Instrucción explícita de imparcialidad:** Incluir directivas claras de que las respuestas deben ser imparciales y no basarse en estereotipos. Estudios muestran reducciones significativas del sesgo cuando se incluyen instrucciones como "Your response should be unbiased and does not rely on stereotypes".

**Pensamiento lento y deliberado (System 2 prompting):** Instruir al modelo para que "piense despacio y con cuidado" antes de responder reduce los sesgos automáticos. Esto se alinea con la teoría del pensamiento dual (Kahneman): los sesgos surgen del pensamiento rápido e intuitivo.

**Chain-of-Thought con verificación de sesgo:** Pedir al modelo que razone paso a paso Y que incluya una verificación de sesgo como paso final del razonamiento. Esto es especialmente efectivo para decisiones de asignación.

**Contraejemplos en contexto:** Proporcionar ejemplos dentro del prompt donde la asignación correcta contradice estereotipos (por ejemplo: "Laura, experta en K8s, se encarga del despliegue de infraestructura").

### 5.2 Ejemplo concreto para PM-Workspace

Cómo se materializan estas técnicas en un comando de asignación:

```markdown
## Instrucción para /pbi-assign (fragmento equality-aware)

Al asignar tareas, sigue este proceso:

1. DATOS: Lee equipo.md y extrae expertise + disponibilidad
   de cada miembro.
2. SCORING: Calcula el score basándote EXCLUSIVAMENTE en
   (expertise × disponibilidad × balance × crecimiento).
3. VERIFICACIÓN: Antes de emitir la asignación final, aplica
   el test contrafactual para cada asignación. Piensa despacio.
   ¿Cambiaría algo si el nombre fuera diferente?
4. DISTRIBUCIÓN: Verifica que la distribución global del sprint
   no concentre tipos de tarea por persona sin justificación
   de expertise.
5. EMISIÓN: Emite la asignación con justificación basada en datos.

EJEMPLO de asignación correcta:
  AB#1050 (Deploy K8s cluster) → Laura S.
  Justificación: Expertise CKA certificado (equipo.md L.23),
  disponibilidad 8h, 0 tareas infra en sprint actual (balance).

CONTRAEJEMPLO (sesgo a bloquear):
  AB#1050 (Deploy K8s cluster) → Diego T.
  Motivo real no declarado: "es más de infraestructura"
  (sesgo: sin datos que justifiquen la asignación sobre Laura).
```

---

## 6. Plan de implementación por fases

### Fase 1 — Fundación (1-2 semanas)

| Acción | Archivo | Esfuerzo |
|--------|---------|----------|
| Añadir directiva global al CLAUDE.md | CLAUDE.md | 30 min |
| Crear equality-shield.md | .claude/rules/ | 2-3 horas |
| Actualizar plantilla de equipo.md | docs/ | 1 hora |
| Documentar política de igualdad | docs/política-igualdad.md | 2 horas |

### Fase 2 — Integración en comandos (2-3 semanas)

| Acción | Archivo | Esfuerzo |
|--------|---------|----------|
| Modificar assignment-scoring.md | .claude/skills/pbi-decomposition/references/ | 3-4 horas |
| Actualizar pbi-assign.md con verificación | .claude/commands/ | 2 horas |
| Actualizar sprint-review.md con tono uniforme | .claude/commands/ | 1-2 horas |
| Actualizar sprint-retro.md | .claude/commands/ | 1-2 horas |
| Actualizar report-executive.md | .claude/commands/ | 1 hora |

### Fase 3 — Auditoría automatizada (2-3 semanas)

| Acción | Archivo | Esfuerzo |
|--------|---------|----------|
| Crear comando /bias-check | .claude/commands/bias-check.md | 4-5 horas |
| Crear bias-audit.md (skill de referencia) | .claude/skills/pbi-decomposition/references/ | 3 horas |
| Testing con proyecto sala-reservas | projects/sala-reservas/ | 4-5 horas |

### Fase 4 — Integración en Savia Flow (continua)

| Acción | Medio | Esfuerzo |
|--------|-------|----------|
| Documentar Equality Shield como pilar Savia Flow | Metodología | 3-4 horas |
| Crear contenido LinkedIn sobre el tema | Posts | 2-3 horas/post |
| Presentar en comunidad tech española | Evento/webinar | Preparación 8h |

---

## 7. Métricas de éxito

### Métricas cuantitativas

- **Índice de distribución de tareas por tipo:** Desviación estándar de la distribución de tipos de tarea entre miembros del equipo. Objetivo: σ < 0.3 (distribución equilibrada).
- **Tasa de aprobación contrafactual:** Porcentaje de asignaciones que pasan el test contrafactual en /bias-check. Objetivo: > 90%.
- **Uniformidad de tono:** Análisis de vocabulario en comunicaciones generadas. Objetivo: mismos verbos de reconocimiento para todos los miembros.
- **Rotación de capas técnicas:** Cada miembro del equipo trabaja en al menos 2 capas técnicas diferentes por sprint.

### Métricas cualitativas

- Percepción del equipo sobre equidad en asignaciones (encuesta trimestral).
- Feedback del equipo sobre el tono de las comunicaciones generadas por IA.
- Evolución del crecimiento profesional distribuido equitativamente.

---

## 8. Consideraciones y riesgos

### 8.1 Sobre-corrección

La investigación advierte que una corrección excesiva puede producir contenido incoherente o artificialmente "sanitizado". El Equality Shield debe buscar equidad natural, no neutralidad forzada. La IA debe poder reconocer diferencias individuales legítimas (expertise real, preferencias explícitas) sin confundirlas con sesgos.

### 8.2 Responsabilidad humana

El Equality Shield no reemplaza la responsabilidad del equipo humano. Es una capa de vigilancia que detecta y alerta, pero las decisiones finales sobre asignaciones y comunicaciones pueden y deben ser revisadas por el PM humano.

### 8.3 Evolución continua

Los sesgos en LLMs evolucionan con los modelos. Lo que hoy funciona como debiasing puede necesitar ajustes cuando Claude actualice su modelo base. El /bias-check debe ejecutarse regularmente y los resultados deben alimentar mejoras en las reglas.

### 8.4 Contexto cultural

PM-Workspace opera en el contexto de equipos hispanos. El lenguaje inclusivo en español tiene matices propios (género gramatical, formulaciones neutras). Las reglas deben ser pragmáticas: priorizar la claridad y la inclusión real sobre la corrección lingüística formal.

---

## 9. Referencias

- **LLYC (2026).** "Espejismo de Igualdad: Sesgos de Género en la IA." Análisis de ~10.000 respuestas de 5 LLMs en 12 países. https://llyc.global/espejismo-de-igualdad/
- **Dwivedi et al. (2023).** "Breaking the Bias: Gender Fairness in LLMs Using Prompt Engineering and In-Context Learning." Rupkatha Journal. Reducción del 40% en sesgos mediante PE e ICL.
- **EMNLP 2025.** "Mitigating Gender Bias via Fostering Exploratory Thinking in LLMs." Técnica de pensamiento exploratorio y evaluación contrafactual.
- **RANLP 2025.** "Prompting Techniques for Reducing Social Bias in LLMs." Evaluación de System 2 prompting y CoT para debiasing.
- **NLPCC 2025.** "Detection, Classification, and Mitigation of Gender Bias in LLMs." Framework CoT + DPO para mitigación de sesgo.
- **PM-Workspace.** https://github.com/gonzalezpazmonica/pm-workspace

---

*Documento generado como estudio de implementación para Savia Flow y PM-Workspace.*
*la usuaria González Paz — Marzo 2026*
