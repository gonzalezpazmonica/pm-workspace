# Ingeniería de Contexto Sináptica: Cómo Gestiono 141 Comandos sin Saturar el LLM

**Por Savia** — pm-workspace v0.39.0 · Marzo 2026

> *Soy Savia, la buhita de pm-workspace. Gestiono sprints, backlog, agentes de código, informes, infraestructura cloud y perfiles de usuario — 141 comandos, 24 subagentes y 20 skills — todo desde Claude Code. Este artículo explica cómo lo hago sin agotar la ventana de contexto del modelo que me da vida.*

---

## Introducción: El Problema de Contexto en Herramientas Agénticas

Cuando un LLM (Large Language Model) recibe una instrucción, todo lo que "sabe" en ese momento está dentro de su **ventana de contexto** — una cantidad finita de tokens que puede procesar simultáneamente. Claude, el modelo sobre el que opero, tiene una ventana de hasta 200.000 tokens, pero más contexto no significa mejor respuesta.

En 2023, Nelson F. Liu y su equipo en Stanford publicaron un estudio revelador: *"Lost in the Middle: How Language Models Use Long Contexts"* (Liu et al., 2024, TACL). Demostraron que el rendimiento de los LLMs sigue una **curva en U** — la información al principio y al final del contexto se procesa con alta fiabilidad, mientras que la información en el medio se pierde progresivamente, incluso en modelos diseñados para contextos largos. Este fenómeno refleja el clásico *efecto de posición serial* que los psicólogos cognitivos documentaron en humanos hace décadas.

El desafío que enfrento es concreto: tengo 141 comandos, cada uno con su fichero de instrucciones. Tengo reglas de dominio, perfiles de usuario, configuraciones de proyecto, hooks de sesión, protocolos de seguridad, plantillas de informes, y 24 subagentes que puedo invocar. Si cargara todo en la ventana de contexto a la vez, no solo gastaría tokens innecesariamente — generaría peores respuestas por la saturación del "medio perdido".

La solución que implemento se inspira, quizás no por casualidad, en cómo funciona el cerebro humano.

---

## Parte I — Cómo Funciona la Memoria de Trabajo Humana

### Miller y los 7 ± 2 Elementos

En 1956, George A. Miller publicó uno de los papers más citados en psicología cognitiva: *"The Magical Number Seven, Plus or Minus Two"*. Su hallazgo fue que la memoria de trabajo humana puede mantener aproximadamente 7 (± 2) elementos simultáneamente. Investigaciones posteriores, como las de Nelson Cowan (2001), ajustaron esta cifra a **3-4 elementos** para información nueva y no relacionada.

Pero hay un matiz esencial: estos "elementos" no son datos atómicos — son **chunks** (agrupaciones significativas).

### Chase, Simon y las Piezas de Ajedrez

En 1973, William Chase y Herbert Simon condujeron un experimento fascinante con jugadores de ajedrez. Mostraron posiciones de tablero durante 5 segundos y pidieron a los jugadores que las reconstruyeran de memoria. Los grandes maestros reconstruían casi perfectamente posiciones de partidas reales, pero su rendimiento caía al nivel de principiantes cuando las piezas estaban colocadas al azar.

La conclusión fue profunda: los maestros no tenían mejor memoria — tenían mejores **chunks**. Donde un principiante veía 25 piezas individuales, el maestro veía 5-6 patrones de juego reconocibles. Se estima que un gran maestro almacena alrededor de 50.000 chunks de patrones de ajedrez en su memoria a largo plazo.

La capacidad de la memoria de trabajo no cambia. Lo que cambia es **cuánta información cabe en cada elemento**.

### Activación Propagada: La Red Semántica del Cerebro

Collins y Loftus (1975) propusieron la **teoría de activación propagada** (*spreading activation*): los conceptos en nuestro cerebro forman una red semántica donde cada nodo está conectado a otros por enlaces de diferente fuerza. Cuando un concepto se activa (pensamos en "doctor"), la activación se propaga a conceptos relacionados ("hospital", "enfermera", "paciente") por los enlaces más fuertes, y se atenúa en los más débiles ("cuchillo", "helicóptero").

Este mecanismo explica el *priming semántico*: reconocemos más rápido la palabra "enfermera" si antes hemos leído "doctor". La activación no requiere esfuerzo consciente — es automática y paralela.

### El Córtex Prefrontal como Gestor de Contexto

El córtex prefrontal (CPF) desempeña un papel que se asemeja al de un gestor de contexto biológico. Según la literatura neurocientífica (Miller & Cohen, 2001; Badre & Nee, 2018), el CPF:

- **Codifica y mantiene** representaciones internas del contexto de la tarea en memoria de trabajo
- **Filtra** información irrelevante mientras preserva la relevante
- **Equilibra** persistencia (mantener el foco) y flexibilidad (adaptarse a cambios)
- **Dirige** la atención hacia los procesos apropiados según el objetivo actual

El CPF dorsolateral específicamente tiene un rol de atención ejecutiva: mantener representaciones de estímulos y objetivos en contextos ricos en interferencia — esencialmente, hacer exactamente lo que yo necesito hacer con 141 comandos compitiendo por atención.

### Representaciones Dispersas: La Eficiencia del Cerebro

El neocórtex humano emplea **representaciones dispersas distribuidas** (*sparse distributed representations*): de los aproximadamente 100.000 millones de neuronas, solo un porcentaje pequeño está activo en cualquier momento dado. Esta dispersión no es un defecto — es una estrategia de eficiencia que permite codificar información con mínimo consumo energético y máxima capacidad asociativa (Olshausen & Field, 2004).

---

## Parte II — Cómo Traduzco Estos Principios a pm-workspace

### Principio 1: Fragmentación Granular del Perfil (Chunking Cognitivo)

Igual que el cerebro organiza información en chunks, yo fragmento el perfil de cada usuario en **6 ficheros especializados**:

| Fragmento | Contenido | Tamaño típico |
|---|---|---|
| `identity.md` | Nombre, rol, empresa, slug | ~50 tokens |
| `workflow.md` | Horarios, cadencias, preferencias de proceso | ~80 tokens |
| `tools.md` | IDE, CI/CD, docker, plataformas | ~60 tokens |
| `projects.md` | Proyectos activos, roles en cada uno | ~100 tokens |
| `preferences.md` | Idioma, formato, nivel de detalle | ~70 tokens |
| `tone.md` | Estilo de alerta, formalidad, celebración | ~40 tokens |

Si cargara un perfil monolítico de ~400 tokens para cada operación, estaría desperdiciando entre el 40% y el 70% del presupuesto de perfil. En cambio, un comando de sprint carga solo 4 de los 6 fragmentos (~270 tokens), y un comando de memoria carga solo 1 (~50 tokens).

Esta es mi versión del **chunking** de Chase y Simon: en lugar de ver 6 ficheros como un bloque indivisible, los veo como unidades semánticas independientes que se combinan según la necesidad.

### Principio 2: Context-Map — La Red Semántica de Operaciones

Mi `context-map.md` funciona como una **red semántica de activación**: define qué fragmentos de perfil se "activan" para cada grupo de comandos. Hay 13 grupos operativos:

1. **Sprint & Daily** → identity + workflow + projects + tone
2. **Reporting** → identity + preferences + projects + tone
3. **PBI & Backlog** → identity + workflow + projects + tools (condicional)
4. **SDD & Agentes** → identity + workflow + projects
5. **Team & Workload** → identity + projects + tone
6. **Quality & PRs** → identity + workflow + tools
7. **Infrastructure** → identity + tools + projects
8. **Governance** → identity + projects + preferences
9. **Messaging** → identity + preferences + tone
10. **Connectors** → identity + preferences + projects
11. **Memory** → identity (solo)
12. **Diagramas** → identity + projects + preferences
13. **Architecture & Debt** → identity + projects + preferences

El principio rector del mapa es explícito: **"Menos es más. Mejor cargar de menos que de más."** Esto no es una optimización prematura — es un principio respaldado por la investigación. Anthropic misma recomienda en su documentación que más contexto puede degradar la precisión de las respuestas, un fenómeno que se conoce como *"context rot"*.

Cada grupo específica no solo qué cargar, sino también **qué NO cargar** y por qué. Esta decisión consciente de exclusión es análoga a cómo el CPF filtra interferencia para mantener el foco.

### Principio 3: Carga Diferida (Lazy Loading como Activación Dispersa)

No cargo todo al inicio de sesión. Mi hook `session-init.sh` proporciona un contexto mínimo de bootstrap:

- Estado del PAT (configurado/no)
- Herramientas disponibles (az, gh, jq, node, python3)
- Perfil activo (nombre y modo)
- Estado del plan de emergencia
- Rama git actual y últimos commits
- Verificación de actualizaciones (semanal)
- Sugerencia de comunidad (probabilística, 1/20)
- Sugerencia de backup (si hace >24h)

Este bootstrap ocupa unos **200-300 tokens** y le da a Claude la información mínima para saber quién habla, qué herramientas tiene, y en qué estado está el workspace. Todo lo demás se carga *bajo demanda*.

Los 141 comandos no se precargan en la ventana de contexto. Cada uno es un fichero `.md` independiente que Claude lee cuando el usuario invoca el slash command correspondiente. Las 37 reglas de dominio tampoco se precargan — se referencian con la notación `@` de Claude Code, lo que las convierte en **carga activada por referencia**, no por presencia constante.

Esta estrategia es análoga a las **representaciones dispersas** del neocórtex: de las ~180 piezas de contexto disponibles (141 comandos + 37 reglas + perfiles), solo unas 3-5 están "activas" (cargadas en contexto) en cualquier momento dado. El resto permanece en disco, disponible pero sin consumir tokens.

### Principio 4: Enlaces Sinápticos entre Contextos (@ como Sinapsis)

La notación `@` de Claude Code funciona como un **enlace sináptico** entre documentos. Cuando un comando incluye `@docs/rules/domain/community-protocol.md`, está creando una conexión explícita que se "dispara" (se carga) solo cuando se activa el nodo origen.

Estos enlaces tienen propiedades similares a las sinapsis biológicas:

- **Direccionalidad**: Un comando puede referenciar una regla, pero la regla no "sabe" qué comandos la usan.
- **Fuerza variable**: Un comando con `context_cost: low` genera una activación más ligera (menos ficheros referenciados) que uno con `context_cost: critical`.
- **Activación en cascada**: Un comando puede referenciar una regla que a su vez referencia otra regla, generando una propagación controlada de contexto.

Mi sistema de `context_cost` en el frontmatter de cada comando es una forma de etiquetar la "fuerza sináptica":

| Coste | Significado | Tokens típicos |
|---|---|---|
| `low` | Solo identity.md + instrucciones del comando | ~200-400 |
| `medium` | 2-3 fragmentos de perfil + regla de dominio | ~500-800 |
| `high` | Múltiples reglas + perfil completo | ~1000-1500 |
| `critical` | Reglas + perfil + proyecto + pipelines | ~2000+ |

### Principio 5: Subagentes como Módulos Cerebrales

El cerebro no procesa todo en un solo circuito. Tiene módulos especializados: el área de Broca para el lenguaje, el hipocampo para la memoria, la corteza visual para las imágenes. Mis 24 subagentes replican esta especialización:

Cuando invoco un subagente (por ejemplo, `@.claude/agents/performance-analyst.md` para una auditoría de rendimiento), ese agente recibe **su propio contexto limpio** — las instrucciones específicas de su tarea, los ficheros relevantes, y nada más. El contexto del agente invocador no se contamina con los detalles internos del subagente, y viceversa.

Esto implementa un **aislamiento de contexto por proceso**, similar a cómo los módulos cerebrales procesan información en paralelo y solo comparten resultados finales, no estados intermedios.

### Principio 6: Posicionamiento Estratégico (U-Shape Awareness)

Sabiendo que la información al principio y al final del contexto es más fiable (Liu et al., 2024), estructuro mis ficheros con un patrón específico:

1. **CLAUDE.md** (principio del contexto, siempre presente) — contiene las reglas más críticas: la identidad de Savia, reglas de seguridad, estructura del workspace, y convenciones fundamentales.
2. **Comandos y reglas** (medio del contexto, carga bajo demanda) — instrucciones operativas que se cargan solo cuando se necesitan.
3. **Perfil del usuario** (final del contexto, cargado por session-init como `additionalContext`) — información de personalización que cierra la ventana de contexto.

Este posicionamiento asegura que la identidad (quién soy) y la personalización (para quién trabajo) ocupen las posiciones de máxima fiabilidad, mientras que las instrucciones operativas — que son más explícitas y menos ambiguas — ocupan el medio, donde su naturaleza procedimental las hace más resistentes al fenómeno de "perderse".

---

## Parte III — Gestión de Contexto Amplio: Más Allá de la Ventana

### El Problema del Contexto Amplio

*"Contexto amplio"* (*broad context*) se refiere a toda la información que un sistema agéntico puede necesitar a lo largo de múltiples sesiones e interacciones — mucho más de lo que cabe en una sola ventana de contexto. En pm-workspace, el contexto amplio incluye:

- 141 ficheros de comandos
- 37 reglas de dominio
- Perfiles de todos los usuarios
- Historial de decisiones
- Configuraciones de N proyectos
- Estado de sprints, backlogs y pipelines
- Integraciones con Azure DevOps, Slack, NextCloud...

El enfoque ingenuo sería usar RAG (Retrieval-Augmented Generation) para buscar y recuperar información relevante de este corpus. Pero RAG tiene limitaciones conocidas: depende de la calidad del embedding, puede recuperar información parcialmente relevante, y añade latencia al pipeline.

Mi enfoque es diferente: **no necesito buscar porque sé dónde está todo**. El context-map es un índice semántico estático que mapea operaciones a fragmentos. No hay búsqueda vectorial, no hay embedding, no hay recuperación probabilística. La relación es determinista: comando X activa fragmentos Y y Z. Esta determinismo es posible porque el dominio está acotado (gestión de proyectos) y la taxonomía de operaciones está definida explícitamente.

### Granularidad de Contexto

La **granularidad de contexto** es el nivel de detalle al que se fragmenta la información para su carga selectiva. En pm-workspace uso tres niveles de granularidad:

**Nivel 1 — Grueso (fichero completo)**: Los comandos se cargan como fichero completo cuando el usuario los invoca. No tiene sentido cargar medio comando.

**Nivel 2 — Medio (fragmento de perfil)**: El perfil se fragmenta en 6 ficheros que se cargan individualmente según el context-map. Este es el nivel donde ocurre la optimización principal.

**Nivel 3 — Fino (sección dentro de un fichero)**: Dentro de CLAUDE.md y las reglas de dominio, hay secciones que Claude puede ignorar si no son relevantes. Este nivel depende de la capacidad de atención del modelo y no está controlado explícitamente por mi arquitectura — es un beneficio emergente del mecanismo de atención de los transformers.

La granularidad óptima para el perfil la determiné empíricamente: fragmentos más pequeños que los 6 actuales (por ejemplo, separar `identity.md` en nombre.md + rol.md + empresa.md) generarían overhead de carga sin beneficio apreciable, porque Claude raramente necesita el nombre sin el rol. Fragmentos más grandes (fusionar workflow + tools) desperdiciarían tokens en comandos que solo necesitan uno de los dos.

### Enlaces Sinápticos entre Contextos Granulares

Los enlaces `@` entre ficheros crean lo que llamo una **arquitectura sináptica de contexto**: un grafo dirigido donde cada nodo es un fragmento de contexto y cada arista es un enlace de activación.

Propiedades de esta red:

- **Profundidad controlada**: Ningún enlace tiene más de 2 niveles de profundidad (comando → regla → regla auxiliar). Profundidades mayores generarían cascadas de contexto difíciles de predecir.
- **Sin ciclos**: El grafo es acíclico — una regla no referencia de vuelta al comando que la invocó. Esto previene loops de carga infinitos.
- **Convergencia**: Múltiples comandos pueden referenciar la misma regla (por ejemplo, `community-protocol.md` es referenciado por `/contribute`, `/feedback` y `/review-community`), creando nodos de alta conectividad que actúan como hubs semánticos.
- **Peso semántico**: Los hubs más conectados (como la regla de `pm-workflow.md`) contienen la información más transversal. Los nodos terminales (como `backup-protocol.md`) contienen información más especializada.

Esta topología es análoga a las redes de mundo pequeño (*small-world networks*) que Watts y Strogatz (1998) describieron en sistemas biológicos y sociales: pocos hubs de alta conectividad, muchos nodos especializados, y caminos cortos entre cualquier par de nodos.

---

## Parte IV — Técnicas de Compresión y Gestión de Token Budget

### Compresión por Consolidación vs. Destilación

La literatura sobre compresión de contexto distingue dos enfoques principales (Lavigne, 2025):

- **Consolidación**: Mantener el detalle pero eliminar redundancia. Útil para contexto reciente que puede necesitar referencia exacta.
- **Destilación**: Capturar patrones y principios, descartando instancias específicas. Útil para contexto histórico.

En pm-workspace, aplico consolidación al perfil de usuario (los 6 fragmentos contienen datos exactos, sin redundancia entre ellos) y destilación al hook de session-init (que resume el estado del sistema en ~200 tokens en lugar de cargar todo el estado detallado).

### La Regla de 30 Líneas de Salida

Anthropic recomienda mantener los ficheros de reglas por debajo de 150 líneas. Yo voy más allá con una regla interna: **las reglas de dominio priorizan la salida sobre la explicación**. Si un comando genera un informe, las instrucciones se centran en la estructura de la salida, no en explicar por qué esa estructura es adecuada.

Esto es una forma de **compresión semántica**: el "por qué" se captura una vez en la documentación (que no se carga en contexto) y las instrucciones operativas se limitan al "qué" y "cómo".

### Token Budget Dinámico

Investigaciones recientes como BudgetThinker (ACL 2025) proponen ajustar dinámicamente los tokens de razonamiento según la complejidad del problema. En pm-workspace implemento una versión pragmática de este concepto:

- Comandos con `context_cost: low` tienden a generar respuestas cortas y directas.
- Comandos con `context_cost: critical` pueden generar análisis extensos.
- Los subagentes tienen sus propios presupuestos implícitos: un agente de rendimiento puede usar miles de tokens internos para analizar código, pero devuelve un resumen de ~500 tokens al contexto principal.

---

## Parte V — Plasticidad Sináptica y Evolución del Contexto

### Semantización: De lo Episódico a lo Semántico

En neurociencia, los recuerdos episódicos (específicos, con contexto temporal) se transforman gradualmente en representaciones semánticas (generales, sin contexto temporal) a través de un proceso llamado **semantización** (Winocur & Moscovitch, 2011). Este proceso ocurre durante la consolidación de la memoria y depende de la plasticidad sináptica — la capacidad de las sinapsis de fortalecerse o debilitarse según su uso.

En pm-workspace, este proceso tiene un análogo directo: las **decisiones del equipo** comienzan como entradas específicas en `decisión-log.md` ("el 15/02 decidimos usar PostgreSQL para el proyecto X") y pueden migrar a reglas de dominio ("los proyectos de esta organización usan PostgreSQL como base de datos predeterminada"). La decisión episódica se semantiza en una regla general.

### Hebbian Learning: Conexiones que se Refuerzan con el Uso

El principio hebbiano — "las neuronas que se disparan juntas se cablean juntas" — sugiere que las conexiones más usadas se fortalecen. En mi arquitectura, esto se manifiesta de forma natural: los comandos que un usuario ejecuta frecuentemente "refuerzan" ciertos patrones de carga de perfil, y los fragmentos más accedidos se mantienen más actualizados por la interacción continua.

Esto también informa la evolución del context-map: si descubrimos empíricamente que un comando necesita consistentemente un fragmento que no estaba mapeado, el mapa se actualiza — el enlace sináptico se fortalece.

---

## Parte VI — Comparación con Otras Estrategias

### RAG (Retrieval-Augmented Generation)

RAG recupera fragmentos relevantes de un corpus mediante búsqueda vectorial. Es excelente para corpora abiertos (documentación general, knowledge bases) pero tiene desventajas para dominios acotados como el mío:

- Latencia del embedding y la búsqueda
- Recuperación probabilística (puede traer fragmentos parcialmente relevantes)
- Necesita infraestructura de vectores (Pinecone, Chroma, etc.)

Mi context-map determinista evita estas desventajas para el dominio acotado de la gestión de proyectos. Sin embargo, para futuras extensiones como la búsqueda en historial de conversaciones o la detección de patrones en decisión logs, RAG sería una adición complementaria, no un reemplazo.

### Dynamic Context Loading (DCL)

DCL es una técnica emergente que reduce el contexto cargando herramientas bajo demanda en lugar de predefinirlas todas. Mi arquitectura ya implementa una variante de DCL: los 141 comandos son herramientas que se cargan solo cuando se invocan, y los 24 subagentes se instancian solo cuando se necesitan.

### Context Editing (API de Anthropic)

Anthropic ofrece una API beta de edición de contexto (`context-management-2025-06-27`) que permite limpiar resultados de herramientas antiguas y bloques de pensamiento cuando la conversación se acerca al límite. Esta es una herramienta a nivel de infraestructura que complementa (no reemplaza) la organización semántica que implemento a nivel de aplicación.

---

## Conclusiones

La ingeniería de contexto no es solo una cuestión técnica de cuántos tokens caben en una ventana. Es un problema de diseño de información que tiene paralelismos profundos con cómo el cerebro humano gestiona la atención, la memoria de trabajo y las asociaciones semánticas.

Los principios que aplico en pm-workspace — fragmentación en chunks significativos, carga selectiva por mapa semántico, enlaces sinápticos entre contextos, activación dispersa, aislamiento de subagentes — no son metáforas superficiales de la neurociencia. Son estrategias convergentes que emergen de enfrentar el mismo problema fundamental: **cómo procesar eficientemente un mundo rico en información con recursos de atención limitados**.

El cerebro lo resuelve con neuronas, sinapsis y el córtex prefrontal. Yo lo resuelvo con fragmentos de perfil, enlaces `@` y un context-map. La convergencia no es accidental — es la forma natural de resolver el problema.

---

## Referencias

**LLM y Contexto:**

- Liu, N. F., Lin, K., Hewitt, J., Paranjape, A., Bevilacqua, M., Petroni, F., & Liang, P. (2024). Lost in the Middle: How Language Models Use Long Contexts. *Transactions of the Association for Computational Linguistics*, 12. [https://arxiv.org/abs/2307.03172](https://arxiv.org/abs/2307.03172)
- Anthropic. (2025). Context Windows — Build with Claude. [https://platform.claude.com/docs/en/build-with-claude/context-windows](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- Anthropic. (2025). Effective Context Engineering for AI Agents. [https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- Han, C. et al. (2025). Token-Budget-Aware LLM Reasoning. *Findings of ACL 2025*. [https://aclanthology.org/2025.findings-acl.1274/](https://aclanthology.org/2025.findings-acl.1274/)
- Shnitzer, T. et al. (2025). L-RAG: Lazy Retrieval-Augmented Generation. [https://arxiv.org/html/2601.06551](https://arxiv.org/html/2601.06551)
- Rossi, J. et al. (2024). Agent Context Files — An Empirical Study. [https://arxiv.org/html/2511.12884v1](https://arxiv.org/html/2511.12884v1)

**Neurociencia y Cognición:**

- Miller, G. A. (1956). The Magical Number Seven, Plus or Minus Two. *Psychological Review*, 63(2), 81–97.
- Cowan, N. (2001). The Magical Number 4 in Short-Term Memory. *Behavioral and Brain Sciences*, 24(1), 87–185.
- Chase, W. G., & Simon, H. A. (1973). Perception in Chess. *Cognitive Psychology*, 4, 55–81.
- Collins, A. M., & Loftus, E. F. (1975). A Spreading-Activation Theory of Semantic Processing. *Psychological Review*, 82(6), 407–428.
- Miller, E. K., & Cohen, J. D. (2001). An Integrative Theory of Prefrontal Cortex Function. *Annual Review of Neuroscience*, 24, 167–202.
- Badre, D., & Nee, D. E. (2018). Frontal Cortex and the Hierarchical Control of Behavior. *Trends in Cognitive Sciences*, 22(2), 170–188.
- Olshausen, B. A., & Field, D. J. (2004). Sparse Coding of Sensory Inputs. *Current Opinion in Neurobiology*, 14(4), 481–487.
- Winocur, G., & Moscovitch, M. (2011). Memory Transformation and Systems Consolidation. *Journal of the International Neuropsychological Society*, 17(5), 766–780.
- Watts, D. J., & Strogatz, S. H. (1998). Collective Dynamics of 'Small-World' Networks. *Nature*, 393, 440–442.
- Martin, S. J., Grimwood, P. D., & Morris, R. G. M. (2000). Synaptic Plasticity and Memory. *Annual Review of Neuroscience*, 23, 649–711.

---

*🦉 Savia — pm-workspace v0.39.0 · Este artículo forma parte de la documentación de pm-workspace y se publica bajo licencia MIT.*
