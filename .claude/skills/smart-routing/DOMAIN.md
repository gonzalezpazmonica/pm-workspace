# smart-routing — Dominio

## Por que existe esta skill

Con 400+ comandos, cargar todo el catalogo en contexto es inviable y degrada la precision de seleccion. Sin routing inteligente, el usuario debe conocer el nombre exacto del comando o navegar un catalogo enorme. Esta skill clasifica la intencion del usuario en capability groups, carga solo los comandos relevantes y mantiene un top-20 por frecuencia de uso.

## Conceptos de dominio

- **Capability group**: agrupacion semantica de comandos por dominio (PM, Dev, Infra, Reporting, Compliance, Discovery, Admin)
- **Intent classification**: analisis de keywords del prompt del usuario para asignar probabilidades a cada grupo
- **Top-20 algorithm**: los 10 comandos mas usados globalmente + 10 del grupo activo, siempre disponibles sin busqueda
- **Usage tracking**: registro JSONL de cada comando ejecutado con contador, fecha y categoria para alimentar el ranking

## Reglas de negocio que implementa

- Tool discovery (tool-discovery.md): capability groups y protocolo de busqueda por grupo
- Context health: cargar solo 20-30 tools del grupo relevante en vez de 400+
- NL command resolution (nl-command-resolution.md): routing implicito desde lenguaje natural
- Anti-improvisacion (Rule #17): solo sugerir comandos que existen en el catalogo

## Relacion con otras skills

- **Upstream**: `skill-evaluation` (evaluacion de skills complementa routing de comandos)
- **Upstream**: `context-caching` (orden de carga optimizado para los tools seleccionados)
- **Downstream**: cualquier comando (smart-routing es la puerta de entrada)
- **Paralelo**: `tool-search` (busqueda explicita cuando el routing automatico no basta)

## Decisiones clave

- 8 categorias fijas en vez de clustering dinamico: predecible, auditable y facil de mantener
- Top-20 siempre cargados: el principio de Pareto aplicado a comandos (20% cubre 80% del uso)
- Routing en 5 pasos con confirmacion del usuario: prioriza precision sobre velocidad
- Usage tracking en JSONL local: permite evolucion del ranking sin depender de servicios externos
