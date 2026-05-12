---
name: dag-scheduling
context: fork
---

# Dominio: Orquestación de agentes con DAG

## ¿Por qué existe esta skill?

El pipeline SDD secuencial reduce tiempo de entrega solo si todas las fases dependen unas de otras. En realidad, muchas son independientes y pueden ejecutarse en paralelo, reduciendo el tiempo total. Esta skill identifica oportunidades de paralelismo mediante análisis de dependencias (DAG) y orquesta múltiples agentes simultáneamente.

---

## Conceptos de dominio

| Concepto | Definición |
|----------|-----------|
| **DAG** | Grafo acíclico dirigido: representa dependencias sin ciclos |
| **Cohorte** | Conjunto de fases que pueden ejecutarse en paralelo |
| **Camino crítico** | Secuencia más larga desde inicio a fin |
| **Holgura** | Tiempo máximo que una fase puede retrasarse sin impactar total |
| **Worktree** | Copia aislada del repo; cada agente paralelo usa una |
| **Wave Executor** | Motor genérico de ejecución paralela (`scripts/wave-executor.sh`) |

---

## Reglas de negocio

| Regla | Referencia |
|-------|-----------|
| Max 5 agentes paralelos simultáneos | SDD_MAX_PARALLEL_AGENTS |
| Cada agente aislado en worktree | parallel-execution.md |
| Validar sin conflictos de escritura | parallel-execution.md |
| Timeout 30 min por agente | parallel-execution.md |
| Recuperación automática x1 si falla | parallel-execution.md |

---

## Relaciones

**Upstream** (prerequisito):
- spec-driven-development — DAG ejecuta SDD en paralelo

**Downstream**: ninguno

**Paralelo**:
- spec-driven-development — ejecución secuencial
- dev-session-protocol — orquestación de slices

---

## Decisiones clave

1. DAG vs secuencial: Análisis automático de dependencias vs pure secuencial
2. Límite de 5 agentes: Equilibrio latencia-throughput
3. Worktree aislamiento: Evita race conditions
4. Reintento x1: Resilencia sin loops infinitos
5. Wave executor genérico: Motor reutilizable, no DAG-específico (SPEC-WAVE-DAG)
