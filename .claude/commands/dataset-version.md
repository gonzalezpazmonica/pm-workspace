---
name: dataset-version
description: >
  Registra y versionea datasets con hashing e integridad. Soporta DVC y Git LFS.
  Compara versiones, verifica cambios, sincroniza localmente.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

# /dataset-version {proyecto} {subcommand} {args}

## Subcomandos

- `register {path} {version} {descripción}` — Registra dataset con hash SHA256
- `diff {version1} {version2}` — Compara dos versiones mostrando cambios
- `pull {version}` — Descarga/sincroniza versión local con la registrada
- `list [--details]` — Muestra todos los datasets registrados
- `validate {version}` — Verifica integridad mediante hash

## Prerequisitos

1. Verificar que `projects/{proyecto}/` existe
2. Crear `projects/{proyecto}/datasets/` si no existe
3. Crear `registry.json` inicial si no existe (formato: [])
4. Detectar: ¿usa DVC? ¿usa Git LFS? ¿local?

## Ejecución

1. 🏁 Banner: `══ /dataset-version — {proyecto}/{subcommand} ══`
2. **register**: Leer fichero/carpeta, calcular SHA256, crear entrada con fecha, usuario
3. **diff**: Cargar dos versiones del registry, crear tabla: ficheros añadidos/modificados/eliminados
4. **pull**: Buscar versión en registry, sincronizar con DVC/LFS o copiar si local
5. **list**: Mostrar tabla: dataset, versión, tamaño, fecha, descripción, estado_local
6. **validate**: Recalcular SHA256 actual, comparar con registry, informar integridad
7. Escribir agent-note: `projects/{proyecto}/agent-notes/dataset-{version}-{accion}.md`
8. ✅ Banner fin con versión o resultado validación

## Output

```
projects/{proyecto}/datasets/registry.json (actualizado)
projects/{proyecto}/datasets/{dataset-slug}/{version}/ (sincronizado)
```

## Reglas

- Cada entrada registry: {name, version, path, hash_sha256, size_bytes, date, user, description, storage}
- storage puede ser: dvc, git-lfs, local
- version formato: v1.0.0 o YYYYMMDD (timestamp)
- diff genera tabla mostrando: fichero | tamaño_v1 | tamaño_v2 | delta
- validate recalcula hash, avisa si no coincide (corrupción potencial)
- pull crea/actualiza fichero local, registra en log de sincronización
