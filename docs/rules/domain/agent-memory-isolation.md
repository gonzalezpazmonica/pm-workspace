# Regla: Aislamiento de Memoria de Agentes — 3 Niveles

> **REGLA INMUTABLE** — Aplica a TODOS los agentes sin excepcion.

---

## Principio

La memoria de los agentes se separa en 3 niveles segun su naturaleza:
publica (best practices), privada (contexto personal) y de proyecto (datos del cliente).

---

## Tres niveles de memoria

### 1. Publica — `public-agent-memory/{agente}/MEMORY.md`

**En git**: SI — conocimiento generico que beneficia a cualquier usuario.

Contenido permitido:
- Patrones de arquitectura (DDD, SOLID, repository pattern)
- Buenas practicas de codigo (limites de metodos, async patterns)
- Reglas de seguridad genericas (vault patterns, regex de deteccion)
- Convenciones de testing (cobertura, traits, assertions)
- Clasificacion de severidad, triage generico

Agentes con memoria publica:
architect, code-reviewer, security-guardian, test-runner, triage,
coherence-validator, reflection-validator

### 2. Privada — `private-agent-memory/{agente}/MEMORY.md`

**En git**: NO — gitignored. Contexto personal del PM, equipo, forma de trabajar.

Contenido permitido:
- Decisiones de equipo y vocabulario interno
- Preferencias de comunicacion de stakeholders
- Convenciones especificas de la organizacion
- Historial de delegaciones y fallos recurrentes
- Feedback de implementacion y rechazos de specs
- Build quirks del entorno del PM

Agentes con memoria privada:
savia, business-analyst, commit-guardian, dotnet-developer, sdd-spec-writer

### 3. De proyecto — `projects/{proyecto}/agent-memory/{agente}/MEMORY.md`

**En git**: NO — dentro de projects/ que ya esta gitignored.

Contenido permitido:
- Datos del cliente y proyecto concreto
- Estado de procesamiento (reuniones procesadas, perfiles creados)
- Personas mencionadas, handles, relaciones
- Patrones tecnicos especificos del proyecto
- Lecciones de fallos en ESE proyecto

Agentes con memoria de proyecto:
meeting-digest, meeting-risk-analyst, meeting-confidentiality-judge,
y CUALQUIER agente cuando opera sobre un proyecto concreto.

---

## Orden de carga al iniciar tarea

Un agente DEBE leer sus memorias en este orden:

```
1. public-agent-memory/{agente}/MEMORY.md      (si existe)
2. private-agent-memory/{agente}/MEMORY.md      (si existe)
3. projects/{proyecto}/agent-memory/{agente}/MEMORY.md  (si hay proyecto activo)
```

Las tres fuentes se combinan. En caso de conflicto: proyecto > privada > publica.

## Orden de escritura al terminar tarea

Antes de escribir, el agente clasifica cada patron aprendido:

| Pregunta | Destino |
|---|---|
| Es una buena practica generica sin PII? | public-agent-memory/ |
| Contiene contexto personal, de equipo o de organizacion? | private-agent-memory/ |
| Contiene datos de un proyecto concreto? | projects/{proyecto}/agent-memory/ |

---

## Prohibido

```
NUNCA  -> Escribir en .claude/agent-memory/ (ruta legacy, eliminada)
NUNCA  -> Usar frontmatter "memory: project" (usa ruta legacy)
NUNCA  -> Datos de proyecto en public-agent-memory/ o private-agent-memory/
NUNCA  -> Datos personales/equipo en public-agent-memory/
NUNCA  -> Mezclar datos de un proyecto con otro
```

## Obligatorio

```
SIEMPRE -> Clasificar cada patron antes de escribir (public/private/project)
SIEMPRE -> Leer las 3 fuentes al iniciar (si existen)
SIEMPRE -> Max 150 lineas por MEMORY.md
SIEMPRE -> private-agent-memory/ en .gitignore
SIEMPRE -> public-agent-memory/ trackeado en git
```

## Justificacion

1. **Conocimiento compartido**: best practices en git, disponibles para la comunidad
2. **Privacidad personal**: contexto del PM nunca se publica
3. **Confidencialidad del cliente**: datos del proyecto aislados por silo
4. **RGPD**: supresion por nivel (borrar proyecto, borrar privada, mantener publica)
5. **Portabilidad**: clonar el repo da las best practices; la privada se restaura del backup
