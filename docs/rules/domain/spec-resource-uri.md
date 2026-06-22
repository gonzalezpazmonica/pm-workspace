---
context_tier: L3
token_budget: 600
audience: all-agents
spec: SE-222
---

# Regla: `resource:` URI Convention para specs y reglas

> **REGLA APLICATIVA** — Aplica a `docs/propuestas/*.md` y `docs/rules/domain/*.md`.
> Spec: SE-222 S0 (OKF Adoptable Patterns). Fecha: 2026-06-23.

## Principio

Cada spec y regla con origen externo conocido (repo, paper, RFC, work item)
debe incluir el campo `resource:` en su frontmatter YAML. El campo apunta al
URI canonico desde el que se derivo el documento.

Esto formaliza el patron LLM-wiki (Karpathy gist, formalizado por Google OKF
v0.1) en el modelo de cupulas de Savia: el campo navegable separa la prosa
de origen (`origin:` como descripcion) del URI canonico (`resource:` como
referencia automatizable).

## Formato

```yaml
---
spec_id: SE-XXX
title: ...
status: PROPOSED
origin: analisis comparativo X vs Y (texto libre)
resource: "https://github.com/owner/repo"
---
```

URIs aceptados:

- `https://` y `http://` para repos, papers, blogs, RFCs
- `file://` para referencias a ficheros locales en N1 (no para N2-N4b)
- `mailto:` para contacto de origen (sin PII, solo aliases publicos)
- `urn:` para identificadores estandar (DOI, arXiv, ISBN)

## Cuando se aplica

- **Specs nuevas** (`docs/propuestas/`) con origen externo: campo obligatorio
- **Reglas nuevas** (`docs/rules/domain/`) derivadas de fuente verificable: obligatorio
- **Specs/reglas internas** sin origen externo (decision interna, retro,
  user-active): campo opcional (omitir es valido)
- **Back-fill**: prioridad alta para specs IMPLEMENTED con origen identificable

## Validacion

```bash
bash scripts/spec-validator.sh <fichero.md>
bash scripts/spec-validator.sh --strict <fichero.md>
bash scripts/spec-validator.sh --batch docs/propuestas/ --json
```

Reglas activas:

1. WARN si `origin:` presente pero `resource:` ausente
2. WARN si `resource:` no es URI valido

## Restricciones de seguridad

`resource:` debe apuntar SOLO a recursos publicos.

No apuntar a:

- Hosts internos no resolubles publicamente
- Cualquier URL que requiera autenticacion corporativa para resolverse

El validator no bloquea estos casos (decision humana caso a caso), pero el
sovereignty-scan en pre-commit los detecta y bloquea el push.

## Relacion con otras reglas

- `smart-frontmatter.md`: campos en commands (`model`, `allowed-tools`).
  `resource:` es para specs/rules, no para commands.
- `context-origin-tagging.md`: trazabilidad de fragmentos cargados.
  `resource:` es metadato persistente; context-origin-tagging es runtime.
- `output-taxonomy.md`: donde va cada fichero en `output/`. `resource:`
  apunta al origen externo, no a un fichero generado.

## Que NO cambia

- Modelo de cupulas N1-N4b: intacto
- Frontmatter de skills (`SKILL.md`): no anade `resource:` salvo si tiene origen externo
- Knowledge Graph (SE-162): no se acopla al `resource:`. Son ortogonales
