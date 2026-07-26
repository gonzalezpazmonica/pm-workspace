# SE-270 — Higiene del harness: skills, agentes, hooks, memoria y contexto al estado del arte 2026

**Status:** PROPOSED
**Fecha:** 2026-07-25
**Area:** Skills / Agents / Hooks / Memory / Context engineering
**Branch:** `agent/se270-harness-hygiene`
**Estimación total:** ~52h (7 slices independientes)
**Base verificada:** HEAD `90052f57` → re-verificado HEAD `33475de3` (PR #909)

---

## Origen

Investigación del ecosistema Claude Code / OpenCode (julio 2026) cruzada
con medición directa del repo. Hallazgo de encuadre: **Savia optimizó
comandos (SE-253), hooks a nivel de fan-out (SE-253 S4), agentes
(SE-265/266) y federación (SE-263), pero la capa de skills nunca se
auditó, y las disciplinas de memoria y contexto quedaron implícitas.**
Lo que sigue no son ideas nuevas: son prácticas que el ecosistema
convergió y que Savia cumple a medias, con la brecha medida.

### Lo que el ecosistema convergió (resumen de la investigación)

**Skills.** La descripción es lo único que el modelo ve al arranque, así
que debe escribirse como REGLA DE ENRUTADO —con frases-gatillo reales,
entradas esperadas y salida— y no como resumen; una descripción vaga
significa que la skill nunca se activa en el momento adecuado.
Divulgación progresiva en tres niveles (metadatos → cuerpo ≈5K tokens
máximo → ficheros referenciados), con referencias de UN SOLO NIVEL: un
fichero que apunta a otro que apunta a otro pierde al agente. Un autor
reporta ~40% de mejora en seguimiento de instrucciones al partir una
skill de 1.200 líneas en un SKILL.md de 200 más tres ficheros de apoyo.
Y código determinista para trabajo determinista: scripts para parsear,
validar y ordenar, en lugar de pedirle al modelo que tenga cuidado.

**Agentes.** Selección de modelo por agente es donde vive el control de
coste. Fan-out a exploradores paralelos conservando SOLO la conclusión,
no los volcados crudos. Los subagentes anidan (cadenas de hasta cinco
niveles a mediados de 2026), lo que hace obligatorio limitar
profundidad. Y el aviso operativo: un subagente que entra en bucle de
corrección —compila, falla, arregla, falla— puede drenar el saldo en
minutos; se recomienda mantener maxSteps bajo (5-10) para forzar la
parada y la consulta al humano.

**Hooks.** Cuatro tipos de handler: command (shell), prompt (evaluación
LLM de un turno), agent (subagente con herramientas para verificación) y
HTTP (nuevo en 2026). Exit code 2 es la herramienta de poder: en
PreToolUse detiene la herramienta; en Stop fuerza a Claude a seguir
trabajando. Presupuesto de latencia: cada PreToolUse añade latencia a
cada llamada que empareja, y la recomendación es mantenerlos por debajo
de 100 ms en el camino caliente, emparejando con regex específica sobre
el nombre de herramienta y no con `.*`. La regla de asignación más útil:
si la consecuencia de que el modelo lo ignore es una molestia menor, va
en documentación; si es un incidente de producción o pérdida de datos,
va en un hook.

**Memoria.** El survey de 2026 distingue cinco tipos cognitivamente
distintos, y señala un error de categoría frecuente: tratar la memoria
de trabajo (la ventana activa) como un problema de recuperación cuando
es un problema de PRESUPUESTO —se gestiona por compresión y priorización,
no por búsqueda—. Regla de escritura estricta: si un hecho cambia a
menudo, es local a una tarea o tiene confianza baja, va a estado de
sesión o artefacto, NUNCA a memoria permanente; así se evita que la
construcción de experiencia degenere en acumulación. Y la higiene:
decaimiento de confianza (lo reciente pesa más) con poda agresiva de
reflexiones antiguas de baja confianza, porque la memoria sin límite
degrada el rendimiento añadiendo ruido sin valor.

**Contexto.** Recuperación justo-a-tiempo con identificadores ligeros
(rutas, consultas) en vez de precargar. Dos modos de fallo con nombre
propio: *context rot* —efectos de umbral donde, pasada cierta fracción
de la ventana, la precisión cae bruscamente y no de forma gradual— y
*context collapse* —cuando un agente reescribe repetidamente su propio
contexto, cada reescritura tiende a la brevedad y erosiona el detalle de
dominio—. La propuesta de ACE (ICLR 2026) para el segundo: representar
el contexto como colección de ítems estructurados y actualizarlo
INCREMENTALMENTE en lugar de reescribir el bloque entero. Sobre
compactación, el aprendizaje de arnés más citado: nunca confiar reglas
críticas a la compactación —sobreviven la tarea actual, los errores
recientes y los nombres de fichero; se pierden las instrucciones
iniciales, las decisiones intermedias y las reglas de estilo—, así que
lo que no puede perderse vive en el prompt de sistema.

### Brecha medida en Savia (HEAD `33475de3`, PR #909)

| Capa | Medición | Práctica |
|---|---|---|
| Skills | descripción media **105 caracteres** | regla de enrutado ≈200-400 con gatillos |
| Skills | **24 de 137** usan `references/`; **23** SKILL.md >5KB | divulgación progresiva de 3 niveles |
| Skills | **0 con `tier:`** (SE-257 S5 nunca entregado) | tiering, ya aplicado a 558 comandos |
| Skills | **sin skill-creator** | meta-skill de autoría como estándar |
| Agentes | **0 con maxSteps**; 0 con `permission.task` declarado | tope de pasos y grafo de invocación cerrado |
| Hooks | **64 command / 0 http / 0 prompt**; **27 matchers amplios** | cuatro tipos según coste; emparejado estrecho |
| Memoria | **sin decay ni poda** | confianza decreciente + poda agresiva |
| Contexto | `context-rot-strategy` existe; sin política de compactación | JIT + compactación con política declarada |

## Objetivo (scope-down agresivo)

Llevar las cinco capas del arnés al estado del arte con medición
antes/después: enrutado de skills (S1), divulgación progresiva y tiering
(S2), autoría y consolidación de skills (S3), disciplina de agentes
(S4), tipos y presupuesto de hooks (S5), disciplina de escritura en
memoria (S6) y política de contexto (S7). Cero capacidades nuevas de
producto: es higiene del sustrato sobre el que corre todo lo demás.

## Out of scope explícito

- NO instalar frameworks externos (Superpowers, gstack): se adoptan
  PATRONES medidos, no dependencias.
- NO auto-mejora automática de skills sin anclaje externo (CRIT-030).
- NO adopción de herramientas con licencia restrictiva (CRIT-008).
- NO reescritura de la metodología SDD ni del Court.
- NO cambio de la semántica de niveles ni de la constitución.

---

## Slice 1 — Descripciones de skills como reglas de enrutado

**Problema:** 105 caracteres de media no enrutan. 94 de 137 skills tienen
<100 caracteres de descripción. Una skill que no se activa en el momento
correcto es coste de índice sin retorno, y su ausencia es invisible.

**Diseño mínimo:**
- **Norma de descripción** en la guía de estilo: responde *cuándo debo
  dispararme*, incluye frases-gatillo reales del usuario, nombra las
  entradas que espera y declara la salida. Rango objetivo 200-400
  caracteres.
- **Reescritura por lotes** de las descripciones con prompt de
  solo-descripción, cero cambios en el cuerpo, diff auditado.
- **Banco de activación** (`tests/skill-routing/cases.yaml`): por skill,
  >=3 peticiones que DEBEN activarla y >=2 vecinas que NO.
- **Detección de colisión**: dos skills cuyas descripciones compiten por
  los mismos gatillos → informe de solape.
- `skills-lint` en CI: descripción fuera de rango, sin gatillos, o sin
  salida declarada → warning.

**Acceptance criteria:**

AC-1.1. Banco de activación con casos; baseline de acierto medido ANTES
        de reescribir.
AC-1.2. Tras la reescritura: acierto de activación >=85% en positivos y
        >=90% en negativos sobre el banco.
AC-1.3. Cero cambios en cuerpos de SKILL.md en el lote de descripciones.
AC-1.4. Informe de colisiones entregado.
AC-1.5. skills-lint en CI operativo con las tres reglas.

**Esfuerzo:** 8h

---

## Slice 2 — Divulgación progresiva y tiering de skills

**Problema:** 23 SKILL.md superan 5KB y solo 24 usan `references/`.
Al activarse, una skill gorda entra entera en contexto. El tiering que
abarató 558 comandos nunca llegó a las skills (deuda del SE-257 S5).

**Diseño mínimo:**
- **Refactor de las 23 gordas**: SKILL.md ≤200 líneas con el
  procedimiento; el detalle a `references/*.md`. Referencias de un solo
  nivel.
- **Código determinista fuera del prompt**: scripts invocables donde la
  skill pide al modelo parsear, validar u ordenar.
- **Tiering** `tier: core|extended` con la mecánica de SE-253 S1.
- **Cierre honesto del SE-257 S5**: este slice lo entrega o lo declara
  ABANDONED.

**Acceptance criteria:**

AC-2.1. Las 23 skills >5KB refactorizadas: SKILL.md ≤200 líneas, detalle
        en references/, cero pérdida funcional.
AC-2.2. Lint de profundidad: referencia anidada plantada → CI en rojo.
AC-2.3. Índice de skills ≤2.4K tokens tras el tiering.
AC-2.4. Cero skills referenciadas por comandos core o agentes marcadas
        extended.
AC-2.5. SE-257 S5 archivado con estado explícito.

**Esfuerzo:** 8h

---

## Slice 3 — skill-creator propio y consolidación del catálogo

**Problema:** no existe meta-skill de autoría. Con 137 skills sin auditar,
el solape es probable.

**Diseño mínimo:**
- `skill-creator` propio: genera andamiaje con la norma del S1,
  estructura del S2, language-boundaries y CONSTITUCIÓN dentro.
- **Auditoría de solape**: matriz de similitud entre skills; pares por
  encima de umbral → propuesta de fusión (CRIT-004).
- **Política de ciclo de vida**: skill sin activaciones en N días →
  extended; sin activaciones en 2N → candidata a archivo con tombstone.

**Acceptance criteria:**

AC-3.1. Skill generada con skill-creator pasa skills-lint, lint de
        profundidad y trae >=3 casos de activación.
AC-3.2. Matriz de solape entregada; >=1 fusión propuesta o justificación.
AC-3.3. Política de ciclo de vida en tier-audit; skill sin uso → propuesta
        de degradación (test).
AC-3.4. skill-creator es el único camino documentado para crear skills.

**Esfuerzo:** 6h

---

## Slice 4 — Disciplina de agentes: presupuesto, profundidad y grafo cerrado

**Problema:** 0 de 81 agentes declaran tope de pasos. Un subagente en
bucle de corrección drena cuota en minutos.

**Diseño mínimo:**
- **Tope de pasos** por agente con default conservador por tier: fast
  5-8, mid 10-15, heavy declarado explícitamente.
- **Profundidad máxima de anidado** declarada globalmente (default 2).
- **Grafo de invocación cerrado**: `permission.task` explícito en los 81
  agentes con allowlist deny-by-default.
- **Fan-out con conclusión, no volcado**: agentes exploradores devuelven
  conclusión + rutas de evidencia.
- **Estado estructurado de subagente**: {completado | bloqueado | parcial
  | fallido} + motivo.

**Acceptance criteria:**

AC-4.1. Los 81 agentes con tope de pasos declarado.
AC-4.2. Profundidad: cadena sintética que excede el límite → rechazada.
AC-4.3. `permission.task` en el 100% de agentes.
AC-4.4. Grafo de invocación generado y commiteado; regenerable determinista.
AC-4.5. Explorador devuelve conclusión + rutas.
AC-4.6. Estado estructurado presente en el 100% de retornos.

**Esfuerzo:** 8h

---

## Slice 5 — Hooks: tipo de handler por coste y presupuesto de latencia

**Problema:** 64 handlers son `command`, hay 27 matchers amplios, y
ningún hook declara presupuesto de latencia.

**Diseño mínimo:**
- **Criterio de tipo de handler** documentado y aplicado.
- **Presupuesto de latencia**: cada hook declara su presupuesto;
  PreToolUse en camino caliente ≤100 ms.
- **Estrechar matchers**: los 27 amplios se sustituyen por regex específica.
- **Salida temprana barata**: patrón obligatorio de "descartar rápido".
- **Regla de asignación** publicada: molestia menor → documentación;
  incidente → hook.

**Acceptance criteria:**

AC-5.1. Distribución de tipos justificada.
AC-5.2. Presupuesto declarado en el 100% de hooks.
AC-5.3. Latencia p95 del camino caliente reducida >=30%.
AC-5.4. Cero matchers amplios sin justificación en línea.
AC-5.5. Regla de asignación en la guía de contribución.

**Esfuerzo:** 8h

---

## Slice 6 — Memoria: disciplina de escritura, decaimiento y poda

**Problema:** sin decaimiento ni poda, la memoria acumula. Sin regla de
escritura, todo aspira a ser permanente.

**Diseño mínimo:**
- **Regla de escritura**: un hecho va a memoria permanente SOLO si es
  estable, transversal y de confianza suficiente.
- **Separación explícita de tipos** (episódico rápido / semántico lento).
- **Decaimiento de confianza**: decrece con el tiempo salvo refuerzo.
- **Poda programada**: entradas bajo umbral → archivo con tombstone
  (cuarentena antes de borrado, CRIT-024).
- **Resolución de conflictos**: instrucción humana explícita gana siempre.

**Acceptance criteria:**

AC-6.1. Gate de escritura rechaza hechos volátiles/locales/baja-confianza.
AC-6.2. Decaimiento operativo: sin refuerzo pierde confianza.
AC-6.3. Poda con tombstone, recuperable.
AC-6.4. Conflicto: humano prevalece sobre alta confianza.
AC-6.5. Informe mensual de higiene de memoria en self-audit.

**Esfuerzo:** 8h

---

## Slice 7 — Contexto: recuperación justo-a-tiempo, compactación con política y anti-colapso

**Problema:** sin política de compactación declarada ni presupuesto de
ventana, Savia depende de la compactación por defecto.

**Diseño mínimo:**
- **Presupuesto de ventana con umbrales**: aviso y compactación en
  fracciones declaradas.
- **Política de compactación declarada**: qué debe sobrevivir siempre y
  qué puede caer.
- **Recuperación justo-a-tiempo**: identificadores ligeros en lugar de
  precargar contenido.
- **Actualización incremental de ficheros de contexto** (anti-colapso).
- **Detección de erosión**: pérdida de volumen sin retirada explícita.

**Acceptance criteria:**

AC-7.1. Compactación dispara en el umbral declarado.
AC-7.2. Política: elementos supervivientes siguen presentes.
AC-7.3. Constitución y línea_roja presentes tras compactación agresiva.
AC-7.4. JIT: flujo equivalente consume >=40% menos tokens.
AC-7.5. Incremental: diff acotado a ítems afectados.
AC-7.6. Erosión: pérdida sintética marcada en self-audit.

**Esfuerzo:** 6h

---

## Verification method

1. **Benchmark de arranque y turno** antes/después: índice de skills
   ≤2.4K tok (S2), latencia p95 de camino caliente −30% (S5), tokens de
   flujo con JIT −40% (S7).
2. **Banco de activación** (S1) como suite permanente.
3. **Adversariales permanentes en CI**: referencia anidada, invocación
   no allowlisted, exceso de profundidad, hook sobre presupuesto,
   escritura volátil en memoria permanente, humano vs memoria de alta
   confianza, constitución tras compactación, reescritura completa de
   fichero de contexto.
4. **Informe de higiene mensual** en /self-audit agregando: activación
   de skills, uso de agentes, latencia de hooks, memoria podada,
   erosión de contexto.
5. Gate de archivo (SE-258 S4) aplicado a esta spec y al SE-257 S5.

## Riesgos identificados pre-flight

- **R1 (S1): la reescritura de descripciones cambia el enrutado a peor.**
  Mitigación: baseline medido ANTES, banco de activación como gate.
- **R2 (S2): partir skills rompe procedimientos.** Mitigación: banco del
  S1 cubre las 23 refactorizadas.
- **R3 (S4): topes de pasos demasiado bajos cortan trabajo legítimo.**
  Mitigación: defaults por tier con override justificado.
- **R4 (S5): estrechar matchers deja un hueco de cobertura.**
  Mitigación: matriz de cobertura regenerada tras el slice.
- **R5 (S6): la poda descarta algo que hacía falta.** Mitigación:
  tombstone y cuarentena.
- **R6 (S7): la actualización incremental complica flujos.** Mitigación:
  se aplica solo a ficheros de contexto vivos.
- **R7 (transversal): 52h de higiene sin capacidad nueva visible.**
  Mitigación: cada slice con métrica propia y abandonable.

## Orden recomendado

1 → 2 → 5 → 4 → 7 → 6 → 3

## Decisión de adopción

Adoptar por slice según su métrica. Cada slice abandonable con registro
en specs-archive. Ninguno se adopta por alineamiento con el ecosistema:
se adopta si su número mejora.

## Referencias

- Investigación de ecosistema (julio 2026)
- Medición propia sobre HEAD `33475de3`: 137 skills (24 con references,
  23 >5KB, 0 con tier, descripción media 105 caracteres), 81 agentes (0
  con maxSteps, 0 con permission.task), 64 handlers de hook (64 command)
  y 27 matchers amplios, memoria sin decay ni poda.
- Sustrato Savia: tiering de comandos (SE-253 S1), dispatchers y
  hook-perf-gate (SE-253 S4), matriz de cobertura (SE-257 S3),
  memory-architecture y engrams (SE-256, SE-268 S4), delegación nativa y
  allowlist (SE-260 S2), self-audit (SE-258 S3), telemetría (SPEC-200),
  language-boundaries, deuda pendiente del SE-257 S5.
- Criterios: CRIT-004, CRIT-005, CRIT-008, CRIT-018, CRIT-024, CRIT-030,
  CRIT-031.
