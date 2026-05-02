# Spec: OpenCode Agent Directory Sync — Replicar decision-trees/ a .opencode/agents/

**Task ID:**        SPEC-OPC-AGENTSYNC
**PBI padre:**      Era 189 — OpenCode Sovereignty (SE-077)
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (auditoria OpenCode alignment)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimacion:**     S 2h
**Estado:**         Pendiente
**Prioridad:**      ALTA
**Modelo:**         claude-sonnet-4-6
**Max turns:**      10

---

## 1. Contexto y Objetivo

Auditoria de alineacion `.opencode/` vs `.claude/` revelo que el directorio
`decision-trees/` (que contiene `commit-guardian-decisions.md`, el log de
decisiones del agente commit-guardian) existe en `.claude/agents/` pero NO
fue replicado a `.opencode/agents/` durante la migracion OpenCode (Era 189).

`.opencode/agents/` tiene 70 .md files. `.claude/agents/` tiene 70 .md files
+ 1 directorio `decision-trees/`. Sin este directorio, los logs de decision
acumulados no estan disponibles cuando commit-guardian opera bajo OpenCode.

**Objetivo:** Replicar el directorio `decision-trees/` a `.opencode/agents/`
y extender `scripts/agents-opencode-convert.sh` para que sincronice tambien
subdirectorios (no solo *.md files).

**Principio SDD:** Este spec define QUE debe existir tras la implementacion:
directorio sincronizado + script de conversion actualizado para cubrir
subdirectorios.

---

## 2. Requisitos Funcionales

- **REQ-01** Directorio `.opencode/agents/decision-trees/` debe existir con
  contenido identico a `.claude/agents/decision-trees/`.
- **REQ-02** `scripts/agents-opencode-convert.sh` debe sincronizar
  subdirectorios de agentes (no solo `*.md`), usando `rsync -a` o `cp -r`.
- **REQ-03** El script no debe sobrescribir archivos con contenido identico
  (solo actualizar si hay drift).
- **REQ-04** El script debe reportar que directorios/archivos fueron
  sincronizados (para visibilidad en ejecucion).

---

## 3. Criterios de Aceptacion

- **AC-01** `diff -r .claude/agents/decision-trees .opencode/agents/decision-trees` no muestra diferencias.
- **AC-02** `bash scripts/agents-opencode-convert.sh` completa sin error y reporta "decision-trees: OK" o "decision-trees: sync".
- **AC-03** Tras modificar un archivo en `.claude/agents/decision-trees/`, re-ejecutar el script lo replica a `.opencode/`.
- **AC-04** El directorio decision-trees/ no interfiere con la generacion de SCM (no debe aparecer como agente en INDEX.scm).

---

## 4. Ficheros a Modificar

| Fichero | Accion |
|---------|--------|
| `scripts/agents-opencode-convert.sh` | MODIFICAR: extender para subdirectorios |
| `.opencode/agents/decision-trees/` | CREAR: copia desde `.claude/agents/decision-trees/` |

---

## 5. Test Scenarios

1. **Sync inicial**: ejecutar script con `.opencode/agents/decision-trees/` ausente. Verificar que se crea.
2. **Sync idempotente**: ejecutar script 2 veces consecutivas. Segunda ejecucion reporta "OK" sin cambios.
3. **Sync tras drift**: modificar `commit-guardian-decisions.md` en `.claude/agents/decision-trees/`. Ejecutar. Verificar replica.
4. **SCM isolation**: ejecutar `generate-capability-map.py`. Verificar que decision-trees NO aparece en INDEX.scm.
