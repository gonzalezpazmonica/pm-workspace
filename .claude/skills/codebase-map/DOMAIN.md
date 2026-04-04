# Codebase Map — Dominio

## Por que existe esta skill

pm-workspace tiene 500+ comandos, 49 agentes, 85+ skills y 40+ reglas de dominio.
Sin un mapa de dependencias, el routing de agentes alucina y las reglas huerfanas
se acumulan. Esta skill indexa las conexiones internas para reducir errores de routing.

## Conceptos de dominio

- **Grafo de dependencias**: red dirigida donde nodos son componentes y aristas son referencias @ o invocaciones
- **Hub**: regla con 5+ consumidores; punto critico cuyo cambio afecta a muchos comandos
- **Huerfano**: componente sin ningun consumidor; candidato a archivado o merge
- **Cadena critica**: secuencia de dependencias donde un cambio se propaga en cascada
- **In-degree/Out-degree**: cantidad de componentes que referencian/son referenciados por un nodo

## Reglas de negocio que implementa

- Semantic Hub Index (semantic-hub-index.md): clasificacion de hubs Tier 1/2/3
- Tool Discovery (tool-discovery.md): agrupacion por capability groups para mejor routing
- Context Health (context-health.md): detectar reglas nunca cargadas para optimizar contexto

## Relacion con otras skills

- **Upstream**: ninguna; se ejecuta como punto de partida para auditorias
- **Downstream**: hub-audit (consume el grafo para detectar hubs), context-optimize (usa datos de uso)
- **Paralelo**: doc-quality-feedback (ambas alimentan la auditoria de calidad del workspace)

## Decisiones clave

- Solo detecta referencias explicitas (@path, nombres en texto); no cubre invocaciones dinamicas del NL-resolver
- El grafo es estatico (snapshot), no se mantiene en tiempo real, para evitar coste continuo de contexto
- Output en markdown (no JSON) para legibilidad humana directa
