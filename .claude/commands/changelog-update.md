---
name: changelog-update
description: >
  Actualiza CHANGELOG.md automáticamente analizando los commits desde la última
  versión/release. Clasifica los cambios por tipo (feat, fix, docs, etc.) usando
  los commits convencionales del workspace. Opcionalmente sugiere bump de versión
  semántica. Delega la redacción final a tech-writer.
---

# Actualización de CHANGELOG

> Analiza los commits desde la última versión y actualiza `CHANGELOG.md`
> siguiendo el formato "Keep a Changelog" (https://keepachangelog.com).

---

## Protocolo

### 1. Identificar la última versión

```bash
# Buscar el último tag de versión
git tag --sort=-v:refname | head -5

# Si no hay tags, buscar la última entrada en CHANGELOG.md
head -30 CHANGELOG.md
```

### 2. Obtener commits desde la última versión

```bash
# Si hay tag
git log v{LAST_VERSION}..HEAD --oneline --no-merges

# Si no hay tag, desde el último cambio del CHANGELOG
git log --oneline --no-merges -50
```

### 3. Clasificar commits por tipo

Usando los tipos definidos en `.claude/rules/github-flow.md`:

| Tipo | Sección CHANGELOG |
|---|---|
| `feat` | ### Added |
| `fix` | ### Fixed |
| `docs` | ### Documentation |
| `refactor` | ### Changed |
| `chore` | ### Maintenance |
| `test` | ### Testing |
| `ci` | ### CI/CD |

Ignorar commits de merge y commits del tipo `wip`.

### 4. Generar la nueva sección

Formato de cada entrada:
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Descripción clara del cambio (#PR o commit hash)

### Fixed
- Descripción del bug corregido

### Changed
- Descripción del cambio de comportamiento
```

### 5. Sugerir versión semántica

Analizar los commits para proponer el bump:
- **MAJOR** (X.0.0): si hay commits con `feat!:` o `BREAKING CHANGE`
- **MINOR** (0.X.0): si hay commits `feat:` sin breaking changes
- **PATCH** (0.0.X): si solo hay `fix:`, `docs:`, `chore:`

Proponer al humano — **NUNCA** hacer bump automáticamente.

### 6. Delegar redacción final

Si el agente `tech-writer` está disponible, delegar la redacción final para
garantizar consistencia de tono y estilo con el resto del CHANGELOG.

### 7. Presentar al humano

Mostrar la sección generada y preguntar:
- ¿Versión propuesta es correcta?
- ¿Alguna entrada necesita ajuste?
- ¿Procedo a actualizar CHANGELOG.md?

Solo tras confirmación, escribir en el fichero.

---

## Restricciones

- **NO hacer bump de versión sin confirmación** del humano
- **NO crear tags de Git** — eso es responsabilidad del humano
- **NO modificar CHANGELOG.md** sin mostrar primero la propuesta
- Respetar el formato existente del CHANGELOG.md del workspace
- Si no hay commits nuevos desde la última versión, informar y no generar nada
