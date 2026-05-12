# Language Boundaries — Bash para sistema, Python para datos

> **Rule #26** — Aplica al código de scripting bajo `scripts/` y al código de soporte (`tests/`, herramientas internas, hooks ejecutables, MCP servers locales). NO aplica a `.opencode/commands/*.md`, `.opencode/agents/*.md`, `.opencode/skills/*/SKILL.md`, ni a otros ficheros markdown que OpenCode interpreta como prompts.

## Alcance preciso

Esta regla rige el código que ejecuta lógica fuera del modelo: scripts del repo, wrappers, hooks ejecutables, herramientas de CI, MCP servers, módulos Python de soporte. Es decir, todo lo que se invoca como proceso del sistema desde la tool Bash de OpenCode o como subprocess de un MCP server.

**No rige los prompts y descripciones markdown que OpenCode lee:**
- Los comandos slash (`.opencode/commands/*.md`) son descripciones que OpenCode interpreta y convierte en prompts.
- Los agentes (`.opencode/agents/*.md`) son frontmatter + prompt que define el comportamiento del modelo.
- Las skills (`.opencode/skills/*/SKILL.md`) son guías textuales para el modelo.

Esos ficheros no son código en el sentido de esta regla. Pueden incluir bloques de comandos en cualquier shell que el modelo decida invocar; el modelo elige las tools que usa. La regla aplica al **destino** de esas tools cuando es código nuestro: si una skill instruye "ejecuta `scripts/foo.sh`", la regla rige `foo.sh`, no la skill.

## Core Mandate

Bash y Python tienen dominios disjuntos en el código de scripting. Mezclarlos genera scripts frágiles, difíciles de testear y que fallan de formas raras en producción.

**Bash** se usa exclusivamente para interactuar con el sistema operativo: ejecutar procesos, mover ficheros, leer variables de entorno, encadenar comandos vía pipes, invocar `git`, `curl`, `gh`, `docker`, gestionar sockets y signals.

**Python** se usa para todo lo que sea manipulación de datos estructurados: parsear o construir JSON, YAML, TOML, XML; validar payloads contra schemas; aplicar lógica condicional sobre estructuras anidadas; cálculos, agregaciones, transformaciones; serialización determinista; comparaciones semánticas; y cualquier algoritmo que no sea trivial.

## Heurística operacional

Si una línea de código contiene `jq`, `awk` o `sed` haciendo algo más complejo que una sustitución de un solo campo o un grep, ese código pertenece a Python. La presencia de `jq` con pipes anidados, `awk` con condicionales, o `sed` con regex no triviales es la señal canónica de que se cruzó la frontera.

Si un script bash crece más allá de unas 100 líneas y la mayoría de esas líneas no son invocaciones a comandos del sistema sino lógica, ese script ya es un programa Python disfrazado de bash. Reescribirlo.

## Prohibiciones

1. **No construir JSON con `printf` ni con concatenación de strings en bash.** Cualquier construcción de payload JSON, OTLP, OpenAPI request, o similar va en Python con `json` de stdlib.
2. **No parsear YAML con `grep` ni con `cut`.** Cualquier lectura de YAML va en Python con `pyyaml` (o `ruamel.yaml` si se necesita preservar comentarios).
3. **No validar schemas a mano en bash.** Validación contra JSON Schema, OTLP schema, o cualquier contrato estructurado va en Python con `jsonschema` o equivalente.
4. **No calcular hashes o firmas en bash con encadenamiento de comandos.** El cómputo va en Python con `hashlib`. Bash invoca el script Python.
5. **No comparar versiones semánticas con string comparison en bash.** Cualquier resolución de versiones (`>=4.0.0`, `~1.2.0`, ranges) va en Python con `packaging.version` o equivalente.
6. **No iterar sobre estructuras JSON anidadas con `jq` + bucles bash.** Si hay iteración, va en Python.

## Obligaciones

1. **Bash invoca Python como subprocess limpio.** Patrón canónico cuando se invoca desde la tool Bash de OpenCode: `result=$(python3 scripts/lib/foo.py arg1 arg2)`. El intercambio se hace por stdin/stdout o por ficheros, nunca por env vars rebuscadas.
2. **Cada herramienta Python del repo es invocable independientemente.** Sin imports relativos rotos, sin asumir cwd, sin depender del entorno del shell que la invocó. Cada script Python pasa `python3 scripts/lib/foo.py --help` con un help útil.
3. **Tests separados por capa.** Tests bash van en `.bats`. Tests Python van en `pytest`. No hay tests bats que validen lógica Python ni tests Python que validen flujo bash.
4. **Dependencias Python declaradas.** Cada herramienta Python que use librerías fuera de la stdlib lo declara en `requirements.txt` o `pyproject.toml` específico. No se instala nada implícitamente.
5. **MCP servers cuando aporten reutilización.** Si una herramienta Python expone funcionalidad útil más allá del workspace concreto (resolver, validador, exporter), considerar empaquetarla también como MCP server. La invocación local vía subprocess desde la tool Bash y la invocación remota vía MCP son dos caras de la misma lógica Python.

## Excepciones explícitas

1. **Hooks pre-write triviales.** Un hook que hace una verificación de un solo campo (ej. comprobar que un fichero no contiene cierto string) puede quedarse en bash con `grep -q`. En cuanto el hook necesita parsear el fichero como YAML/JSON, pasa a Python.
2. **Wrappers de CLI externas.** Un script que invoca `git`, `gh`, `az`, o cualquier CLI con argumentos preparados y devuelve su output sin transformarlo se queda en bash. Si transforma el output, pasa a Python.
3. **One-liners de instalación.** `install.sh`, `bootstrap.sh` y similares se quedan en bash porque su trabajo es exactamente "interactuar con el sistema": detectar OS, instalar paquetes, crear directorios, copiar ficheros.

## Consecuencias para specs futuros

Cualquier spec que declare "implementación en bash + jq" para algo que es manipulación de datos se rechaza en revisión y se reescribe declarando Python para la lógica y bash para el envoltorio. Esta regla aplica retroactivamente a SPEC-AGENTIC-FLOW-GRAPH, SPEC-AFG-COMPOSE, SPEC-SAVIA-MANIFEST, SPEC-AGENT-ARCHITECT y SPEC-FLOW-OBSERVABILITY.

## Deuda existente

Los scripts bajo `scripts/` que violan esta regla NO se migran de forma reactiva. Se marcan como deuda y se migran cuando se tocan por otra razón. La regla aplica de forma estricta a código nuevo y a refactors voluntarios. Auditoría inicial en SPEC-LANG-BOUNDARIES-AUDIT (futuro, opcional).

## Por qué esta regla existe

Bash es excelente para lo que fue diseñado: orquestar procesos del sistema. Es pésimo para todo lo demás. Cuando se le pide manipular datos estructurados, el código resultante:

- No tiene tipos. Errores que Python detectaría en parse-time se manifiestan en runtime.
- No es testable. Los frameworks de test bash son inferiores a pytest en uno o dos órdenes de magnitud.
- No es portable. Diferencias entre bash 3.2 (macOS), bash 5.x (Linux), zsh y dash producen bugs invisibles.
- No escala. Cada feature añade complejidad cuadrática a la lectura del script.
- Hace difícil la depuración. Sin stack traces útiles, sin debugger interactivo, sin REPL.

Python no es perfecto, pero para los problemas de manipulación de datos del repo es la herramienta correcta. Coherencia de stack es más valiosa que ahorrar el coste de invocar un subprocess.
