# Spec: SCM Freshness Check — Fix --check mode to be read-only

**Task ID:**        SPEC-SCM-FRESHCHECK
**PBI padre:**      SE-084 Slice 1 — Skill catalog quality audit (Era 190)
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (auditoria SCM integrity)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     S 2h
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      10

---

## 1. Contexto y Objetivo

`scripts/generate-capability-map.py` no soporta un flag `--check`. Si se
invoca con ese argumento, el script lo interpreta como un path de output
y crea el directorio `/path/to/--check/.scm/` como efecto colateral,
contaminando el filesystem.

El script fue disenado para generacion (escribe .scm/). La verificacion
de frescura se hace externamente via `scripts/ci-extended-checks.sh`
Check #7, que compara `.scm/INDEX.scm` contra una regeneracion temporal.

**Objetivo:** Anadir flag `--check` al script que:
1. Regenera en un directorio temporal (sin tocar `.scm/` real).
2. Compara el output temporal contra `.scm/` actual.
3. Reporta FRESH o STALE.
4. Retorna exit code 0 (fresh) o 1 (stale).
5. NO crea archivos fuera del directorio temporal.

---

## 2. Requisitos Funcionales

- **REQ-01** `python3 scripts/generate-capability-map.py --check` no
  modifica ningun archivo en `.scm/`.
- **REQ-02** Usa `tempfile.TemporaryDirectory` para el output temporal.
- **REQ-03** Compara INDEX.scm hash (linea `> hash: ...`) entre temporal
  y real. Si coinciden: "SCM: FRESH" + exit 0.
- **REQ-04** Si difieren: "SCM: STALE (hash: TEMP vs REAL)" + exit 1.
- **REQ-05** Si `.scm/INDEX.scm` no existe: "SCM: MISSING" + exit 2.
- **REQ-06** El flag `--check` es mutuamente excluyente con el argumento
  posicional de path de salida.
- **REQ-07** El directorio temporal se limpia automaticamente al terminar
  (exito o error) via `finally` o context manager.

---

## 3. Argumentos

```
python3 scripts/generate-capability-map.py             # Genera .scm/ en repo_root
python3 scripts/generate-capability-map.py --check      # Modo verificacion (read-only)
python3 scripts/generate-capability-map.py /custom/path # Genera en path personalizado
# --check + path posicional es invalido -> error + exit 2
```

---

## 4. Criterios de Aceptacion

- **AC-01** `--check` sobre SCM fresco sale con exit 0 y mensaje "SCM: FRESH".
- **AC-02** `--check` no crea archivos en el repo (verificar con `git status --porcelain`).
- **AC-03** `--check` sobre SCM stale (modificar un comando, no regenerar) sale con exit 1.
- **AC-04** `--check` con `.scm/INDEX.scm` ausente sale con exit 2.
- **AC-05** `--check /custom/path` (ambos a la vez) sale con error y exit 2.
- **AC-06** El directorio temporal NO persiste tras la ejecucion.

---

## 5. Ficheros a Modificar

| Fichero | Accion |
|---------|--------|
| `scripts/generate-capability-map.py` | MODIFICAR: anadir flag `--check` en `main()` |

---

## 6. Test Scenarios

1. **Fresh check**: regenerar SCM. Ejecutar `--check`. Exit 0. Output "SCM: FRESH".
2. **Stale check**: modificar `trace-optimize.md` frontmatter. NO regenerar. `--check` → exit 1.
3. **Missing check**: `mv .scm/INDEX.scm /tmp/`. `--check` → exit 2. Restaurar.
4. **No side effects**: `--check` → `git status --porcelain` vacio. `ls /tmp/opencode/` no tiene directorios residuales del check.
5. **Mutual exclusion**: `--check /tmp/out` → error + exit 2.
