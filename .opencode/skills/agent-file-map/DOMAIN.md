# Domain — Agent File Map

## Por qué existe esta skill

Los proyectos reales dependen de ficheros que viven fuera del repositorio git: Excels de capacity en OneDrive corporativo, PDFs de contratos en SharePoint, dashboards PowerBI exportados, videos de reuniones, diagramas en Miro. Los agentes los necesitan en cada sesión pero no los encuentran sin ayuda — y cuando los encuentran, a menudo con paths erróneos por caracteres especiales.

.afm elimina esta fricción con un índice pre-calculado y verificado.

## Conceptos de dominio

- **Fichero externo**: recurso referenciable desde el proyecto que NO vive en el git del workspace (OneDrive, SharePoint, NAS, drive compartido, S3)
- **Alias canónico**: nombre del fichero usado para referenciarlo (ej. `Sprint26.xlsx`)
- **Path real**: ruta absoluta donde existe en disco, con sintaxis del SO del usuario
- **Variable de base**: abreviación simbólica para paths largos (`$ONEDRIVE`, `$PROJECT_SHARED`)
- **Digest**: fichero markdown dentro del workspace que contiene la extracción digerida del fichero externo
- **Categoría**: agrupación semántica (Sprint tracking, Diagramas, Compliance...)

## Reglas de negocio implementadas

- **RN-AFM-01**: un .afm solo referencia ficheros que existan al momento de añadirlos
- **RN-AFM-02**: el nivel de confidencialidad del .afm es el más alto de sus entradas
- **RN-AFM-03**: si un fichero tiene digest asociado, el digest se referencia en la entrada
- **RN-AFM-04**: paths con espacios o caracteres especiales se escriben tal cual (no escapar)
- **RN-AFM-05**: variables `$VAR` se resuelven en la sección `Convenciones de path`
- **RN-AFM-06**: los .afm NO contienen credenciales, tokens, ni contenido de los ficheros
- **RN-AFM-07**: si un path cambia, el .afm se actualiza antes que cualquier digest que lo referencie

## Relación con otras skills

**Upstream (depende de)**:
- `project-new` / `onboarding-dev` — llaman a `/afm:init` al crear proyecto

**Downstream (es usada por)**:
- `meeting-digest` — consulta .afm para localizar transcripciones fuente
- `sprint-management` — consulta .afm para el Excel de planning activo
- `capacity-planning` — consulta .afm para Excel de capacidad
- `excel-digest` — consulta .afm para saber dónde están los Excel a digerir

**Paralelas (comparten ubicación `.agent-maps/`)**:
- `agent-code-map` (.acm) — mapas de código fuente
- `human-code-map` (.hcm) — mapas narrativos

## Decisiones clave

- **.afm en lugar de extender .acm**: .acm está diseñado para código; los ficheros externos tienen otras propiedades (path, formato, hojas, páginas). Separar evita que los .acm crezcan con ruido.
- **Ubicación en `.agent-maps/files/`**: subcarpeta dedicada dentro de la estructura existente, no crear un `.file-maps/` paralelo (reduce fragmentación)
- **YAML frontmatter + markdown**: consistente con .acm / .hcm / SKILL.md — facilita lectura humana y parseo por agentes
- **Sin ejecución automática**: .afm es declarativo. No ejecuta scripts ni abre ficheros. Los agentes deciden qué hacer con el path que reciben.
- **Actualización manual**: no hay sync automática. El PM decide qué ficheros son lo suficientemente importantes para indexar.
