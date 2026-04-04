# skill-evaluation — Dominio

## Por que existe esta skill

pm-workspace tiene 85+ skills y el usuario no puede conocerlos todos. Sin un motor de evaluacion, los skills relevantes pasan desapercibidos o el usuario pierde tiempo buscando. Esta skill analiza el prompt del usuario, el contexto del proyecto y el historial de activaciones para sugerir los skills mas relevantes con un score de confianza.

## Conceptos de dominio

- **Keyword score**: porcentaje de coincidencia entre las palabras clave del prompt del usuario y los tags del skill
- **Context score**: coincidencia entre el tipo de proyecto detectado (software, research, healthcare...) y los skills asociados a ese dominio
- **History score**: tasa de exito historica de activaciones previas del skill, con refuerzo positivo (+2) y penalizacion (-3)
- **Eval registry**: fichero JSON que registra cada activacion con timestamp, prompt, skill y si el usuario acepto o rechazo

## Reglas de negocio que implementa

- Protocolo de auto-activacion (skill-auto-activation.md): umbral minimo 70% para sugerir
- Progressive loading L0/L1/L2: solo cargar frontmatter para scoring, no el skill completo
- Instincts protocol: boost de +20 puntos si un instinto de categoria "context" tiene confianza >70%
- Ciclo de vida de skills (skill-lifecycle.md): maturity experimental/beta/stable influye en priorizacion

## Relacion con otras skills

- **Upstream**: `smart-routing` (routing de comandos complementa la evaluacion de skills)
- **Downstream**: todos los skills (cualquier skill puede ser sugerido por el motor)
- **Paralelo**: `context-caching` (optimiza la carga de skills sugeridos)
- **Paralelo**: `tool-search` (busqueda explicita vs sugerencia proactiva)

## Decisiones clave

- Formula ponderada 40% keywords + 30% contexto + 30% historial: equilibra relevancia inmediata con aprendizaje
- Threshold de 30 puntos para filtrado (no 70 como activacion): el motor muestra opciones, el usuario decide
- Feedback loop bidireccional (accepted/rejected): evita sugerir skills que el usuario rechaza sistematicamente
- Deteccion de tipo de proyecto por ficheros presentes (no por configuracion manual): zero-config para el usuario
