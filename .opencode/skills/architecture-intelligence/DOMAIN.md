# Architecture Intelligence — Dominio

## Por que existe esta skill

Los proyectos heredados o nuevos no siempre documentan su patron de arquitectura, y los desarrolladores asumen patrones incorrectos al implementar. Esta skill detecta automaticamente el patron real del codigo fuente mediante analisis de carpetas, imports, naming y configuracion, proporcionando un diagnostico objetivo con score de adherencia y violaciones concretas.

## Conceptos de dominio

- **Patron de arquitectura**: organizacion estructural del codigo (Clean, Hexagonal, DDD, CQRS, MVC, Microservices, etc.)
- **Score de adherencia**: puntuacion 0-100 que mide cuanto se ajusta el codigo al patron detectado (Alto mayor a 80, Medio 50-80, Bajo menor a 50)
- **Fitness function**: regla verificable automaticamente que valida una propiedad arquitectonica (ej: Domain no importa de Infrastructure)
- **Violacion**: incumplimiento de una regla del patron detectado, clasificada por severidad (CRITICAL, WARNING)
- **Language Pack**: conjunto de patrones especificos de cada lenguaje que complementan las reglas genericas

## Reglas de negocio que implementa

- Deteccion en 4 fases ponderadas: estructura carpetas (40%), imports (30%), naming (20%), configuracion (10%)
- Se reportan patron principal (score mas alto) y patrones secundarios (score mayor a 30)
- Dependencias inversas entre capas son CRITICAL; naming incorrecto es WARNING
- Cada lenguaje carga su reference especifico (patterns-{lang}.md) para markers propios

## Relacion con otras skills

- **Upstream**: codebase-map (mapa de dependencias que alimenta el analisis de imports)
- **Downstream**: agent-code-map (estructura de capas para generar .acm), spec-driven-development (patron detectado guia la implementacion)
- **Paralelo**: performance-audit (detecta anti-patrones complementarios al analisis estructural)

## Decisiones clave

- Algoritmo de 4 fases con pesos en vez de heuristicas simples, porque un solo indicador es insuficiente para distinguir patrones similares
- References separados por lenguaje en vez de un catalogo monolitico, para cargar solo los tokens necesarios
- Score numerico acumulativo en vez de deteccion binaria, porque los proyectos reales mezclan patrones
