# Banking Architecture — Dominio

## Por que existe esta skill

Los proyectos bancarios operan bajo estandares arquitectonicos especificos (BIAN, ISO 20022, SWIFT) que los patrones genericos de arquitectura no cubren. Esta skill proporciona conocimiento especializado para validar arquitecturas contra el marco BIAN, auditar pipelines Kafka/EDA y verificar gobierno de datos en entornos de banca, evitando gaps de compliance que pueden resultar en sanciones regulatorias.

## Conceptos de dominio

- **BIAN (Banking Industry Architecture Network)**: estandar de dominios de servicio para arquitectura bancaria con metamodelo y catalogo de capacidades
- **ArchiMate**: notacion de modelado de arquitectura empresarial usada para representar capas BIAN
- **EDA (Event-Driven Architecture)**: patron basado en Kafka/MSK con Saga, CQRS y Event Sourcing tipico en banca transaccional
- **Data governance bancario**: lineage de datos, clasificacion, feature stores y data mesh aplicados a datos financieros regulados
- **MLOps bancario**: versionado, drift detection y auditoria de modelos ML en contextos financieros regulados

## Reglas de negocio que implementa

- La deteccion bancaria se activa con score mayor o igual a 55% en /banking-detect
- Las recomendaciones se marcan siempre como sugerencia tecnica, no asesoria legal
- Nunca acceder a datos financieros reales sin autorizacion explicita
- Las regulaciones varian por jurisdiccion (EU, US, LATAM, APAC) y deben especificarse

## Relacion con otras skills

- **Upstream**: architecture-intelligence (/arch-detect detecta proyecto bancario y sugiere /banking-bian)
- **Downstream**: regulatory-compliance (compliance sectorial complementario), diagram-generation (genera diagramas ArchiMate)
- **Paralelo**: vertical-finance (compliance SOX/PSD2), enterprise-analytics (metricas de equipo bancario)

## Decisiones clave

- Skill separada de vertical-finance porque banking-architecture cubre tooling tecnico (BIAN, Kafka, MLOps) mientras finance cubre compliance regulatorio (SOX, PSD2)
- References separados por dominio (BIAN, EDA, data governance) para cargar solo lo necesario en cada comando
- Score de deteccion mayor o igual a 55% como umbral para evitar falsos positivos en proyectos fintech que no requieren BIAN completo
