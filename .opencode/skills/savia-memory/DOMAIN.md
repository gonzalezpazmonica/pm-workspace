# Savia Memory — Dominio

## Por que existe esta skill

Savia opera entre sesiones y necesita persistencia de decisiones, patrones y aprendizajes. Sin memoria externa, cada sesion empieza desde cero, perdiendo contexto de sesiones anteriores. Esta skill gestiona la memoria canonica en `.savia-memory/` como fuente unica de verdad entre sesiones.

## Conceptos de dominio

- **Memoria auto**: entradas de usuario, feedback, proyecto y referencia
- **Snapshots de sesion**: estado capturado al final de cada sesion
- **Memoria por proyecto**: contexto especifico de cada proyecto PM
- **Memoria de agentes**: historial publico/privado de agentes especializados
- **Shield maps**: mapas de mask/unmask para datos protegidos
- **Lazy reference**: solo se carga el indice al inicio; entradas especificas bajo demanda

## Reglas de negocio que implementa

- Hard cap de 200 lineas / 25 KB por fichero de indice
- Entradas < 150 caracteres en el indice
- Escritura via `scripts/memory-store.sh` (nunca edicion directa)
- Lectura inicial: solo `auto/MEMORY.md` (indice)
- Tipos de entrada: decision, pattern, context, feedback, lesson, reference

## Relacion con otras skills

- **Upstream**: savia-identity (la identidad determina que memoria cargar)
- **Downstream**: spec-driven-development (patrones de implementacion guardados), sprint-management (tendencias de velocity recordadas)
- **Paralelo**: todas las skills pueden escribir a memoria para persistir aprendizajes

## Decisiones clave

- Memoria externa al repo (`.savia-memory/`) para no mezclar datos operativos con codigo
- Protocolo lazy: no cargar toda la memoria al inicio para preservar contexto
- Indice centralizado (`auto/MEMORY.md`) como punto unico de entrada
