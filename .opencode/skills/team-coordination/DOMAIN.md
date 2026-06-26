# team-coordination — Dominio

## Por que existe esta skill

Cuando una organizacion tiene multiples equipos, las dependencias cruzadas se convierten en la principal fuente de bloqueo y retraso. Sin visibilidad explicita de quien depende de quien, los bloqueos se descubren tarde y escalan mal. Esta skill orquesta la creacion de equipos, asignacion de miembros y deteccion proactiva de bloqueantes cross-equipo.

## Conceptos de dominio

- **Dependencia cross-equipo**: relacion declarada entre dos equipos, tipada como blocking, informational o shared-resource, con semaforo de estado (green/amber/red)
- **Dependency health**: porcentaje de dependencias en estado green, indicador principal de salud inter-equipo (objetivo: >=80%)
- **Capacidad FTE**: full-time equivalent de cada miembro, que puede ser <1.0 si esta en multiples equipos
- **Grafo de dependencias**: representacion de equipos como nodos y dependencias como aristas, con deteccion de ciclos y equipos aislados

## Reglas de negocio que implementa

- Team Topologies (Skelton & Pais): stream-aligned, platform, enabling y complicated-subsystem
- Regla de escalamiento: bloqueo <24h sync directo, 24-72h escalar a dept lead, >72h escalar a direccion
- Anti-patron de equipo >10 personas: dividir (regla de dos pizzas)
- Regla PII-Free: usar @handles en vez de nombres reales en reports exportables

## Relacion con otras skills

- **Upstream**: `capacity-planning` (capacidad por equipo alimenta la coordinacion)
- **Upstream**: `team-onboarding` (miembros nuevos se asignan via coordinacion)
- **Downstream**: `scaling-operations` (datos de equipos alimentan analisis de tier)
- **Downstream**: `portfolio-overview` (agregacion de metricas por equipo)

## Decisiones clave

- Dependencias declaradas en fichero deps.md por equipo: explicitas, auditables, versionadas en Git
- Tres tipos de dependencia (blocking/informational/shared-resource): suficientes para cubrir el 95% de los casos sin sobrecomplicar
- Deteccion de ciclos en el grafo: las dependencias circulares son criticas y se alertan inmediatamente
- Datos personales (salarios, rates) NUNCA en team.md: van en .flow-data/rates.json (gitignored)
