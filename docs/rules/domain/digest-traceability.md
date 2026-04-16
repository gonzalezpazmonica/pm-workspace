# Regla: Trazabilidad de Digestiones — Idempotencia Universal

> **REGLA OBLIGATORIA** — Aplica a TODOS los proyectos y a TODA fuente de datos procesada por Savia.

---

## Principio

Toda fuente de datos externa que Savia procese (digiera, transcriba, resuma o extraiga información)
DEBE registrarse en un log de trazabilidad. Esto garantiza:

1. **Idempotencia**: nunca reprocesar lo que ya se digirió
2. **Trazabilidad**: saber qué fuentes alimentaron qué outputs
3. **Auditoría**: reconstruir la cadena de información fuente → digest → decisión
4. **Eficiencia**: antes de digerir, consultar el log y saltar lo ya procesado

---

## Fuentes cubiertas

- **Documentos**: DOCX, PDF, PPTX, XLSX, TXT de SharePoint, Drive, local
- **Transcripciones**: VTT, SRT de reuniones grabadas (Teams, Meet, Zoom)
- **Notas de reunión**: MD/TXT generados por IA de plataformas de videoconferencia
- **Audio**: grabaciones de voz procesadas via `/voice-inbox`
- **Web**: páginas, APIs, documentación externa descargada
- **Repositorios**: código externo analizado via `/evaluate-repo`
- **Imágenes/diagramas**: screenshots, wireframes, organigramas importados
- **Cualquier otra fuente** que genere un output digerido dentro del proyecto

---

## Fichero de log por proyecto

Cada proyecto tiene UN log centralizado:

```
projects/{proyecto}/_digest-log.md
```

Si un proyecto necesita logs separados por área (documentos vs reuniones),
puede usar ficheros auxiliares que referencien al log central:

```
projects/{proyecto}/meetings/_meeting-digest-log.md  → auxiliar
projects/{proyecto}/docs/_doc-digest-log.md          → auxiliar
projects/{proyecto}/_digest-log.md                   → consolidado
```

Los logs auxiliares son opcionales. El consolidado es OBLIGATORIO.

---

## Formato de entrada

Cada fuente procesada se registra como un item de lista con checkbox:

```markdown
- [x] {tipo} | {nombre_fuente} | {fecha_fuente} | digest: {fecha_digestion} | output: {ruta_output}
- [ ] {tipo} | {nombre_fuente} | {fecha_fuente} | pendiente
```

Campos:
- **tipo**: doc, meeting, one2one, daily, audio, web, repo, diagram, video
- **nombre_fuente**: nombre del fichero o URL (sin ruta absoluta, relativa al proyecto)
- **fecha_fuente**: fecha del contenido original (YYYY-MM-DD)
- **fecha_digestion**: cuándo se procesó (YYYY-MM-DD)
- **ruta_output**: fichero(s) .md generados como resultado

---

## Protocolo de idempotencia

ANTES de iniciar cualquier digestión:

1. Leer `_digest-log.md` del proyecto
2. Buscar la fuente por nombre
3. Si ya está marcada [x] → SALTAR, informar: "Ya digerido el {fecha}"
4. Si está marcada [ ] → procesar, luego actualizar a [x]
5. Si no aparece → procesar, añadir entrada nueva como [x]

### Detección de cambios

Si la fuente ya fue digerida pero ha sido **modificada** desde entonces:

- Comparar fecha de modificación del fichero vs fecha_digestion
- Si fichero es más reciente → re-digerir y actualizar entrada
- Añadir nota: "re-digest: fichero modificado desde última digestión"

---

## Secciones del log

Organizar por tipo de fuente: `## Documentos (doc)`, `## Reuniones (meeting, daily, status)`,
`## One-to-ones (one2one)`, `## Audio / Voz (audio)`, `## Web / APIs (web)`,
`## Diagramas / Imágenes (diagram)`, `## Repositorios (repo)`.

Creación automática por `/project-new` o al primera digestión si no existe.

---

## Integración con agentes

Los agentes de digestión DEBEN: (1) recibir la ruta al log, (2) consultar si ya procesado ANTES de leer, (3) actualizar el log al terminar o devolver `digest_entry:` YAML para que el orquestador actualice.

Ademas, antes de escribir output deben consultar `projects/{proyecto}/.context-index/PROJECT.ctx` (si existe) y usar sus entradas `[digest-target]` para decidir DONDE almacenar cada tipo de informacion extraida.

---

## Límites y privacidad

- Max 200 entradas/sección → archivar >6 meses a `_digest-log-archive.md`
- El log NO se incluye en git (datos de proyecto, gitignored) — SÍ en backups
- Contiene nombres de ficheros de cliente → vive dentro de `projects/` (protegido)

---

## Prohibido

```
NUNCA → Digerir sin consultar el log primero
NUNCA → Dejar una digestión sin registrar en el log
NUNCA → Borrar entradas del log (solo archivar)
NUNCA → Incluir contenido de las fuentes en el log (solo metadata)
NUNCA → Rutas absolutas en el log (solo relativas al proyecto)
```
