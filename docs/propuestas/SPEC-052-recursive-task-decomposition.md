# SPEC-052: Recursive Task Decomposition with Approval Gates

> Status: **DRAFT** | Fecha: 2026-03-30
> Origen: ComposioHQ/agent-orchestrator — LLM-driven task decomposer
> Impacto: PBIs complejos se descomponen recursivamente con aprobacion

---

## Problema

`/pbi-decompose` descompone un PBI en tasks de un solo nivel. No hay:

- Descomposicion recursiva (task compleja → sub-tasks → sub-sub-tasks)
- Clasificacion automatica atomico/compuesto antes de descomponer
- Contexto de linaje (cada subtask sabe de donde viene)
- Aprobacion humana entre descomposicion y ejecucion
- Limite de profundidad para evitar sobre-descomposicion

agent-orchestrator resuelve esto con un decomposer que clasifica tareas
como atomicas o compuestas, descompone recursivamente con lineage context,
y requiere aprobacion antes de ejecutar. Util para PBIs que cruzan
multiples modulos o requieren coordinacion entre agentes.

---

## Arquitectura

### Clasificacion atomico/compuesto

Antes de descomponer, el LLM clasifica la tarea:

```
Heuristicas de clasificacion:
- Feature unica, endpoint unico, componente unico → ATOMICO
- Multiples concerns independientes → COMPUESTO
- Profundidad >= max_depth → forzar ATOMICO
- En caso de duda → ATOMICO (lean toward simplicity)
```

### Arbol de descomposicion

```
PBI-123: "API de reservas con auth y notificaciones"
├── 1: "API CRUD de reservas" (atomico) → dotnet-developer
├── 2: "Autenticacion OAuth para reservas" (atomico) → dotnet-developer
└── 3: "Sistema de notificaciones" (compuesto)
    ├── 3.1: "Servicio de email" (atomico) → dotnet-developer
    └── 3.2: "Webhook de confirmacion" (atomico) → dotnet-developer
```

Cada nodo mantiene:
```json
{
  "id": "3.1",
  "title": "Servicio de email",
  "classification": "atomic",
  "depth": 2,
  "lineage": ["API de reservas con auth y notificaciones", "Sistema de notificaciones"],
  "agent": "dotnet-developer",
  "status": "pending",
  "spec_ref": null
}
```

### Flujo con approval gate

```
1. PM ejecuta /pbi-decompose-deep {PBI-ID}
2. LLM clasifica tarea raiz
3. Si compuesto: generar 2-7 subtareas, recursion en cada una
4. Max depth: 3 niveles (configurable)
5. Generar plan visual (arbol ASCII)
6. Estado: "review" — PM revisa el arbol
7. PM aprueba (total o parcial) o edita
8. Estado: "approved" — listo para ejecucion
9. Hojas atomicas se asignan a agentes via assignment-matrix.md
```

### Concurrencia entre hojas

Las hojas sin dependencias se ejecutan en paralelo (dag-scheduling).
Las dependencias se detectan por analisis de ficheros esperados:

```
Si hoja A escribe AuthService.cs y hoja B lo lee:
  B depende de A → serializar
Si hojas A y B no comparten ficheros:
  Paralelo → misma cohorte
```

---

## Integracion

### Con pbi-decomposition skill

El skill actual genera tasks de 1 nivel. Este spec extiende con:
- Flag `--recursive` para activar descomposicion profunda
- Flag `--max-depth N` para limitar profundidad (default 3)
- Sin flags: comportamiento actual (1 nivel, sin cambios)

### Con assignment-matrix.md

Cada hoja atomica se asigna al agente primario segun tipo de tarea
y language pack del proyecto. El arbol incluye agent sugerido.

### Con dag-scheduling skill

El arbol de descomposicion se convierte en DAG para ejecucion paralela.
Nodos sin dependencias forman cohortes. dag-plan visualiza el plan.

### Con autonomous-safety.md

La aprobacion es OBLIGATORIA antes de ejecutar. Estado "review"
bloquea ejecucion hasta confirmacion explicita del PM.
Cada subtarea se ejecuta en rama agent/* propia.

### Con spec-driven-development skill

Cada hoja atomica puede generar un spec (via /spec-generate) antes
de la implementacion. El lineage context enriquece el spec.

---

## Restricciones

- Max depth: 3 niveles (sobre-descomposicion degrada calidad)
- Min subtasks por nodo compuesto: 2 (evitar splits triviales)
- Max subtasks por nodo: 7 (cognitive load, Miller's law)
- Aprobacion humana OBLIGATORIA antes de ejecucion
- Lineage se pasa al LLM en cada nivel (contexto, no re-inventar)
- Budget: clasificacion ~200 tokens, descomposicion ~500 tokens por nodo
- Hoja atomica = maximo 1 spec, maximo 3 ficheros a modificar

---

## Implementacion por fases

### Fase 1 — Clasificacion y arbol (~2h)
- [ ] Clasificacion atomico/compuesto con LLM (Haiku para speed)
- [ ] Recursion con lineage context, max depth 3
- [ ] Output: plan.json + arbol ASCII. Test: PBI multi-modulo → arbol correcto

### Fase 2 — Approval gate + asignacion (~1.5h)
- [ ] Estado review/approved en plan.json
- [ ] Asignacion de agentes via assignment-matrix
- [ ] Test: PM aprueba parcialmente → solo hojas aprobadas se ejecutan

### Fase 3 — Integracion DAG (~1h)
- [ ] Conversion arbol → DAG con deteccion de dependencias por ficheros
- [ ] Integracion con dag-scheduling. Test: 3 hojas independientes → paralelo

---

## Ficheros afectados

| Fichero | Accion |
|---------|--------|
| `.claude/commands/pbi-decompose-deep.md` | Crear — comando recursivo |
| `.claude/skills/pbi-decomposition/SKILL.md` | Modificar — flag --recursive |
| `docs/rules/domain/parallel-execution.md` | Sin cambios (ya soporta DAG) |

---

## Metricas de exito

- PBIs complejos descompuestos sin intervencion manual: >80%
- Profundidad media del arbol: 1.5-2.0 (no sobre-descomponer)
- Hojas atomicas ejecutables sin preguntas al PM: >90%
- Tiempo de descomposicion (3 niveles, 10 hojas): <30s
