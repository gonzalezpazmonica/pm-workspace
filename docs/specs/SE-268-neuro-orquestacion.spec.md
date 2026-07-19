# SE-268 — Orquestacion neuro-inspirada: plano constitucional prioritario, federacion por saliencia, umbral de hooks por dominio y memoria de dos velocidades

**Status:** PROPOSED → IMPLEMENTING (Slice 1 iniciado 2026-07-19)
**Fecha:** 2026-07-19
**Area:** Orchestration architecture / Control plane / Federation / Hooks / Memory
**Branch:** agent/se268-neuro-orquestacion
**Estimacion total:** ~34h (4 slices)
**Base verificada:** HEAD 520dd293 (#906). SE-263 (federacion git+A2A),
SE-256 (engrams), memory-bitemporal.py y memory-consolidate.py presentes.

---

## Origen

Informe de investigacion "Neurocomputacion aplicada a la orquestacion de
flujos agenticos" (julio 2026). Tesis del informe, que esta spec asume y
NO reabre: la neurocomputacion aporta a Savia patrones de ARQUITECTURA DE
ORQUESTACION, no aceleracion por hardware. El sustrato neuromorfico solo
es relevante en el borde (percepcion event-driven), y eso queda fuera de
esta spec por prematuro salvo como nota de diseño para ZeroClaw.

De las seis recomendaciones del informe, esta spec implementa las CUATRO
de mayor relacion valor/esfuerzo que atacan un problema ya sentido en el
codigo real. Las otras dos se registran como no incluidas con motivo
(seccion final).

**Verificado en repo (el sustrato existe, el patron no):**
- `a2a-server.py` existe (SE-263) pero el informe señala el riesgo de que
  la coordinacion sea por sondeo del git state plane; hay que garantizar
  que el veto constitucional NO compita por el canal A2A ordinario.
- Hooks (~100) SIN umbral de exigencia configurable: la severidad esta
  implicita en cada hook, no parametrizada por dominio.
- `memory-bitemporal.py` y `memory-consolidate.py` existen, pero la
  consolidacion no esta formalizada como dos velocidades con replay
  selectivo: hoy es mas "compactar" que "consolidar".
- No existe saliencia: la federacion (SE-263) promueve cupulas por regla
  de nivel, no por relevancia; y no hay umbral de que asciende al dome.

**El principio unificador (del informe, seccion 4):** el criterio humano
es el prior de maxima precision (via hiperdirecta de los ganglios
basales); el context dome es el espacio de trabajo global donde se difunde
por saliencia; los hooks arbitran Go/NoGo; la memoria consolida a dos
velocidades. Cada pieza YA existe en Savia; lo que falta es el criterio
para dimensionarlas y decidir que va por que plano. Esta spec añade ese
criterio en los cuatro puntos donde hay dolor real.

## Objetivo (scope-down agresivo)

Dar al veto constitucional un plano de control propio, prioritario y de
minima latencia, separado del A2A ordinario (S1). Hacer la federacion
event-driven con difusion por saliencia en lugar de sondeo y replicacion
total (S2). Parametrizar el umbral de exigencia de los hooks por dominio
(S3). Formalizar la memoria como dos velocidades con consolidacion por
replay selectivo (S4). Cero hardware, cero reescritura de lo que funciona:
se añade criterio donde hay heuristica implicita.

## Out of scope explicito

- NO hardware neuromorfico ni inferencia por impulsos: el informe lo
  descarta como prematuro; solo nota de diseño para ZeroClaw en borde.
- NO implementacion literal del calculo variacional de inferencia activa:
  el informe es explicito en que su valor aqui es como LENGUAJE de diseño
  y criterio de arbitraje, no como computo en cada instancia. El
  trade-off informacion/coordinacion se adopta como criterio (S2), no
  como integral.
- NO consciencia ni subjetividad: GWT/GNWT se usan como patron de
  ACCESO y difusion; la saliencia es una puntuacion escalar, no
  experiencia (nota explicita en S2 para evitar deriva conceptual).
- NO reescritura de SE-263, SE-256 ni de la capa constitucional: se
  extienden con un plano y unos parametros.
- NO cambio de la semantica de niveles N1-N4b: la saliencia es ORTOGONAL
  al nivel (una cosa es si algo PUEDE cruzar —nivel— y otra si DEBE
  ascender —saliencia—).

---

## Slice 1 — Plano constitucional prioritario (via hiperdirecta)

**Problema:** el veto constitucional (CONSTITUCION/CRITERIO/veto humano)
y el trafico de coordinacion comparten mecanismo. Un veto que compite por
el mismo canal que la coordinacion no es irrenegociable. En anatomia: la
via hiperdirecta cortocircuita el bucle normal de los ganglios basales;
el veto debe hacer lo mismo.

**Diseño minimo:**
- **Canal de control separado**: `bridge/control-plane/` con un bus de
  veto de minima latencia, independiente del plano A2A y del git state
  plane. Un veto (constitucional o humano) publicado aqui tiene prioridad
  absoluta y alcance global: puede detener cualquier accion de cualquier
  instancia ANTES de su commit, sin razonar caso por caso.
- **Precedencia dura**: toda accion consulta el plano de control antes de
  ejecutar (check O(1) contra un conjunto de vetos activos + reglas
  linea_roja de CRITERIO). El plano de control NUNCA se encola detras de
  trafico de coordinacion; si el bus de control esta caido, fail-closed
  (sin plano de control verificable → no se ejecutan acciones que
  requieran su visto bueno).
- **Vetos con alcance**: {global | instancia | dominio | sesion} y TTL
  opcional (un veto humano "para todo ahora" es global sin TTL; un
  bloqueo de dominio puede expirar). Propagacion a la federacion por el
  canal de control, no por exchange git ordinario.
- **Latencia como AC**: el veto es util solo si llega antes que la
  accion. Presupuesto de latencia declarado y medido.
- Integracion: las reglas linea_roja de CRITERIO.md (CRIT con
  dureza:linea_roja) se compilan a vetos permanentes del plano de
  control; verify-principal y el veto humano publican aqui.

**Acceptance criteria:**

AC-1.1. Veto global publicado detiene una accion en curso en TODAS las
        instancias de una federacion de laboratorio antes de su commit
        (E2E con 2 instancias sinteticas + real).
AC-1.2. Latencia del veto: desde publicacion hasta bloqueo efectivo
        <=P ms declarado (medido); y estrictamente menor que la latencia
        del plano A2A ordinario en el mismo harness (el veto no compite).
AC-1.3. Fail-closed: bus de control inalcanzable → las acciones que
        requieren visto bueno constitucional NO se ejecutan (test).
AC-1.4. Alcance y TTL: veto de dominio con TTL expira y libera; veto
        global sin TTL persiste hasta revocacion humana (dos tests).
AC-1.5. Compilacion CRITERIO→vetos: las CRIT linea_roja activas producen
        vetos permanentes verificables; añadir una CRIT linea_roja nueva
        la refleja en el plano (test).
AC-1.6. Precedencia: bajo saturacion de coordinacion (S2), el veto sigue
        cumpliendo AC-1.2 (test de carga: el plano de control no degrada
        con el trafico A2A).

**Esfuerzo:** 10h

---

## Slice 2 — Federacion event-driven con difusion por saliencia

**Problema:** el informe advierte que un espacio compartido PASIVO que
las instancias sondean genera estancamiento y bucles homogeneos en
ejecuciones largas (hallazgo GWT/GWA). Y que replicar todo el contexto
entre instancias es caro e innecesario: en GNWT solo lo que supera un
umbral de saliencia "prende" y se difunde.

**Diseño minimo:**
- **Publicacion de eventos salientes** en vez de sondeo: una instancia
  que produce algo relevante publica un evento en el plano A2A (SSE, ya
  disponible en A2A v1.0) que DESPIERTA a las coaliciones pertinentes;
  se elimina/reduce el polling periodico del git state plane. El git
  sigue siendo la verdad durable; el evento es la señal de que hay algo
  nuevo que mirar.
- **Puntuacion de saliencia** (`bridge/salience/`): funcion escalar,
  auditable y deterministica primero, que puntua un candidato a ascender
  al dome/federacion por {novedad respecto a creencias actuales, impacto
  en compromisos/dependencias abiertas, criticidad de nivel, recurrencia}.
  Solo lo que supera umbral asciende. Nota anti-deriva: la saliencia es
  una puntuacion, no una experiencia; no implica consciencia (seccion 5
  del informe).
- **Umbral explicito y por contexto**: el umbral de ascenso al dome es
  configurable (coherente con soberania: menos trafico VPN, retencion
  justificada) y distinto por criticidad de cupula.
- **Difusion selectiva, no broadcast**: promover al dome compartido solo
  lo saliente; el resto queda local a la instancia. Encaja con soberania
  de datos (no se replica lo que no necesita difundirse).
- **Interrumpibilidad**: un evento saliente de alta prioridad puede
  interrumpir un proceso en curso (coherente con el plano de control del
  S1 para el caso extremo del veto; aqui es para saliencia alta no-veto).
- **Anti-estancamiento**: detector de bucle homogeneo (misma coalicion
  repitiendo sin ganancia) → eleva saliencia del estancamiento como
  evento, rompiendo el bucle (el problema concreto que GWA resuelve).

**Acceptance criteria:**

AC-2.1. Federacion pasa de polling a event-driven: en el harness, trafico
        de sondeo reducido >=80% manteniendo tiempo-a-deteccion de un
        evento nuevo <= al del polling (medido).
AC-2.2. Saliencia funciona: candidato bajo umbral NO asciende al dome;
        sobre umbral asciende y despierta solo a las coaliciones
        pertinentes (no broadcast total). Tests separados.
AC-2.3. Umbral por contexto configurable: misma señal con umbral alto no
        asciende, con umbral bajo si (test).
AC-2.4. Determinismo de la puntuacion base: misma entrada → misma
        saliencia (la capa LLM opcional se marca INFERRED y no altera el
        gate deterministico).
AC-2.5. Anti-estancamiento: bucle homogeneo sintetico en ejecucion larga
        → detectado y roto por elevacion de saliencia (test).
AC-2.6. Soberania: lo no-saliente permanece local; verificacion de que el
        dome compartido NO contiene lo que no supero umbral (asercion).

**Esfuerzo:** 10h

---

## Slice 3 — Umbral de exigencia de hooks por dominio (modulacion tipo dopaminergica)

**Problema:** los ~100 hooks tienen severidad implicita en el codigo. El
informe lo mapea a la modulacion dopaminergica de los ganglios basales:
la eficacia del arbitraje depende de un umbral, y ese umbral deberia ser
explicito y ajustable por dominio — salud y legal exigen mas conservacion
que un dominio experimental.

**Diseño minimo:**
- `config/hook-thresholds.yaml`: nivel de exigencia por dominio
  {conservador | estandar | experimental} que modula el comportamiento de
  los hooks parametrizables: que severidad bloquea vs advierte, umbrales
  numericos (coverage minimo, complejidad, confianza), y que
  validaciones opcionales se activan.
- **Distincion NoGo vs hiperdirecta hecha explicita** (aporte fino del
  informe): un hook ordinario es NoGo (rechaza una accion concreta por
  una regla concreta) y su umbral es modulable aqui; las reglas
  linea_roja NO son modulables — son hiperdirecta (S1) y ningun umbral de
  dominio las relaja. El YAML no puede bajar la exigencia de una
  linea_roja (gate que lo impide).
- **Mapeo dominio→exigencia** derivado del contexto activo (proyecto/
  cupula declara su dominio; salud/legal/finanzas → conservador por
  defecto, con override humano explicito y registrado).
- **Auditabilidad**: el umbral efectivo de cada decision de hook se
  registra (que exigencia aplico y por que), de modo que "por que paso
  esto" es respondible. Entra en el /self-audit.

**Acceptance criteria:**

AC-3.1. Mismo hook parametrizable, mismo input, dominio conservador vs
        experimental → decisiones distintas y ambas justificadas en el
        log (test).
AC-3.2. Dominio salud/legal → exigencia conservador por defecto sin
        configuracion adicional (test).
AC-3.3. Gate anti-relajacion: intento de bajar via YAML la exigencia de
        una regla linea_roja → rechazado (test adversarial; la
        hiperdirecta no se modula).
AC-3.4. Auditabilidad: el umbral efectivo de cada decision queda
        registrado y es consultable por el self-audit (test).
AC-3.5. Override de dominio a menos conservador → exige aprobacion humana
        y deja entrada en el ledger (test).

**Esfuerzo:** 6h

---

## Slice 4 — Memoria de dos velocidades con consolidacion por replay selectivo

**Problema:** memory-consolidate.py hoy compacta; el informe (teoria CLS)
pide separar explicitamente un almacen episodico rapido (hipocampo) de
uno semantico lento (corteza), con consolidacion por REPLAY SELECTIVO —no
"copiar todo a largo plazo", sino reactivar lo recurrente/valioso y
descartar el resto. Savia ya tiene el eje bitemporal ideal para esto.

**Diseño minimo:**
- **Dos almacenes explicitos sobre el eje bitemporal existente**:
  - Episodico (rapido, hipocampal): lo ocurrido en esta sesion/instancia,
    alta resolucion, barato de escribir, indexado por el eje
    tiempo-de-sistema.
  - Semantico (lento, cortical): patrones consolidados, generalizables,
    caros de modificar, sobre el eje tiempo-de-validez.
- **Consolidacion por replay selectivo** (proceso offline, "sueño"): una
  instancia reprocesa sus engrams episodicos, promueve al semantico solo
  lo recurrente o valioso (sesgo por relevancia/recompensa, analogo al
  replay hipocampal), y descarta el resto. Es tambien higiene de
  soberania: menos datos retenidos, retencion justificada. Corre en L1
  con loop-budget (SE-228), como job de fondo (clase fondo del gateway
  si SN-001 aplica; aqui: horario de baja actividad).
- **Recuperacion indexada por contexto de dome activo**, no busqueda
  global plana (el replay agrupa por contexto espacio-temporal): la
  recuperacion de engrams se filtra primero por la cupula activa.
- **Evaluacion**: los cuatro procesos del informe (codificacion,
  recuperacion, consolidacion, evaluacion) → metrica de calidad de
  consolidacion (¿lo promovido resulto util despues?, medible contra el
  ledger de relacion) que realimenta el sesgo de replay.

**Acceptance criteria:**

AC-4.1. Dos almacenes operativos sobre el eje bitemporal; una entrada
        episodica y su version consolidada semantica son distinguibles y
        consultables por separado (test).
AC-4.2. Replay selectivo: de N engrams episodicos sinteticos con
        recurrencia/valor variable, solo los que superan criterio se
        promueven; el resto se descarta con registro (test con conteos).
AC-4.3. La consolidacion NO es copia total: verificacion de que |semantico|
        << |episodico procesado| en un caso realista (asercion).
AC-4.4. Recuperacion por contexto: misma query en dos domes distintos →
        resultados priorizados por el dome activo (test).
AC-4.5. Consolidacion corre en L1 con presupuesto; sin presupuesto para
        y reporta (SE-228, test).
AC-4.6. Metrica de calidad: lo promovido que luego se usa vs lo que no,
        medido contra el ledger; realimenta el sesgo (demostrado en un
        ciclo).

**Esfuerzo:** 8h

---

## Verification method

1. **Plano de control**: veto global bajo saturacion de coordinacion
   cumple su presupuesto de latencia (S1 AC-1.6) — el experimento clave,
   porque es la garantia "nunca se delega el criterio" hecha mecanismo.
2. **Federacion**: benchmark polling vs event-driven (trafico y
   tiempo-a-deteccion) + anti-estancamiento demostrado en ejecucion
   larga sintetica.
3. **Hooks**: matriz de decisiones por dominio con el gate
   anti-relajacion de linea_roja en verde permanente.
4. **Memoria**: ciclo de consolidacion con la asercion de no-copia-total
   y la metrica de calidad realimentando.
5. Adversariales permanentes en CI: veto que compite y pierde (debe
   ganar), linea_roja relajada por YAML (debe bloquear), no-saliente en
   dome compartido (debe estar ausente), consolidacion que copia todo
   (debe fallar).
6. Gate de archivo del SE-258 S4 aplicado a esta spec.

## Riesgos identificados pre-flight

- **R1 (S1, el mayor): el plano de control se convierte en punto unico de
  fallo.** Mitigacion: fail-closed por diseño (sin control verificable,
  no se actua) es el comportamiento SEGURO aqui, no un fallo; y el
  conjunto de vetos activos es texto replicable (cada instancia cachea el
  ultimo estado firmado, opera con el si el bus cae, y para las acciones
  nuevas que requieran visto bueno).
- **R2 (S2): la saliencia mal calibrada oculta lo importante** (umbral
  alto) o no filtra nada (umbral bajo). Mitigacion: puntuacion base
  deterministica y auditable, umbral por contexto, y arranque
  conservador (umbral bajo: asciende de mas) con ajuste por datos del
  self-audit; mejor ruido temporal que silencio.
- **R3 (S2): sobre-ingenieria — Savia funciona con heuristica.** El
  informe lo advierte (seccion 5). Mitigacion: cada slice ataca un dolor
  YA sentido (veto que compite, estancamiento en long-horizon, severidad
  implicita, memoria que crece sin criterio); si un slice no demuestra el
  dolor en su benchmark, se abandona con registro.
- **R4 (S3): un umbral por dominio mal puesto relaja seguridad.**
  Mitigacion: linea_roja jamas modulable (AC-3.3), conservador por
  defecto en dominios sensibles, override humano registrado.
- **R5 (S4): el replay selectivo descarta algo que luego hace falta.**
  Mitigacion: lo episodico no se borra inmediatamente (cuarentena antes
  de descarte, CRIT-024); la metrica de calidad (AC-4.6) detecta
  descartes que se echaron en falta y ajusta el sesgo.
- **R6 (transversal): mapear neurociencia a ingenieria con exceso de
  fidelidad.** El informe es explicito: son fuentes de patrones, no
  plantillas. Mitigacion: cada slice se justifica por el problema de
  ingenieria (arbitraje, difusion, consolidacion), no por fidelidad
  biologica; el vocabulario neuro es andamiaje, no requisito.

## Orden recomendado

1 (plano de control, 10h: la garantia constitucional es lo de mayor
impacto segun el informe, recomendacion #1) → 3 (umbral de hooks, 6h:
barato y refuerza el arbitraje que el plano de control corona) →
2 (federacion por saliencia, 10h: sobre el plano ya separado) →
4 (memoria dos velocidades, 8h).

Justificacion: 1 y 3 son el eje de arbitraje (hiperdirecta + Go/NoGo) y
se sostienen sin los otros; 2 se beneficia de que el plano de control ya
exista (interrumpibilidad); 4 es independiente y puede ir en cualquier
momento.

## Decision de adopcion

Adoptar por slice segun su propio benchmark demuestre el dolor que ataca.
S1 es el de mayor valor (garantia de criterio) y el candidato a
implementar aunque los demas se pospongan. Cada slice abandonable con
registro. Ningun slice se adopta "por elegancia neurocomputacional": se
adopta si su AC de valor (latencia de veto, reduccion de polling,
decisiones por dominio, no-copia-total) se cumple.

## No incluido (con motivo)

- **Recomendacion #5 del informe (sustrato neuromorfico en ZeroClaw):**
  percepcion event-driven de bajo consumo en el borde. Prematuro y
  dependiente de hardware; se deja como nota de diseño para ZeroClaw, no
  como slice. Cuando haya caso de uso de señal real (audio/sensores),
  spec propio.
- **Recomendacion #6 (inferencia activa como computo literal):** el
  propio informe la descarta como implementacion; su valor como LENGUAJE
  de diseño ya esta absorbido en el criterio de saliencia del S2
  (trade-off informacion/coordinacion). No hay slice de calculo
  variacional.

## Referencias

- Informe "Neurocomputacion aplicada a la orquestacion de flujos
  agenticos" (julio 2026), secciones 3.1 (GWT→domes), 3.2 (ganglios
  basales→hooks/constitucion), 3.3 (inferencia activa→federacion, como
  lenguaje), 3.4 (CLS/replay→engrams/bitemporal), 4 (sintesis), 6
  (recomendaciones accionables #1-#4).
- Sustrato Savia: a2a-server.py y federacion (SE-263), CONSTITUCION/
  CRITERIO y verify-principal (SE-255), hooks y dispatchers (SE-253),
  memory-bitemporal.py y memory-consolidate.py (SE-256), context-dome
  (SE-252), loop budgets (SE-228), self-audit (SE-258 S3), ledger de
  relacion (SE-255 S3).
- Criterios: CRIT-023 (fail-closed, S1), CRIT-024 (cuarentena antes de
  descarte, S4), CRIT-031 (intocables: linea_roja no modulable, S3),
  principio "se delega la ejecucion, nunca el criterio" (S1 lo hace
  mecanismo).
- El mapeo neuro→Savia es interpretativo y sujeto a validacion empirica
  (nota metodologica del informe); los AC de esta spec miden el valor de
  ingenieria, no la fidelidad biologica.
