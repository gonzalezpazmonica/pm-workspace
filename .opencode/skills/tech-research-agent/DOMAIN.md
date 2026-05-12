# Tech Research Agent — Dominio

## Por qué existe esta skill

Antes de tomar decisiones arquitectónicas, el Tech Lead necesita investigar alternativas con datos concretos. Esta skill delega la fase de recopilación de información a un agente autónomo que genera informes estructurados con recomendaciones accionables, sin modificar código ni tomar decisiones.

## Conceptos de dominio

- **Research program**: Instrucciones declarativas en markdown que definen objetivo, criterios, alternativas y restricciones — inspirado en el `program.md` de autoresearch
- **Informe de investigación**: Documento estructurado con contexto, alternativas evaluadas, comparativa, riesgos y recomendación marcada como propuesta
- **Nivel de confianza**: Cada afirmación del agente se acompaña de alto/medio/bajo según la evidencia disponible

## Reglas de negocio que implementa

- RN-AUT-01: Ningún agente autónomo tiene autoridad para decisiones irreversibles
- RN-AUT-04: Las recomendaciones de investigación son PROPUESTAS, no acciones

## Relación con otras skills

- **Upstream**: Decisión arquitectónica pendiente o evaluación de tecnología solicitada
- **Downstream**: ADR (Architecture Decision Record) si el humano aprueba la recomendación
- **Paralela**: `architecture-intelligence` (detección de patrones vs investigación activa)

## Decisiones clave

- Se eligió solo generar informes (sin PRs ni código) para minimizar riesgo de acción no supervisada
- Se exige citar fuentes en cada afirmación para prevenir alucinaciones
- El patrón program.md permite reutilizar programas de investigación entre proyectos
