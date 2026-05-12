# AST Comprehension — Dominio

## Por qué existe esta skill

Los agentes de código fallan cuando modifican código ajeno sin entenderlo.
Leen 50 líneas del fichero, asumen el patrón global y rompen contratos implícitos.
Esta skill extrae la estructura completa mediante AST antes de cualquier edición,
dando al agente un mapa del territorio en lugar de navegarlo a ciegas.

Diferencia crítica con `ast-quality-gate`: ese skill pregunta "¿está bien
el código que generamos?". Este pregunta "¿qué hay aquí antes de tocar nada?".

## Conceptos de dominio

- **Mapa estructural**: representación jerárquica de clases, funciones, constantes
  y sus relaciones, extraída del AST sin ejecutar el código.
- **Surface API**: conjunto de símbolos públicos que otros módulos consumen.
  Modificar estos sin análisis previo rompe contratos silenciosamente.
- **Hotspot de complejidad**: función con complejidad ciclomática > 10.
  Indica lógica densa — el agente debe proceder con máxima cautela.
- **Call graph**: grafo de llamadas entre funciones. Revela dependencias
  ocultas que no aparecen en los imports.
- **Comprehension report**: informe JSON unificado con toda la información
  estructural de un fichero o directorio, language-agnostic.
- **Pre-edit context**: datos estructurales inyectados en el contexto del agente
  antes de que ejecute una edición, vía hook PreToolUse.

## Reglas de negocio implementadas

- **RN-COMP-01**: Antes de editar fichero existente > 50 líneas, extraer mapa
  estructural. Si complejidad máxima > 15, añadir advertencia explícita.
- **RN-COMP-02**: El mapa estructural NO modifica el fichero analizado.
  Es solo lectura. Fallo en extracción no bloquea la edición.
- **RN-COMP-03**: Para legacy assessment, mapear TODOS los ficheros incluyendo
  los de alta complejidad sin umbral de bloqueo.
- **RN-COMP-04**: El summary generado usa los nombres del código fuente, no
  los inventados. Prohibido fabricar propósitos no evidentes en el AST.
- **RN-COMP-05**: Si Tree-sitter no está instalado, degradar a extracción
  por grep-estructural. Nunca bloquear al agente por falta de herramienta.

## Relación con otras skills

- **Upstream**: invocado desde `/evaluate-repo`, `/legacy-assess`,
  `/comprehension-report`, y el hook PreToolUse antes de Edit
- **Downstream**: resultado alimenta `code-comprehension-report/SKILL.md`
  para generar informes de debuggabilidad
- **Paralelo**: `ast-quality-gate` valida output IA; `ast-comprehension`
  comprende input humano/legacy — son complementarios, no solapados

## Decisiones de diseño clave

- **Tree-sitter como denominador universal**: funciona en todos los lenguajes
  sin ejecutar código, sin dependencias de compilador. Degradación elegante
  si no está disponible.
- **No bloquea edición**: este hook es advisory, no blocker. Si la extracción
  falla (fichero binario, sintaxis rota), el agente sigue adelante.
- **Async en hook pre-edit**: demasiado lento para bloquear el flujo. El
  resultado se muestra como contexto informativo, no como gate.
- **JSON unificado idéntico al quality-gate**: facilita tools que consuman
  ambos tipos de análisis (calidad + comprensión) con el mismo parser.
