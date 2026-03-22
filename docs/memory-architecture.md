# Mi Sistema de Memoria

Soy Savia. Cada vez que cierras la conversacion, yo pierdo todo lo que hablamos. Asi funciona Claude: cada sesión empieza de cero. Eso es un problema enorme si gestionas proyectos, porque las decisiones de ayer importan hoy.

Este documento explica como resolvi ese problema. Como recuerdo cosas entre sesiones, como las busco después, y como me aseguro de que nunca dependas de una herramienta que no puedas leer tu misma con tus propios ojos.

---

## Lo más importante: todo se guarda en ficheros de texto

Si solo lees una frase de este documento, que sea esta:

**Mi memoria son ficheros de texto plano que cualquier persona puede abrir, leer y editar con un editor de texto normal.**

No hay una base de datos oculta. No hay un servicio en la nube que guarde tus datos. No hay una caja negra. Si mañana desaparezco, tus ficheros siguen ahi, legibles, buscables con `grep`, editables con cualquier editor.

Esto es una decision de diseño deliberada:
- **Portabilidad**: mueves los ficheros a otro ordenador y funcionan.
- **Transparencia**: abres el fichero y ves exactamente lo que recuerdo.
- **Durabilidad**: el texto plano es el formato más longevo de la informática. Un fichero de texto de 1970 se lee hoy sin problemas. Una base de datos de 2020 puede necesitar software específico para abrirse.
- **Control**: si algo que recuerdo es incorrecto, lo editas directamente.
- **Independencia**: no necesitas ni Savia ni Claude ni ningun software para acceder a tu propia memoria.

---

## Qué recuerdo y como lo organizo

Cada cosa que vale la pena recordar la guardo como una "observación". Una observación es una linea en un fichero de texto con esta información:

- **Que paso** (What) — el hecho concreto
- **Por que importa** (Why) — la razón
- **Donde** (Where) — en que parte del proyecto o codigo
- **Que aprendi** (Learned) — la leccion para la proxima vez

Por ejemplo, si en una reunion el equipo decide usar PostgreSQL en vez de MySQL, yo guardo:

```
Que: Elegimos PostgreSQL para la base de datos del proyecto
Por que: Mejor soporte para JSON y extensiones mas maduras
Donde: Proyecto Alpha, capa de persistencia
Aprendi: Siempre evaluar las extensiones disponibles antes de elegir BD
```

Cada observación tiene ademas:
- Un **tipo**: decision, bug, patron, descubrimiento, convencion, arquitectura
- Una **etiqueta temática** (topic key): `decision/postgresql`, `bug/token-timeout`
- Un **proyecto** asociado
- Una **fecha** de cuando se registro
- Opcionalmente, una **fecha de caducidad** — porque no todo es relevante para siempre. "El sprint actual termina el viernes" caduca; "Usamos PostgreSQL" no caduca.

Cuando actualizo una decision (por ejemplo, "finalmente cambiamos de PostgreSQL a MongoDB"), guardo la nueva decision Y registro que reemplaza a la anterior. Asi nunca pierdo el histórico de por que cambiamos de opinión.

---

## Donde viven fisicamente estos ficheros

Todo esta dentro de tu carpeta de trabajo. Nada sale de tu ordenador.

### El fichero principal: la memoria

```
output/.memory-store.jsonl
```

Es un fichero de texto donde cada linea es una observación en formato JSON. Puedes abrirlo con cualquier editor. Cada linea es independiente — si borras una, las demás siguen funcionando.

Ejemplo real de una linea (formateada para que se lea mejor):

```json
{
  "ts": "2026-03-22T10:00:00Z",
  "type": "decision",
  "title": "Usar PostgreSQL",
  "content": "What: Elegimos PostgreSQL | Why: Mejor JSON | Where: Backend | Learned: Evaluar extensiones",
  "topic_key": "decision/usar-postgresql",
  "concepts": ["database", "backend"],
  "project": "alpha",
  "rev": 1
}
```

Si el equipo cambia de opinión y elige MongoDB, la siguiente linea tendra `"rev": 2` y un campo `"supersedes": "Elegimos PostgreSQL"` para que se vea que hubo un cambio y cual era la decision anterior.

### Las notas personales

```
~/.claude/projects/*/memory/
```

Aqui guardo lo que aprendo sobre ti: que prefieres informes cortos, que trabajas con Azure DevOps, que tu equipo usa sprints de 2 semanas. Claude Code carga estos ficheros automáticamente cuando empezamos a hablar. Son markdown normal — los puedes leer y editar.

### El conocimiento de cada proyecto (la parte más rica)

Esta es probablemente la parte más importante de mi memoria, y la que mas usas sin darte cuenta. Cada proyecto tiene su propia carpeta con ficheros markdown que cualquiera puede leer:

```
projects/{nombre-proyecto}/
  CLAUDE.md               — como funciona este proyecto, sus reglas, sus entornos
  reglas-negocio.md       — las reglas de negocio: que se puede, que no, por que
  equipo.md               — quien trabaja aqui, que rol tiene, que sabe hacer
  stakeholders.md         — con quien hablamos, que les importa, como tratarles
  decision-log.md         — todas las decisiones tomadas, con fecha y contexto
  meetings/               — digestiones de cada reunion
    2026-03-15-sprint-review.md
    2026-03-18-daily.md
    2026-03-20-one2one-carlos.md
  agent-memory/           — lo que mis agentes aprenden del proyecto
    meeting-digest/MEMORY.md
    pdf-digest/MEMORY.md
    meeting-risk-analyst/MEMORY.md
```

**Cada uno de estos ficheros es markdown puro.** Los puedes abrir, leer, editar, compartir con el equipo, imprimir. No hay nada oculto.

Cuando me pides el estado del sprint, yo leo `equipo.md` para saber quien esta en el equipo. Cuando proceso una reunion, leo `reglas-negocio.md` para entender si lo que se discutio tiene sentido. Cuando asigno una tarea, leo `equipo.md` para saber las competencias de cada persona.

**Las digestiones de reuniones** son especialmente valiosas. Cuando procesas una transcripcion conmigo, extraigo:
- Decisiones tomadas (van a `decision-log.md`)
- Action items (con responsable y fecha)
- Actualizaciones de perfiles (si alguien demuestra una competencia nueva)
- Riesgos detectados (contradicciones con reglas de negocio, dependencias)
- Información de stakeholders (como prefieren que les presenten las cosas)

Todo esto queda en ficheros markdown dentro de la carpeta del proyecto. Si cambias de herramienta, de IA, o de PM — esos ficheros siguen siendo útiles porque son legibles por humanos.

**Aislamiento entre proyectos:** la información del Proyecto Alpha nunca aparece cuando trabajo en el Proyecto Beta. Cada proyecto es un silo independiente. Esto es critico cuando gestionas proyectos de clientes diferentes que no deben conocer la información del otro.

### La memoria de mis agentes

Ademas de la carpeta del proyecto, mis agentes especializados guardan lo que aprenden:

```
public-agent-memory/     — patrones genericos (buenas practicas, DDD, SOLID)
                           Esto SI va al repositorio publico porque no tiene datos privados.

private-agent-memory/    — patrones de tu organizacion (como trabaja tu equipo, vocabulario interno)
                           Esto NO va al repositorio (gitignored).

projects/{p}/agent-memory/ — aprendizajes de ese proyecto concreto
                           Esto NO va al repositorio (gitignored).
```

La regla es simple: si es conocimiento generico que beneficia a cualquiera, va a la memoria publica. Si tiene datos de tu equipo o tu cliente, se queda local.

---

## Cómo busco en mi memoria

Aqui es donde la cosa se pone interesante. Tener ficheros de texto esta bien, pero si tienes 500 observaciones, buscar manualmente es lento. Por eso tengo **aceleradores de búsqueda** — pero quiero que entiendas una cosa fundamental:

**Los aceleradores son como el indice de un libro. Si arrancas el indice, el libro sigue teniendo toda la información. Solo tardas mas en encontrar la pagina.**

Mis aceleradores son ficheros que yo genero automáticamente a partir del texto plano. Si los borro, los regenero. Si no estan, busco directamente en el texto (mas lento, pero funciona).

### Búsqueda por palabras (siempre funciona)

La mas básica. Busco las palabras exactas que me pides en los titulos, contenidos y etiquetas de mis observaciones. Funciona sin instalar nada extra.

Si buscas "PostgreSQL", encuentro todo lo que tenga esa palabra.

**Limitación**: si buscas "problemas de base de datos", no encuentro la observación que dice "PostgreSQL timeout en producción" — porque las palabras no coinciden aunque el significado si.

### Búsqueda por significado (necesita una instalación extra)

Para superar esa limitación, puedo crear un **indice de significados**. Funciona asi:

1. Leo cada observación y la convierto en una lista de numeros que representan su significado (esto se llama "embedding" en IA, pero lo importante es que es una representacion matemática del significado).
2. Cuando buscas algo, convierto tu búsqueda en la misma representacion matemática.
3. Comparo los numeros y te devuelvo las observaciones cuyo significado es más parecido al de tu búsqueda.

El resultado: si buscas "problemas de autenticacion", encuentro "timeout en el token de refresco" aunque no compartan ninguna palabra — porque el significado es similar.

**Datos reales**: en mis benchmarks, la búsqueda por palabras encuentra el resultado correcto el 40% de las veces. La búsqueda por significado lo encuentra el 90% de las veces.

El modelo que uso para entender significados pesa 22 MB, se ejecuta en tu procesador (no necesita GPU ni internet), y tiene licencia libre (Apache 2.0). Puedes instalarlo o no — sin el, la búsqueda por palabras sigue funcionando.

### Búsqueda por relaciones (para preguntas complejas)

A veces no buscas un texto parecido, sino una relación: "¿quien decidio usar PostgreSQL?" o "¿que tecnologias estan vinculadas al proyecto Alpha?".

Para eso extraigo **entidades** (nombres de tecnologias, conceptos, proyectos) y **relaciones** (quien decidio que, que afecta a que) de cada observación. Esto forma un mapa de conexiones que me permite navegar por relaciones, no solo por similitud.

Este mapa también es un fichero de texto (JSON), generado automáticamente, borrable y regenerable.

---

## Cómo llega información a mi memoria

Hay tres caminos por los que aprendo cosas:

### 1. Trabajando contigo en conversacion

Mientras hablamos, detecto decisiones, correcciones, descubrimientos y patrones. Cuando ejecutas `/compact` (para liberar espacio en la conversacion), automáticamente extraigo lo importante y lo guardo antes de que se pierda.

### 2. Procesando documentos y reuniones

Tengo 7 agentes especializados en "digerir" información:

| Agente | Que procesa | Ejemplo |
|--------|------------|---------|
| meeting-digest | Transcripciones de reuniones | Acta de Sprint Review |
| pdf-digest | Documentos PDF | Manual de arquitectura |
| word-digest | Documentos Word | Propuesta de cliente |
| excel-digest | Hojas de calculo | Presupuesto del proyecto |
| pptx-digest | Presentaciones | Kickoff del proyecto |
| visual-digest | Imagenes, pizarras, capturas | Foto de whiteboard |
| meeting-risk-analyst | Riesgos detectados en reuniones | Conflictos, dependencias |

Cada uno de estos agentes, al terminar de procesar un documento, hace dos cosas:

1. **Guarda la digestion completa** en la carpeta del proyecto (`projects/{nombre}/meetings/` o el directorio correspondiente) como un fichero markdown legible. Esto incluye el resumen, los action items, las decisiones, los perfiles actualizados.

2. **Envia los aprendizajes clave** a mi memoria central (el fichero JSONL) para que esten disponibles en búsquedas semánticas. Asi, la información de una reunion de hace un mes aparece cuando buscas "problemas de rendimiento" aunque estemos trabajando en otra cosa.

El resultado: los ficheros markdown del proyecto son la referencia completa y legible. La memoria central es el indice que me permite encontrar cosas rapidamente entre cientos de reuniones y documentos.

### 3. Manualmente

Tu o cualquier persona del equipo puede añadir observaciones directamente:

```bash
bash scripts/memory-store.sh save \
  --type decision \
  --title "Cambiar de proveedor de hosting" \
  --what "Migramos de AWS a Hetzner" \
  --why "Reducir costes un 60%" \
  --where "Infraestructura" \
  --learned "Hetzner no tiene CDN propio, necesitamos Cloudflare"
```

---

## Qué pasa cuando la información caduca

No toda la información es eterna. "El sprint actual termina el viernes" es útil hoy pero irrelevante la semana que viene. Para gestionar esto:

- Cuando guardo una observación, puedo ponerle una **fecha de caducidad**. Ejemplo: las notas de sesión caducan a los 30 dias, los descubrimientos a los 90 dias.
- Las decisiones y los bugs **no caducan nunca** — son lecciones permanentes.
- Las observaciones caducadas no se borran — simplemente dejan de aparecer en las búsquedas. Siguen en el fichero de texto por si alguien necesita consultarlas.
- Si quieres ver todo, incluido lo caducado: `search "query" --include-expired`.

---

## Qué pasa cuando cambio de opinión

Las decisiones evolucionan. Hoy usamos JWT para autenticacion, mañana cambiamos a OAuth2. Cuando eso ocurre:

1. La nueva decision reemplaza a la antigua en las búsquedas.
2. Pero la antigua queda registrada en un campo "supersedes" — así siempre puedes ver **que habia antes** y entender **por que se cambio**.
3. El número de revision se incrementa (rev: 1 → rev: 2 → rev: 3...).

Esto evita dos problemas:
- **Información obsoleta**: la búsqueda te devuelve la decisión actual, no la de hace 6 meses.
- **Perdida de contexto**: si necesitas entender por que se cambio, el histórico esta ahi.

---

## La regla de oro: texto plano sobrevive a todo

Quiero ser muy clara sobre la jerarquia:

```
TEXTO PLANO (ficheros .jsonl y .md)
  |
  |  Son la única verdad. Todo lo demás se deriva de ellos.
  |
  +--→ Indice de significados (.idx)     — ACELERADOR, regenerable
  +--→ Mapa de relaciones (.json)        — ACELERADOR, regenerable
  +--→ Indice vectorial (.map)           — ACELERADOR, regenerable
```

Si borras los aceleradores: los regenero en segundos.
Si borras el texto plano: la información se pierde (por eso esta versionado con git).

Si mañana sentence-transformers desaparece, o hnswlib deja de mantenerse, o cambiamos de modelo de IA — **tus datos siguen intactos en texto plano**. Buscamos otro acelerador y listo.

Si mañana desaparezco yo misma — **tus ficheros siguen siendo legibles por cualquier humano con un editor de texto**.

Esto no es un accidente. Es una decision filosofica: **la dependencia cero de cualquier herramienta, incluida yo misma**.

---

## El panorama completo: como se conecta todo

Imagina que llevas 6 meses gestionando un proyecto. En ese tiempo:
- Has tenido 50 reuniones (digeridas en `projects/{nombre}/meetings/`)
- Has tomado 30 decisiones (en `decision-log.md` y en mi memoria central)
- Has procesado 10 documentos del cliente (digeridos en la carpeta del proyecto)
- Tu equipo ha resuelto 20 bugs (registrados como observaciones)
- Has cambiado 5 decisiones (con `supersedes` para mantener el histórico)

Toda esa información vive en ficheros de texto. Puedes:
- **Abrir la carpeta del proyecto** y leer las actas de reuniones como markdown
- **Buscar "rendimiento"** y encontrar el bug de N+1 queries de hace 3 meses
- **Preguntarme "que decidimos sobre la base de datos"** y obtener la decisión actual Y la anterior
- **Ver el equipo** abriendo `equipo.md`
- **Compartir con un nuevo miembro** copiandole la carpeta — toda la historia del proyecto esta ahi

Y si algun dia cambias de herramienta, de IA, o decides prescindir de mi:
- Los ficheros markdown siguen siendo ficheros markdown
- Las actas de reuniones siguen siendo legibles
- Las decisiones siguen documentadas
- No hay lock-in, no hay exportacion, no hay migracion

---

## Privacidad

- **Nada sale de tu ordenador.** Cero telemetria. Cero conexiones a servidores externos para la memoria.
- El modelo de búsqueda semántica (22 MB) se descarga una vez y se ejecuta localmente en tu CPU.
- Los ficheros de memoria estan en directorios excluidos de git (gitignored) — no se publican aunque hagas push.
- Los datos de cada proyecto estan aislados: la información de un cliente nunca se mezcla con la de otro.
- Si necesitas borrar todo lo que se sobre un tema: editas el fichero de texto y listo.

---

## Cómo verificar que todo funciona

```bash
# Ver el estado de mi memoria
bash scripts/memory-store.sh index-status

# Ver estadisticas (cuantas observaciones, de que tipo)
bash scripts/memory-store.sh stats

# Buscar algo
bash scripts/memory-store.sh search "autenticacion"

# Ver las ultimas 20 observaciones
bash scripts/memory-store.sh context

# Verificar que todos mis sistemas estan operativos
bash scripts/readiness-check.sh
```

---

## Tres niveles de potencia

No necesitas instalar nada extra para que mi memoria funcione. Pero si quieres búsquedas mas inteligentes:

| Nivel | Que necesitas | Que puedo hacer | Calidad de búsqueda |
|-------|--------------|-----------------|---------------------|
| **Basico** | Nada extra | Buscar por palabras exactas | 40% de acierto |
| **Intermedio** | Nada extra | + Buscar por relaciones (grafo) | 55% de acierto |
| **Completo** | `pip install sentence-transformers hnswlib` | + Buscar por significado + reranking | 95% de acierto |

El nivel basico siempre funciona. Los demás son mejoras opcionales.

---

## Resumen visual

```
                    TU
                     |
          (conversacion, documentos, manual)
                     |
                     v
            +-----------------+
            |  MEMORIA        |
            |  (texto plano)  |  ← ficheros .jsonl y .md
            +-----------------+  ← legibles por humanos
               |     |     |
               v     v     v
            Indice  Grafo  Indice    ← aceleradores
            signif. relac. palabras     (derivados, opcionales)
               |     |     |
               +-----+-----+
                     |
                     v
              BÚSQUEDA UNIFICADA
                     |
                     v
             Resultados ordenados
             por relevancia
```

La información entra por arriba (conversacion, documentos, entrada manual), se persiste en texto plano en el centro, y los aceleradores de abajo hacen que buscar sea rapido. Pero el centro — los ficheros de texto — es lo único que realmente importa.
