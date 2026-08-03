# SE-292 — Contencion de ejecucion: radio de impacto acotado y autonomia graduada por fiabilidad medida

**Status:** APPROVED
**Fecha:** 2026-08-02
**Area:** Execution containment / Credential isolation / Reliability measurement
**Branch:** agent/se292-contencion-ejecucion
**Estimacion total:** ~54h (7 slices)
**Complementa a:** SE-273 (contencion de trayectoria). SE-273 reduce la probabilidad de que algo malo ocurra; SE-292 reduce su impacto cuando ocurra.

---

## Origen

Validacion de Savia contra el vocabulario operativo de sistemas agenticos en produccion (agosto 2026). De veinte conceptos, Savia cubre diecinueve y en la mayoria por encima de la media del sector. **El unico no resuelto es el sandboxing**, y la brecha es de arquitectura, no de configuracion.

### Lo medido

- `docker/` contiene unicamente `savia-test`, el arnes de escenarios del workspace. Los demas `docker-compose` del repo pertenecen a laboratorios de seguridad y a la busqueda web: **ninguno aisla la ejecucion del agente**.
- **102 hooks** que lanzan procesos y **856 scripts** ejecutables, todos corriendo en el anfitrion.
- Sin devcontainer. El CI corre en runner efimero — el unico entorno desechable que existe, y no es donde Savia trabaja.
- La proteccion actual es **de patron** (denegar ordenes conocidas peligrosas) y **de forma** (SE-273: irreversibilidad, radio, cruce de perimetro, novedad). Ambas son prevencion.

### El planteamiento correcto

El riesgo no es "Savia ejecuta bash". Es que ejecuta bash que acaba de escribir, o que vino de fuera, en el anfitrion, con las credenciales presentes. Esa es la superficie.

La aritmetica del riesgo es un producto: probabilidad x impacto. Savia ha optimizado el primer factor —guards de patron, de forma, de trayectoria, presupuestos, plano de control— y ha dejado el segundo sin tocar. Un sistema con prevencion excelente y contencion nula tiene un perfil de riesgo peor de lo que su cantidad de controles sugiere: cuando la prevencion falla, y falla, no hay nada debajo.

### La otra brecha

La misma validacion encontro un segundo hueco: las evaluaciones miden **capacidad** (lo consiguio?) y no **fiabilidad bajo repeticion** (lo consigue k de k veces?). Los sistemas agenticos que parecen solidos en una pasada se degradan al repetirlas, y la diferencia entre ambas medidas es exactamente el criterio para ampliar autonomia.

Los dos huecos son el mismo problema desde dos lados. Tesis que une esta spec:

> **La frontera de contencion debe ser funcion de la fiabilidad medida.**
> Se amplia el radio de accion de un agente en la medida en que su fiabilidad demostrada lo permita, no por confianza acumulada ni por comodidad.

Sin medida de fiabilidad, la contencion se relaja por costumbre. Sin contencion, la medida de fiabilidad no tiene donde aplicarse.

### Justificacion contractual

En el modelo de encargos y en el de servicio gestionado, Savia ejecutara construcciones y pruebas de **codigo de cliente**. Hacerlo en el anfitrion, con las credenciales de la operadora presentes y el conocimiento de otros clientes en disco, es un problema contractual antes que tecnico: las murallas entre clientes se declaran a nivel de datos y se rompen a nivel de proceso.

---

## Objetivo (scope-down agresivo)

Acotar el radio de impacto de la ejecucion sin destruir lo que hace util a Savia: clasificar la superficie (S1), construir el entorno de contencion (S2), aislar credenciales (S3), ejecutar codigo ajeno de forma segura (S4), poder deshacer (S5), medir fiabilidad bajo repeticion (S6) y degradar fail-closed con verificacion adversarial (S7).

---

## Out of scope explicito

- NO contenerizar Savia entera. Su valor depende de operar sobre el repositorio real, los hooks y el git del anfitrion. Un contenedor que lo aisla todo destruye el producto.
- NO maquinas virtuales ni hipervisores: el nivel de aislamiento que justifica el riesgo es el de contenedor. Anadir peso reduce la probabilidad de que se use — un aislamiento que estorba se desactiva.
- NO sustituir los guards existentes: prevencion y contencion son complementarias. Esta spec anade el segundo factor, no reemplaza el primero.
- NO exigir un motor de contenedores concreto: interfaz con implementaciones intercambiables. Savia es software global y no puede presuponer el entorno.
- NO aislamiento de red total por defecto en toda ejecucion: romperia la investigacion web legitima. La red se deniega **por nivel**, segun S1.

---

## Slice 1 — Clasificacion de la superficie de ejecucion (8h)

**Problema:** sin saber que ejecuta Savia y de donde viene, cualquier contencion es arbitraria: o asfixia el trabajo normal o no cubre lo que importa.

**Diseno minimo:**

Tres niveles de ejecucion, declarados y aplicados por origen del codigo:

| Nivel | Origen | Entorno | Red | Credenciales | Sistema de ficheros |
|---|---|---|---|---|---|
| **N-anfitrion** | Codigo propio del workspace, versionado y revisado. Necesita git y ficheros reales | Anfitrion | Ilimitada | Presentes | Completo |
| **N-contenido** | Codigo que Savia escribio en este turno, dependencias de terceros, herramientas de analisis, scripts de origen externo | Contenedor | Denegada (salvo allowlist) | Ninguna | Montaje minimo ro |
| **N-hostil** | Codigo de cliente bajo analisis, artefactos de fuente no verificada, cualquier cosa que se ejecute para ver que hace | Contenedor | Denegada | Ninguna | Efimero |

Reglas de clasificacion:
- **Por origen, no por contenido**: no se clasifica leyendo el script para ver si parece peligroso —ese es el juego que siempre gana el atacante— sino por su procedencia. Codigo escrito en el turno es N-contenido aunque parezca inocuo.
- **Inventario de los 856 scripts y 102 hooks** con su nivel declarado, y gate para los nuevos: script sin nivel → hallazgo.
- **Excepciones con caducidad** (patron ya vigente en SE-274): un script N-contenido que necesite anfitrion se justifica y expira.
- Lo que no es Savia escribiendo codigo (ej. git commit, npm install de libreria conocida) es N-anfitrion.

**Acceptance criteria:**

AC-1.1. Los 856 scripts y 102 hooks clasificados; cero sin nivel (check automatizado contra el arbol).
AC-1.2. Clasificacion por origen demostrada: script generado en turno con contenido trivial → N-contenido igualmente (test).
AC-1.3. Script nuevo sin nivel → hallazgo en el self-audit (test).
AC-1.4. Excepcion a anfitrion exige justificacion y caducidad (test).
AC-1.5. Distribucion publicada: cuantos scripts en cada nivel. Si el 95% cae en N-anfitrion, la clasificacion es cosmetica y hay que revisarla.

**Esfuerzo:** 8h

---

## Slice 2 — Entorno de contencion (10h)

**Problema:** no existe donde ejecutar lo contenido.

**Diseno minimo:**
- **Interfaz de contencion** (`src/containment/types.ts`): abstraccion con implementaciones intercambiables (motor de contenedores del sistema, o el que la organizacion tenga). Savia declara requisitos —sistema de ficheros efimero, red controlable, limites de recursos, sin privilegios— y no un producto:
  ```typescript
  interface ContainerRuntime {
    run(opts: ContainerOptions): Promise<ContainerResult>;
    buildImage(context: string, tag: string): Promise<void>;
    isAvailable(): Promise<boolean>;
  }
  ```
- Implementacion de referencia: `DockerRuntime` (usa `docker` CLI). Alternativa minima: `ProcessRuntime` que ejecuta en subproceso con `--no-sandbox` flag + entorno limpio (fallback sin contencion real, util para desarrollo sin Docker, con warning explicito).
- **Imagen base minima** (`containment/Dockerfile.base`) con herramientas habituales: node, python, git, curl, jq. Versiones pineadas. Sin credenciales, sin claves, sin configuracion de la operadora. Reconstruible deterministicamente.
- **Limites de recursos declarados**: CPU (--cpus=1), memoria (--memory=512m), tiempo de vida (timeout 5min por defecto), max procesos (--pids-limit=50). Sin privilegios (--cap-drop=ALL, --security-opt=no-new-privileges), usuario no-root.
- **Presupuesto de latencia**: arranque de contenedor medido y declarado. Si el coste hace que nadie lo use, el slice ha fracasado aunque funcione.
- **Reutilizacion de sesion**: contenedor por sesion de trabajo y no por invocacion, para que el coste se amortice. `SessionContainer`: arranca una vez, ejecuta N comandos, se destruye al cerrar sesion.

**Acceptance criteria:**

AC-2.1. Ejecucion contenida operativa con `DockerRuntime` y `ProcessRuntime` (dos implementaciones prueban la abstraccion).
AC-2.2. Limites aplicados: proceso que intenta exceder memoria o tiempo → terminado y reportado (dos tests).
AC-2.3. Escalada de privilegios intentada dentro del contenedor → falla (test adversarial).
AC-2.4. Latencia de arranque medida y declarada; con reutilizacion de sesion, coste amortizado publicado.
AC-2.5. Imagen reconstruible de forma determinista desde su Dockerfile.

**Esfuerzo:** 10h

---

## Slice 3 — Aislamiento de credenciales y montajes minimos (8h)

**Problema:** un contenedor que hereda el entorno y monta el directorio personal es contencion nominal. Es el error mas comun y el que anula todo lo demas.

**Diseno minimo:**
- **Entorno limpio por defecto**: ninguna variable del anfitrion se hereda. Lo que el proceso contenido necesite se pasa explicitamente, campo a campo (`--env KEY=VALUE`).
- **Cero credenciales en N-contenido y N-hostil**: sin tokens de proveedor, sin claves de instancia, sin acceso al almacen de secretos (~/.savia/, PAT files). Si un proceso contenido necesita una credencial, esta mal clasificado o mal disenado.
- **Montaje minimo y explicito**: solo las rutas que la tarea declara, en solo lectura salvo el directorio de trabajo (`--volume /host/path:/container/path:ro`). Nada de montar el repositorio entero (`--volume $PWD:/workspace`) por comodidad.
- **Salida por artefacto, no por sistema de ficheros compartido**: el proceso contenido escribe en su directorio de trabajo y lo que sale se copia explicitamente tras verificacion (`docker cp`). Esto evita que un proceso escriba en el workspace sin pasar por gate.
- **Verificacion adversarial obligatoria**: test por cada via de fuga (entorno, secretos, ficheros de configuracion, montaje del directorio personal).

**Acceptance criteria:**

AC-3.1. Proceso contenido no ve ninguna variable de entorno del anfitrion (asercion sobre `env` completo dentro del contenedor).
AC-3.2. Cuatro vias de acceso a credenciales probadas y bloqueadas: variables de entorno, almacen de secretos (~/.savia/), ficheros de configuracion, y montaje del directorio personal.
AC-3.3. Escritura fuera del directorio de trabajo → bloqueada (test).
AC-3.4. Salida por artefacto verificado: escritura al workspace sin pasar por el gate → imposible (test).
AC-3.5. Montaje del repositorio completo → rechazado por politica salvo declaracion justificada (test de politica).

**Esfuerzo:** 8h

---

## Slice 4 — Ejecucion de codigo de cliente en contencion (8h)

**Problema:** es la justificacion contractual y el caso de uso que hace urgente el resto. Las murallas entre clientes se declaran a nivel de datos y se rompen a nivel de proceso.

**Diseno minimo:**
- **Todo lo de un encargo se ejecuta contenido**: construcciones, pruebas, linters y herramientas del proyecto de cliente. Nivel N-hostil por defecto, no por sospecha del cliente sino por higiene: es codigo que Savia no escribio ni reviso.
- **Un contenedor por encargo**, jamas compartido entre clientes (etiquetado `--label encargo=<id>`). La muralla se hace efectiva en el proceso, no solo en el disco.
- **Sin acceso al conocimiento propio**: el proceso de cliente no ve el vault de Savia, ni su criterio, ni el material de otros encargos.
- **Red por politica del encargo**: la allowlist de egreso del encargo (SE-273 S3) aplica dentro del contenedor. Una construccion que descarga dependencias necesita red; una que no la necesita, no la tiene.
- **Evidencia para el paquete de auditoria**: registro de que se ejecuto, en que contencion y con que acceso. Responde a la pregunta del auditor de cliente sobre aislamiento.

**Acceptance criteria:**

AC-4.1. Construccion y pruebas de un proyecto de cliente sintetico ejecutadas en contencion, con resultado equivalente al de anfitrion.
AC-4.2. Proceso de cliente A no alcanza material de cliente B ni el vault propio (dos tests de muralla a nivel de proceso).
AC-4.3. Allowlist de egreso del encargo aplicada dentro del contenedor (test).
AC-4.4. Registro de ejecucion integrado en el paquete de evidencia (SE-271).
AC-4.5. Contenedor por encargo: cero reutilizacion entre clientes (asercion).

**Esfuerzo:** 8h

---

## Slice 5 — Reversibilidad del anfitrion (8h)

**Problema:** para lo que sigue ejecutandose en el anfitrion —la mayoria y debe seguir siendolo— la contencion no aplica. Ahi lo que reduce el impacto es poder deshacer.

**Diseno minimo:**
- **Punto de restauracion antes de operacion de radio alto**: cuando el clasificador de forma (SE-273) marca una accion como irreversible o de radio amplio, se toma un punto de restauracion del alcance afectado antes de ejecutar. El sustrato git (`git stash` + `git stash apply`) hace la mitad del trabajo.
- **Alcance minimo**: se preserva lo que la accion va a tocar, no el workspace entero. Un punto de restauracion caro no se toma. Implementacion: `git stash push -- <rutas afectadas>` en lugar de `git stash --all`.
- **Deshacer verificable**: comando que revierte (`git stash pop --index`) y verifica que el estado coincide con el previo (`git diff --exit-code HEAD`), no que "parece bien".
- **Lo que git no cubre**: ficheros ignorados, estado fuera del repositorio, efectos en sistemas externos. Se declara explicitamente que **no** es reversible, en lugar de dar una falsa red de seguridad.
- **Conexion con el plano de control**: un veto durante una operacion de radio alto dispara la restauracion automaticamente.

**Acceptance criteria:**

AC-5.1. Operacion de radio alto sintetica → punto de restauracion tomado antes de ejecutar (test).
AC-5.2. Deshacer verificado por comparacion de estado (`git diff`), no por ausencia de error (test).
AC-5.3. Alcance minimo: el punto de restauracion cubre lo tocado y no el workspace completo (medido: `git stash list`).
AC-5.4. Lo no reversible declarado explicitamente antes de ejecutar; el operador lo ve (test de mensaje).
AC-5.5. Veto durante operacion de radio alto → restauracion disparada (test E2E con el plano de control SE-273).

**Esfuerzo:** 8h

---

## Slice 6 — Fiabilidad bajo repeticion (8h)

**Problema:** las evaluaciones actuales miden si Savia **puede** hacer algo. La pregunta que gobierna la autonomia es si **lo hace de forma consistente**. Son medidas distintas y hoy solo existe una.

**Diseno minimo:**
- **Metrica de consistencia**: `p_consistente = tareas_superadas_en_k_repeticiones / (tareas_intentadas * k)`. Comparar con `p_capacidad = tareas_superadas_al_menos_una_vez / tareas_intentadas`. La brecha `gap = p_capacidad - p_consistente` es el dato que hoy falta.
- **Aplicada por clase de tarea**, no en agregado: la fiabilidad de "generar un spec" y la de "aplicar un fix" no son intercambiables, y la autonomia se concede por clase.
- **Reutiliza la infraestructura existente** de evaluaciones (`evaluations/` + scripts de delta pareado). No se construye sistema nuevo (CRIT-004).
- **Anclaje de version obligatorio**: una serie de repeticiones a caballo de un cambio silencioso de version del modelo no mide fiabilidad, mide dos modelos distintos. Se registra el model_id + timestamp de la serie.
- **Sin objetivo prefijado**: se mide y se publica lo que salga. Un umbral decidido antes de conocer la distribucion es un deseo, no un criterio.
- **Arranque modesto**: 3 clases de tarea (spec-generation, code-review, bug-fix), k=3 repeticiones, 10 tareas por clase = 90 ejecuciones. Suficiente para validar la metrica sin disparar costes.

**Acceptance criteria:**

AC-6.1. Metrica de consistencia calculada para >=3 clases de tarea con k>=3 repeticiones y >=10 tareas por clase.
AC-6.2. Brecha capacidad-consistencia publicada por clase (gap en %).
AC-6.3. Anclaje de version verificado; serie a caballo de un cambio de modelo → marcada como no comparable (test).
AC-6.4. Reproducibilidad: misma serie, mismo anclaje → mismo resultado (+- tolerancia por no determinismo del modelo).
AC-6.5. Cero umbrales de decision fijados antes de la primera medicion (asercion documental: el script de decision de autonomia requiere >=1 medicion previa).

**Esfuerzo:** 8h

---

## Slice 7 — Degradacion fail-closed y autonomia graduada (4h)

**Problema:** dos cosas pueden anular todo lo anterior: que la contencion no este disponible y Savia siga adelante en el anfitrion, y que la frontera se relaje por costumbre en lugar de por evidencia.

**Diseno minimo:**
- **Fail-closed sin excepciones**: sin motor de contencion disponible, las tareas N-contenido y N-hostil **no se ejecutan**. No hay repliegue silencioso al anfitrion. El mensaje explica que falta y como habilitarlo.
- **Diferenciacion honesta de estado**: el operador siempre sabe si esta operando con contencion o sin ella. Trabajar sin contencion puede ser una decision legitima; hacerlo sin saberlo, no. Indicador en el prompt de Savia: `[CONTAINMENT: ACTIVE]` o `[CONTAINMENT: UNAVAILABLE — N-content/N-hostil disabled]`.
- **Politica de autonomia por clase**, ligada a S6: el nivel de contencion aplicable a una clase de tarea es funcion de su consistencia medida. Ampliar la frontera exige evidencia nueva, no tiempo transcurrido ni ausencia de incidentes. **La ausencia de incidentes no es evidencia de fiabilidad; es ausencia de medida.**
- **Revision de la frontera** en el self-audit (SE-258 S3): clases cuya consistencia bajo, contencion que se relajo sin evidencia, excepciones a anfitrion vencidas.
- **Suite adversarial permanente**: 5 pruebas — fuga de credencial, escritura fuera de ambito, cruce entre encargos, escalada de privilegios, repliegue silencioso al anfitrion, ampliacion de autonomia sin evidencia. Corre en CI tras cada push.

**Acceptance criteria:**

AC-7.1. Motor no disponible → tarea contenida rechazada con mensaje accionable; cero ejecuciones en anfitrion por repliegue (test central).
AC-7.2. Estado de contencion visible al operador en todo momento (test de indicador en prompt).
AC-7.3. Ampliacion de autonomia sin evidencia de consistencia → bloqueada (test adversarial).
AC-7.4. Revision de frontera en el self-audit con las tres comprobaciones (clases degradadas, contencion relajada, excepciones vencidas).
AC-7.5. Suite adversarial completa en verde y permanente en CI (los 6 tests no se saltan ni se deshabilitan).

**Esfuerzo:** 4h

---

## Verification method

1. **Escenario canonico**: Savia escribe un script en el turno y lo ejecuta. Debe correr contenido, sin credenciales, sin red salvo declaracion, y su salida debe pasar por gate antes de tocar el workspace. Es el test integral del spec.
2. **Escenario de cliente**: construccion de proyecto ajeno contenida, sin acceso al vault propio ni a otro encargo, con evidencia registrada.
3. **Escenario de fallo**: motor no disponible → rechazo, no repliegue.
4. **Reversibilidad**: operacion de radio alto deshecha y verificada por comparacion de estado.
5. **Fiabilidad**: brecha capacidad-consistencia publicada por clase.
6. **Coste**: latencia de contencion medida. Si el coste hace que se desactive, el spec ha fracasado aunque todos los tests pasen — por eso la medida es criterio de adopcion, no una nota.
7. Gate de archivo aplicado.

---

## Riesgos identificados pre-flight

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| R1: Friccion que lleva a desactivar la contencion | Alta | Critico | La mayoria del trabajo sigue en anfitrion por diseno (S1), reutilizacion de contenedor por sesion, latencia medida como criterio de adopcion, y distribucion publicada (AC-1.5) que delata clasificacion asfixiante o cosmetica |
| R2: Contencion nominal por herencia de entorno o montajes amplios | Media | Critico | Entorno limpio por defecto y cuatro vias de credencial probadas (AC-3.2) |
| R3: Dependencia de Docker no disponible en el entorno del usuario | Media | Alto | Interfaz con implementaciones intercambiables, ProcessRuntime como fallback de desarrollo, fail-closed honesto, documentacion de capacidades deshabilitadas |
| R4: Falsa sensacion de reversibilidad (S5) | Baja | Medio | Declarar explicitamente lo NO reversible antes de ejecutar (AC-5.4); prometer menos es lo unico honesto |
| R5: Medir consistencia es caro | Alta | Medio | k modesto (3), clases acotadas (3), cadencia baja, ejecucion en clase de trafico de fondo. Arranque con solo 90 ejecuciones totales |
| R6: Autonomia ampliada por confianza en vez de por evidencia | Media | Alto | Politica ligada a la medida (S7) y revision en el self-audit; la ausencia de incidentes no cuenta como evidencia |
| R7: Sobre-contencion que rompe flujos legitimos | Media | Alto | N-anfitrion es el nivel por defecto para codigo propio revisado; suite completa en verde tras cada slice |

---

## Orden recomendado

S1 (clasificacion, 8h: sin saber que corre donde, todo lo demas es arbitrario) → S2 (entorno, 10h) → S3 (credenciales, 8h: contencion sin esto es nominal) → S7 (fail-closed, 4h: antes de que nadie dependa de la contencion) → S4 (codigo de cliente, 8h: la justificacion contractual) → S5 (reversibilidad, 8h) → S6 (fiabilidad, 8h: independiente, puede ir en paralelo con S5 desde S1)

**Hito de contencion util tras S1+S2+S3+S7 (30h)**: lo que Savia escribe y ejecuta deja de correr con las llaves puestas. **Hito contractual tras S4**: el codigo de cliente se ejecuta con muralla a nivel de proceso.

---

## Decision de adopcion

Adoptar si: escenario canonico contenido, cuatro vias de credencial bloqueadas, fail-closed sin repliegue, murallas efectivas a nivel de proceso, y **latencia de contencion dentro del presupuesto declarado** (<2s para arranque en frio, <200ms por ejecucion en sesion reutilizada). Este ultimo criterio tiene el mismo rango que los demas: una contencion que estorba se desactiva, y una contencion desactivada no protege.

---

## Estructura de ficheros

```
scripts/
├── classify-execution-level.sh      # S1: clasifica script/hook por origen → N-anfitrion|contenido|hostil
├── execution-level-inventory.sh     # S1: inventario de scripts/hooks con nivel (salida: JSON/TSV)
├── containment-run.sh               # S2/S3: wrapper unico para ejecucion contenida
├── containment-check.sh             # S7: verificacion de disponibilidad del motor
├── restore-checkpoint.sh            # S5: punto de restauracion + deshacer
├── measure-reliability.sh           # S6: metricas de consistencia por clase
└── adversarial-containment.sh       # S7: suite adversarial (6 pruebas)

containment/
├── Dockerfile.base                  # S2: imagen base minima
├── session-container.sh             # S2: contenedor por sesion
└── container-policy.json            # S1: reglas de clasificacion versionadas

docs/
└── rules/domain/
    └── execution-containment.md      # S1+S7: politica documentada

tests/
├── test-classify-execution-level.bats    # S1 (6+ tests)
├── test-containment-run.bats             # S2 (8+ tests)
├── test-credential-isolation.bats        # S3 (6+ tests)
├── test-client-code-isolation.bats       # S4 (5+ tests)
├── test-restore-checkpoint.bats          # S5 (5+ tests)
├── test-measure-reliability.bats         # S6 (4+ tests)
├── test-fail-closed.bats                 # S7 (6+ tests)
└── test-adversarial-containment.bats     # S7 (6+ tests)
```

---

## OpenCode Implementation Plan (SE-110)

### Classification
- **Complexity:** VERY HIGH (7 slices, 7+ scripts, 6+ docs, ~46 tests, nuevo subsistema de contencion)
- **Risk:** HIGH (modifica el modelo de ejecucion de Savia; la mayoria de los riesgos son operativos, no tecnicos)
- **Parallelizable:** S1→S2→S3 son secuenciales. S6 puede ejecutarse en paralelo desde S1. S5 puede empezar tras S1.
- **Test surface:** ~46 tests BATS nuevos + suite adversarial permanente en CI

### Implementation Strategy
- **Agent:** tipos de agente mixto. S1-S3: `architect` + `infrastructure-agent`. S4: `architect` + `python-developer`/`typescript-developer`. S5: `architect`. S6: `evaluations-framework` + `dev-orchestrator`. S7: `architect` + `security-guardian`.
- **Review:** `code-reviewer` + `security-guardian` post-S3 (credenciales), `legal-compliance` post-S4 (encargos)
- **Gates:**
  - Gate 1 (post-S1+S2): `bash tests/test-classify-execution-level.bats && bash tests/test-containment-run.bats` → all pass
  - Gate 2 (post-S3): `bash tests/test-credential-isolation.bats` → all pass + `security-guardian` review
  - Gate 3 (post-S4): `bash tests/test-client-code-isolation.bats` → all pass + `legal-compliance` review
  - Gate 4 (post-S7): `scripts/adversarial-containment.sh` → 6/6 adversarial tests pass en CI
- **Security review:** Obligatorio y multiple (post-S3, post-S4, post-S7)
- **Adopcion gate final:** escenario canonico pasa, latencia medida < presupuesto

---

## Referencias

- SE-273: contencion de trayectoria (guards de forma, allowlist de egreso)
- SE-271: encargos y paquetes de evidencia
- SE-274: excepciones con caducidad y deriva de proveedor
- SE-258 S3: self-audit
- SE-260: contrato de artefactos gestionados
- CRIT-004: reutilizar infraestructura existente
- CRIT-005: ACs falsificables
- CRIT-013: declarar lo NO reversible
- CRIT-018: sin medicion no hay prioridad; autonomia por evidencia
- CRIT-021: reversibilidad decide la velocidad
- CRIT-023: fail-closed sin repliegue silencioso
