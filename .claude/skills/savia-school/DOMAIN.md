# savia-school — Dominio

## Por que existe esta skill

Savia School adapta pm-workspace para entornos educativos donde los usuarios son estudiantes, potencialmente menores de edad. Sin esta skill, no existirian las garantias de privacidad, cifrado y cumplimiento RGPD que requiere la legislacion europea para datos de menores. Proporciona el marco de seguridad, matriculacion por alias, evaluacion con rubricas y gestion del portfolio del estudiante.

## Conceptos de dominio

- **Alias de estudiante**: identificador anonimo que reemplaza el nombre real en todos los artefactos, cumpliendo minimizacion de datos RGPD
- **Rubrica**: criterios de evaluacion estructurados con niveles de logro que el profesor define y aplica a los proyectos
- **Portfolio**: coleccion versionada de proyectos, evaluaciones y reflexiones de un estudiante a lo largo del curso
- **Derecho al olvido (Art. 17)**: supresion completa de todos los datos de un estudiante, incluyendo evaluaciones cifradas y audit trail
- **Cifrado AES-256**: todas las evaluaciones y datos personales se cifran en reposo con clave protegida (permisos 0600)

## Reglas de negocio que implementa

- RGPD Arts. 5, 13, 15, 17: minimizacion, transparencia, acceso y supresion
- LOPD Organica 3/2018: proteccion de menores en entornos educativos
- AEPD: orientaciones sobre menores y entornos digitales educativos
- Principio foundacional #4: privacidad absoluta (datos nunca salen del servidor)

## Relacion con otras skills

- **Upstream**: `regulatory-compliance` (marcos regulatorios que School aplica al contexto educativo)
- **Downstream**: `evaluations-framework` (School usa rubricas para evaluar proyectos)
- **Paralelo**: `vertical-education` (vertical de compliance educativo complementa School)
- **Paralelo**: `team-onboarding` (patron similar de incorporacion, adaptado a estudiantes)

## Decisiones clave

- Alias obligatorios en vez de nombres reales: el dato mas seguro es el que no existe
- Cifrado en reposo de evaluaciones porque contienen juicios sobre menores
- Retencion cero dias tras salida del estudiante (excepto incidentes: 7 anos por obligacion legal)
- El diario del estudiante NO es accesible por padres por defecto: es un espacio de reflexion propio
