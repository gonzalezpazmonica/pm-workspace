# SE-269 — Patrones BMAD: forja de ideas, veredicto ternario, revision humana guiada y calibracion adversarial

**Status:** APPROVED (post-review v2: SE-255→SE-257 fix, unified data contract, cold-start paths, hardened AC-5.4, dependency table, ROI estimates)
**Fecha:** 2026-07-23
**Area:** Analysis phase / Gates / Human review / Judge calibration / Docs distribution
**Branch:** agent/se269-bmad-patterns
**Estimacion total:** ~28h (5 slices independientes)
**Base verificada:** HEAD a1178820 (#907, SE-268 mergeado)
**Inspirado por:** BMAD Method v6 (bmad-code-org, docs.bmad-method.org). Conceptos adoptados con atribucion; implementacion propia. Verificar licencia antes de transcribir texto literal alguno.

---

## Origen

Analisis comparativo BMAD Method vs Savia v6.15.0+. Conclusion de
encuadre: BMAD es un metodo de SDLC asistido por IA optimizado para
ADOPCION (multi-frontend, marketplace de modulos, comunidad); Savia es un
sistema agentico soberano optimizado para CRITERIO (constitucion con
enforcement, niveles de confidencialidad, federacion, memoria). Se
solapan fuertemente en la cadena spec→story→dev→review y divergen en
todo lo demas.

De ese solape emergen cinco patrones donde BMAD resuelve algo que Savia
NO tiene, verificado en repo:

1. **No existe fase de analisis previa a la spec.** Savia salta de la
   idea a `spec-generate`/`spec-design`. Cero comandos de brainstorming
   facilitado, pressure-testing de ideas, working-backwards o
   elicitacion avanzada (verificado: sin brainstorm/forge/prfaq/elicit
   en commands). BMAD tiene una fase completa cuyo nucleo es
   `bmad-forge-idea`: interrogatorio socratico una pregunta cada vez, con
   modo de ataque adversarial, que termina en un veredicto ternario —
   la idea se endurece, se demuestra, o muere barata. Consecuencia para
   Savia: las specs nacen sin haber sido presionadas, y el coste de una
   idea mala se paga en implementacion, no en analisis.

2. **Los gates de Savia son binarios.** `release-readiness` existe
   (post-desarrollo) pero no hay gate pre-implementacion, y la familia
   de gates actual bloquea o pasa. BMAD usa veredicto ternario
   PASS/CONCERNS/FAIL en su chequeo de preparacion. La banda CONCERNS es
   la aportacion: hoy un hallazgo relevante-pero-no-bloqueante fuerza a
   Savia a elegir entre falso bloqueo o falso verde.

3. **La revision humana no tiene artefacto propio.** Savia tiene 15+
   jueces (correctness, architecture, cognitive, coherence, completeness,
   compliance, concession, calibration, authority-claim...) y el bounded
   review del SE-260: maquina-a-maquina de primer nivel. Falta lo que
   hace EFICIENTE al revisor humano. BMAD lo tiene: revision ordenada por
   preocupacion (seguridad→rendimiento→logica→estilo), con un orden de
   lectura sugerido escrito por el autor de la spec cuando existe (y
   generado del diff cuando no, reconociendo que el generado es de peor
   calidad pero mejor que leer en orden de fichero), y — el detalle mas
   util — de 2 a 5 formas de observar manualmente el cambio funcionando,
   no comandos de test automatizados, con la nota explicita de que si el
   cambio no tiene comportamiento visible, se dice, sin inventar trabajo.

4. **Los jueces adversariales de Savia no declaran su tasa de falsos
   positivos.** BMAD documenta honestamente el modo de fallo del patron:
   como la IA recibe la instruccion de encontrar problemas, encontrara
   problemas aunque no existan, y hay que esperar falsos positivos —
   nimiedades disfrazadas de incidencias, malentendidos de intencion, o
   preocupaciones directamente alucinadas — siendo el humano quien
   decide que es real. Savia tiene mas jueces que BMAD y ninguna
   medicion de su ruido. Con la infraestructura de calibracion del
   SE-258 S3 (self-audit) y SE-257 S1 (CRITERIO) ya construidas, esto es
   aplicar a los jueces lo que Savia ya se aplica a si misma.

5. **La documentacion no se distribuye para consumo por IA.** BMAD
   publica un fichero de texto plano consolidado con la referencia
   completa (mas un indice), pensado para que un agente lo cargue de una
   vez. Savia tiene 1.637 documentos y ninguna forma barata de que otra
   instancia — o un evaluador externo — cargue su contexto. Alineado con
   CRIT-010 (usable por todas las personas) a coste minimo.

**NO se adopta (con motivo):** agentes con nombre y persona, y el modo
"party" de debate entre personajes — chocan de frente con el precedente
anti-biomimetic-theater (brainless-patterns archivado DO NOT MERGE) y con
el articulo T3 (prohibido afirmar estados internos). El debate
multi-perspectiva que aporta valor Savia ya lo tiene sin personas: el
Court. Tampoco se adopta el marketplace ni el soporte multi-frontend:
Savia es OpenCode-only por decision registrada.

## Objetivo (scope-down agresivo)

Añadir la fase de forja previa a la spec (S1), introducir el veredicto
ternario en los gates de decision (S2), producir el paquete de revision
humana que complementa al Court (S3), calibrar el ruido de los jueces
adversariales (S4) y publicar la documentacion en formato consumible por
IA (S5). Cero reescritura de la cadena SDD existente: se añade delante,
se afina en medio, se mide lo que ya corre.

## Out of scope explicito

- NO personas ni agentes con nombre; NO party mode con personajes.
- NO marketplace, multi-frontend ni web bundles (decision OpenCode-only).
- NO reescritura de spec-generate/spec-design/spec-review ni del Court:
  S1 alimenta la cadena, S4 la mide, ninguno la sustituye.
- NO nuevo sistema de memoria: el residuo de decision de la forja se
  escribe en el sustrato existente (engrams SE-256), no en un almacen
  nuevo (CRIT-004, consolidar antes que proliferar).
- NO veredicto ternario en gates de seguridad o linea_roja: alli el
  binario fail-closed es correcto y CONCERNS seria una puerta trasera
  (ver S2, restriccion dura).

---

## Slice 1 — Forja de ideas: presion socratica con veredicto ternario

**Problema:** las specs de Savia nacen de una idea no presionada. El
coste de una idea mala se descubre implementando.

**Diseño minimo:**
- `/forge-idea <idea|fichero>`: interrogatorio de UNA pregunta cada vez
  en orden de dependencia (no cuestionario en bloque: la respuesta N
  condiciona la pregunta N+1). Cada pregunta pone sobre la mesa una
  respuesta recomendada contra la que empujar — es mas facil corregir
  una propuesta que rellenar un vacio.
- **Modo de ataque adversarial** activable: el mismo hilo, con mandato de
  buscar el fallo (supuesto no verificado, coste oculto, alternativa mas
  simple, evidencia contraria). Reutiliza los jueces existentes como
  lentes, sin personas: la lente es un mandato, no un personaje.
- **Contraste contra material propio**: si el workspace tiene proyecto
  activo, las afirmaciones de la idea se contrastan contra el KG, las
  specs archivadas y el CRITERIO (una idea que contradice un CRIT
  linea_roja muere en la forja, no en revision).
- **Veredicto ternario**: ENDURECIDA (destilado listo para alimentar
  spec) | MAS_CLARA (avance parcial, preguntas abiertas registradas) |
  MUERTA (con el motivo escrito: morir barato es exito del comando, no
  fallo).
- **Residuo de decision**: cada sesion de forja deja las decisiones y su
  porque como engram (SE-256), no solo el resultado. El "por que
  descartamos X" es lo que se pierde hoy y lo que evita repetir el
  debate en tres meses.
- **Salida encadenable**: el destilado de una idea ENDURECIDA es entrada
  valida de `spec-generate` y del analisis de requisitos (SE-267 S1) sin
  reescritura manual.

**Acceptance criteria:**

AC-1.1. Sobre 3 ideas reales (una que debe endurecer, una difusa, una
        inviable), el comando produce los tres veredictos correctos con
        el motivo escrito; el juicio se contrasta a ciegas con el de la
        operadora sobre las mismas 3 (coincidencia >=2/3 o se recalibra
        el criterio de veredicto antes de adoptar).
AC-1.2. Una pregunta cada vez, en orden de dependencia: el flujo NUNCA
        emite dos preguntas sin respuesta intermedia (asercion sobre la
        traza).
AC-1.3. Idea que contradice un CRIT linea_roja → veredicto MUERTA
        citando el CRIT, sin llegar a spec (test adversarial).
AC-1.4. Destilado de idea ENDURECIDA consumido por spec-generate sin
        edicion manual (demo E2E).
AC-1.5. Residuo: la sesion deja engram consultable con >=1 decision y su
        motivo; recuperable por el contexto de la cupula activa (test).
AC-1.6. Coste acotado: sesion de forja <=20 turnos por defecto, con
        corte y veredicto MAS_CLARA al agotarse (no hay forja infinita).

**Esfuerzo:** 8h

---

## Slice 2 — Veredicto ternario y gate de preparacion pre-implementacion

**Problema:** los gates binarios de Savia fuerzan a elegir entre falso
bloqueo y falso verde ante hallazgos relevantes-pero-no-bloqueantes. Y
no existe gate ANTES de implementar (release-readiness llega tarde).

**Diseño minimo:**
- **Veredicto ternario como formato de salida** de los gates de juicio:
  PASA | RESERVAS | FALLA, con la semantica escrita: RESERVAS = puede
  avanzar CON registro explicito de la reserva y su dueño; no es "pasa
  con matices" ni "falla suave".
- **Restriccion dura**: los gates de seguridad, confidencialidad y
  linea_roja NO admiten RESERVAS. Alli el binario fail-closed es la
  semantica correcta (CRIT-023) y una banda intermedia seria una puerta
  trasera. El ternario aplica a gates de JUICIO (preparacion, calidad de
  spec, madurez de diseño), nunca a los de FRONTERA.
- **`/implementation-readiness <spec>`**: gate previo a codificar que
  verifica que la spec tiene ACs falsificables, out-of-scope explicito,
  riesgos con mitigacion, trazabilidad a requisito o BR, y slices con
  hito utilizable. Reutiliza la rubrica del SE-267 S2 si existe; si no,
  la instancia. Emite el ternario con informe por dimension.
- **Las RESERVAS son deuda registrada**: cada una entra como follow-up
  con dueño y, si sigue abierta al cierre del spec, aparece en el
  archivo (gate SE-258 S4). Una reserva que nadie ve es un falso verde
  con mejor prensa.

**Acceptance criteria:**

AC-2.1. Las tres bandas se producen sobre 3 specs reales de distinta
        madurez, con informe por dimension (no veredicto opaco).
AC-2.2. Restriccion dura: intento de emitir RESERVAS desde un gate de
        seguridad/confidencialidad/linea_roja → rechazado por
        construccion (test adversarial).
AC-2.3. RESERVAS genera follow-up con dueño; reserva abierta al cierre
        aparece en el archivo del spec (test E2E).
AC-2.4. Spec sin ACs falsificables → FALLA con la dimension señalada
        (test con spec sintetico defectuoso).
AC-2.5. Tasa de uso auditada: si >70% de veredictos son RESERVAS en la
        ventana mensual, el self-audit lo marca — un ternario que
        siempre cae en la banda intermedia es un binario cobarde.

**Esfuerzo:** 5h

---

## Slice 3 — Paquete de revision humana (checkpoint)

**Problema:** el Court revisa maquina-a-maquina; el revisor humano
recibe un diff y un veredicto. Falta el artefacto que hace su revision
eficiente.

**Diseño minimo:**
- `/review-checkpoint <PR|rama>`: genera un paquete de revision con
  cinco secciones:
  1. **Que cambio y por que**, ligado a la spec/BR de origen.
  2. **Orden de lectura sugerido**: si el autor lo declaro en la spec, se
     usa; si no, se genera del diff y del contexto — declarando que es
     generado, porque un recorrido generado es peor que uno del autor y
     mucho mejor que leer en orden de fichero.
  3. **Hallazgos ordenados por preocupacion**: seguridad → rendimiento →
     logica → estilo. De los hallazgos del Court NO se listan los ya
     corregidos, sino las decisiones que el revisor debe conocer.
  4. **Verificacion manual**: de 2 a 5 formas de observar el cambio
     funcionando — una interaccion, un comando, una peticion — con
     resultado esperado. No son comandos de test automatizado (esos ya
     corrieron): son observaciones que construyen confianza. Si el
     cambio no tiene comportamiento observable, se dice explicitamente;
     prohibido inventar trabajo.
  5. **Cierre**: aprobar, rehacer o seguir discutiendo.
- **Integracion con el ciclo acotado** (SE-260 S1): el checkpoint se
  genera DESPUES del freeze, con los hallazgos ya congelados; no reabre
  el bucle de revision.
- **Integracion con el certificado QA** (SE-267 S3 si existe): el
  paquete cita el certificado, no lo sustituye — uno prueba que los
  tests pasaron, el otro ayuda a mirar lo que los tests no ven.

**Acceptance criteria:**

AC-3.1. Paquete generado para 3 PRs reales de distinta naturaleza (UI,
        dominio, infraestructura) con las 5 secciones completas.
AC-3.2. Orden de lectura: si la spec lo declara, se respeta literalmente;
        si no, se genera Y se etiqueta como generado (dos tests).
AC-3.3. Verificacion manual: entre 2 y 5 observaciones con resultado
        esperado; cambio sin comportamiento observable → lo declara y
        emite cero observaciones (test — este es el AC anti-relleno).
AC-3.4. Cero hallazgos ya corregidos en la seccion 3 (asercion contra el
        ledger de correccion del bounded review).
AC-3.5. Tiempo de revision humana medido en el piloto: reduccion >=30%
        frente a revisar el mismo PR sin paquete (2 PRs comparables,
        medicion honesta con su n pequeño declarado).

**Esfuerzo:** 6h

---

## Slice 4 — Calibracion adversarial de los jueces

**Problema:** Savia instruye a 15+ jueces para encontrar problemas, y un
juez instruido para encontrar problemas los encuentra aunque no existan.
Nadie mide cuanto de lo que reportan es ruido.

**Diseño minimo:**
- **Registro de veredicto por hallazgo**: cada hallazgo de juez recibe
  disposicion humana {aceptado | descartado-nimiedad |
  descartado-malentendido | descartado-inexistente}. La disposicion se
  captura en el flujo de revision existente, sin friccion (un tecla).
- **Tasa de falsos positivos por juez**, publicada como la calibracion
  del self-audit (SE-258 S3) publica la de Savia: con minimo N=25 hallazgos dispuestos
  por juez antes de mostrar cifra; sin N suficiente, "sin datos" como
  estado honesto.
- **Consecuencia operativa**: un juez con FP >X% en un dominio pasa a
  modo asesor (sus hallazgos informan pero no bloquean) hasta
  recalibrarse. La consecuencia es automatica y reversible, y queda
  registrada.
- **Anti-Goodhart**: se mide TAMBIEN el falso negativo detectable — un
  fallo que llego a produccion o a QA y que un juez debio ver. Sin esta
  segunda cara, la forma facil de bajar la tasa de FP es no reportar
  nada. Las dos metricas se publican juntas o no se publica ninguna.
- El informe mensual entra en el self-audit (SE-258 S3) y sus hallazgos
  al ledger.

**Acceptance criteria:**

AC-4.1. Disposicion capturada para >=50 hallazgos reales en la ventana,
        con <=1 tecla por hallazgo (friccion medida).
AC-4.2. Tasa de FP publicada para >=2 jueces con N>=25; los demas en
        "sin datos" (test del umbral).
AC-4.3. Juez sintetico con FP alto → degradado a asesor
        automaticamente; recalibrado → restaurado (test E2E).
AC-4.4. Falso negativo detectable registrado: fallo que escapa y era
        detectable por un juez concreto → entrada contra ese juez (test
        con caso plantado).
AC-4.5. Publicacion conjunta forzada: intento de publicar FP sin FN →
        bloqueado (asercion anti-Goodhart).

**Esfuerzo:** 6h

---

## Slice 5 — Distribucion de documentacion consumible por IA

**Problema:** 1.637 documentos y ninguna forma barata de que otra
instancia, un evaluador o un colaborador cargue el contexto de Savia de
una vez.

**Diseño minimo:**
- `docs/llms.txt`: indice curado (que es Savia, mapa de areas, punteros).
- `docs/llms-full.txt`: consolidado en texto plano de la documentacion
  publica, generado por script desde el corpus, con presupuesto de
  tamaño declarado y seccionado por area.
- **Filtro por nivel obligatorio**: el generador excluye por
  construccion todo N2+ y cualquier ruta de `sensitive-paths.yaml`
  (SE-258 S1). Un consolidado es la superficie ideal para una fuga por
  agregacion: contenido inocuo por separado que junto deja de serlo.
- Regeneracion en CI con drift-check: documentacion publica modificada
  sin regenerar → warning.

**Acceptance criteria:**

AC-5.1. Ambos ficheros generados; el consolidado cabe en el presupuesto
        declarado y es seccionado por area.
AC-5.2. Filtro de nivel: documento N3 plantado en el corpus → ausente
        del consolidado (test adversarial de fuga).
AC-5.3. Regeneracion determinista (dos ejecuciones → cero diff) y
        drift-check en CI operativo.
 AC-5.4. Utilidad verificada: una instancia sintetica que solo carga
         llms-full.txt responde correctamente >=8/10 preguntas fijas:
         (1) que es Savia, (2) como se estructura el workspace,
         (3) que es el Court, (4) que niveles de confidencialidad existen,
         (5) que es una spec SDD, (6) como se invoca un agente,
         (7) que es CRITERIO.md y cuantas linea_roja contiene,
         (8) que es el self-audit, (9) como funciona la federacion,
         (10) que patrones de seguridad aplica. El banco de preguntas
         esta en tests/fixtures/se269-llms-questions.json y es inmutable
         (cambios solo via PR).

**Esfuerzo:** 3h

---

## Verification method

1. Cadena E2E: idea → forja (veredicto ENDURECIDA) → spec →
   implementation-readiness (ternario) → implementacion → checkpoint de
   revision humana → merge. Evidencia commiteada.
2. Adversariales permanentes en CI: RESERVAS en gate de frontera,
   forja que contradice linea_roja, checkpoint con relleno inventado,
   FP sin FN, N3 en consolidado.
3. Metricas de 30 dias: veredictos de forja por banda (si nunca aparece
   MUERTA, la forja no presiona), ratio de RESERVAS, tiempo de revision
   humana, tasas FP/FN por juez.
4. Gate de archivo del SE-258 S4 aplicado a esta spec al cierre.

## Riesgos identificados pre-flight

- **R1 (S1): la forja se vuelve ceremonia** — 20 turnos para llegar a la
  idea de partida. Mitigacion: corte duro, veredicto MAS_CLARA como
  salida legitima, y la metrica de bandas (si nunca mata una idea, no
  esta presionando: se revisa el mandato adversarial).
- **R2 (S2): RESERVAS como via de escape universal.** Mitigacion:
  restriccion dura en gates de frontera (AC-2.2), reserva = follow-up
  con dueño, y auditoria del ratio (AC-2.5).
- **R3 (S3): el paquete de revision se convierte en relleno** —
  observaciones inventadas para cumplir el minimo de 2. Mitigacion:
  AC-3.3 exige declarar explicitamente el caso sin comportamiento
  observable y emitir cero; el relleno es fallo de test.
- **R4 (S4): medir a los jueces los vuelve timidos** (Goodhart).
  Mitigacion: publicacion conjunta FP+FN forzada (AC-4.5); el juez que
  calla para no fallar acumula falsos negativos.
- **R5 (S4): la disposicion humana es el cuello de botella.** Mitigacion:
  una tecla por hallazgo, captura en el flujo existente, y "sin datos"
  como estado honesto si no hay volumen — no se inventan cifras con N=6.
- **R6 (S5): fuga por agregacion en el consolidado.** Mitigacion: filtro
  por nivel en el generador (no en revision posterior) + test
  adversarial permanente.
- **R7 (transversal): adoptar el vocabulario de otro metodo sin su
  contexto.** Mitigacion: cada slice se justifica por un hueco medido en
  Savia (sin fase de analisis, gates binarios, sin artefacto de revision
  humana, jueces sin calibrar, docs no distribuibles); si el hueco no se
  confirma en el piloto, el slice se abandona con registro.

- **R8 (S1): envenenamiento socratico** — la forja lee mal el KG y formula
  preguntas capciosas que inducen a descartar ideas validas. Mitigacion:
  toda pregunta de la forja cita la fuente en el KG de la que deriva
  (trazabilidad); si la fuente es debil, lo declara. La operadora puede
  pedir "fuente" en cualquier momento y la forja debe mostrar la entidad
  del KG que sustenta la pregunta.
- **R9 (S3): orden de lectura generado peor que aleatorio** — el orden
  inferido del diff induce modelos mentales erroneos. Mitigacion: el orden
  generado incluye una nota de caveat por cada salto no obvio ("este
  fichero se lista primero porque el cambio central depende de el, pero
  la inferencia puede ser incorrecta"); y AC-3.2 exige que el orden de
  autor se respete cuando existe.
- **R10 (S4): fatiga de disposicion** — si disponer cada hallazgo es
  tedioso, las disposiciones se hacen al azar (garbage in, garbage out).
  Mitigacion: las disposiciones por defecto son "sin disponer" (no
  inventan dato); un hallazgo sin disponer no cuenta para N. Si tras 60
  dias el 80% de hallazgos siguen sin disponer, el self-audit lo reporta
  como "calibracion no operativa" y los jueces operan sin consecuencias.
- **R11 (S5): consolidado como superficie de prompt injection** — un
  atacante que compromete el CI puede inyectar instrucciones ocultas en
  llms-full.txt. Mitigacion: el script de regeneracion es deterministico y
  solo consume docs/ (no acepta input externo); el drift-check (AC-5.3)
  detecta modificaciones no regeneradas; y el consolidado se firma con
  hash en CI para detectar manipulacion post-generacion.

## Orden recomendado

2 (ternario, 5h: barato y desbloquea la semantica que S1 y S3 usan) →
1 (forja, 8h: el hueco de mayor valor) → 3 (checkpoint humano, 6h) →
4 (calibracion de jueces, 6h) → 5 (distribucion docs, 3h).

Justificacion: el veredicto ternario es infraestructura de decision que
los demas consumen (la forja emite tres bandas, el checkpoint cierra en
tres opciones); implementarlo primero evita tres semanticas distintas.

## Decision de adopcion

Adoptar por slice segun su metrica: forja que produce las tres bandas en
30 dias, ratio de RESERVAS sano, reduccion medida de tiempo de revision,
tasas FP/FN publicadas con N suficiente, consolidado util (8/10). Cada
slice abandonable con registro en specs-archive. Ningun slice se adopta
por venir de un metodo con comunidad: se adopta si cierra el hueco
medido que lo justifica.

## Dependencias verificadas

Estado real de cada subsistema que esta spec consume (verificado 2026-07-23):

| Dependencia | Estado | Slice | Nota |
|---|---|---|---|
| SE-256 (engrams) | EXISTS | S1 | memory-store.sh operativo; 42+ scripts |
| SE-257 S1 (CRITERIO.md) | EXISTS | S1, S2 | 33 entries, 19 linea_roja; provenance INFERRED |
| SE-258 S1 (sensitive-paths) | EXISTS | S5 | config/sensitive-paths.yaml v1.0 |
| SE-258 S3 (self-audit) | EXISTS | S2, S4 | scripts/self-audit.sh funcional |
| SE-258 S4 (gate archivo) | PARTIAL | S2 | CHANGELOG.d existe; pr-guardian.sh ausente |
| SE-260 S1 (bounded review) | EXISTS | S3 | court.rules.yaml + scripts/court-review.sh |
| SE-267 (rubrica/certificado QA) | ABSENT | S1, S2, S3 | Referencias condicionales ("si existe"); fallback disenado |
| Knowledge Graph (SE-162) | EXISTS | S1 | scripts/knowledge-graph.sh; densidad variable por proyecto |
| .opencode/commands/ | EXISTS | S1,S2,S3 | 560 comandos; formato YAML + markdown body |
| CRITERIO.md (linea_roja) | EXISTS | S1,S2 | 19 linea_roja con dureza declarada |

## Contrato de datos unificado (ternario)

Los tres slices que emiten veredicto ternario comparten estructura de salida:

```
veredicto: {banda}
dimensiones:
  - nombre: string
    banda: string
    hallazgos: string[]
motivo: string
owner: string|null
engram_op: string|null
origen: string
timestamp: ISO8601
```

Bandas por slice: S1 (ENDURECIDA|MAS_CLARA|MUERTA), S2 (PASA|RESERVAS|FALLA),
S3 (APROBAR|REHACER|SEGUIR). Campos base comunes; cada slice puede extender.
Implementado en scripts/ternary-verdict.sh (S2, reutilizado por S1 y S3).

## Cold-start y rutas de degradacion

- **KG vacio/escaso (S1):** si el proyecto activo tiene <10 entidades en el
  KG, la forja opera sin contraste y lo declara. No es fallo: la presion
  socratica funciona sin KG; el contraste es acelerador, no requisito.
- **Orden de lectura cold-start (S3):** el primer dia ningun autor declara
  orden. El generado desde diff se etiqueta como tal. A partir del tercer
  PR con orden generado, el sistema sugiere al autor persistir el orden.
- **Disposicion cold-start (S4):** primeros 30 dias todos los jueces en
  "sin datos". La calibracion no bloquea hasta N>=25. Jueces operan con
  comportamiento actual durante el periodo de recoleccion.
- **SE-267 ausente (S1, S2, S3):** los slices referencian SE-267
  condicionalmente. Si al iniciar implementacion SE-267 sigue ausente, se
  instancia la rubrica directamente en cada slice. La deuda de duplicacion
  se registra como follow-up.

## ROI estimado por slice

| Slice | Coste | Valor esperado | Riesgo de no hacerlo |
|---|---|---|---|
| S1 | 8h | 1 mala idea/mes evitada (~20h/mes ahorradas en implementacion fallida) | Las specs siguen naciendo sin presion; el coste de una idea mala se paga en codigo |
| S2 | 5h | Elimina falso bloqueo + falso verde en gates de juicio (friccion diaria) | Gates binarios fuerzan eleccion incorrecta en hallazgos matizados |
| S3 | 6h | 30% reduccion de tiempo de revision humana (~15min/PR ahorrados) | El cuello de botella humano sigue siendo el tiempo del revisor |
| S4 | 6h | Ruido de jueces cuantificado; degradacion automatica de jueces ruidosos | Los hallazgos de los jueces siguen sin calibrar; falsos positivos erosionan confianza |
| S5 | 3h | Contexto Savia cargable en una operacion para evaluadores y colaboradores | Evaluadores externos no pueden cargar contexto sin leer 1.637 documentos |

## Referencias

- BMAD Method v6 (docs.bmad-method.org): fases Analysis/Planning/
  Solutioning/Implementation; bmad-forge-idea (presion socratica una
  pregunta cada vez, modo adversarial, veredicto ternario);
  bmad-check-implementation-readiness (PASS/CONCERNS/FAIL);
  bmad-checkpoint-preview (revision ordenada por preocupacion, orden de
  lectura sugerido, verificacion manual 2-5); adversarial review
  (documentacion honesta de falsos positivos); llms.txt / llms-full.txt.
  Conceptos adoptados; implementacion propia; licencia a verificar.
- Sustrato Savia: 15+ jueces y court-orchestrator, bounded review
  (SE-260 S1), calibracion (SE-258 S3), engrams (SE-256), CRITERIO y
  linea_roja (SE-257 S1), sensitive-paths (SE-258 S1),
  self-audit (SE-258 S3), rubrica de specs y certificado QA (SE-267,
  si implementado), gate de archivo (SE-258 S4).
- No adoptado con motivo: agentes con persona y party mode (precedente
  anti-biomimetic-theater, articulo T3); marketplace, multi-frontend y
  web bundles (decision OpenCode-only).
- Criterios: CRIT-004 (consolidar antes que proliferar: el residuo va a
  engrams), CRIT-005 (ACs falsificables), CRIT-013 (honestidad antes que
  marketing: declarar el ruido de los jueces), CRIT-023 (fail-closed en
  fronteras: sin banda intermedia), CRIT-010 (bien comun: distribucion
  de docs).
