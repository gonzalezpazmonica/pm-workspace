# SE-369 — Contract Digest Pins: versionado inmutable de contratos (hooks, settings, skills)

**Status:** PROPOSED (2026-09-02, para aprobación de la operadora)
**Fecha:** 2026-09-02
**Área:** Contratos / Configuración / Estabilidad
**Fuente de inspiración:** artefactos de contrato byte-congelados bajo digest pin; las versiones previas se cargan en modo compat y nunca recuperan autoridad (análisis release open-source 2026-09-02)
**Criterio humano aplicable:** CRIT-001 (todo local)

---

## 1. Motivación

Savia tiene muchos contratos que evolucionan sin pin de versión: `.claude/
settings.json` (hooks), schemas de skills, formato de veredictos, contratos de
memoria. Cuando un contrato cambia (p.ej. una versión nueva del schema de
receipts), no hay forma de saber si un consumidor antiguo está leyendo una
representación obsoleta, ni de rechazar explícitamente una versión nueva que un
binary/script antiguo no entiende. Resultado: regresiones silenciosas (un
consumidor interpreta mal un campo añadido) o migraciones que rompen lectores
viejos sin aviso.

La lección del modelo de referencia: **los artefactos de contrato quedan
byte-congelados bajo un digest pin**; un artefacto previo se carga en modo
compat (lectura tolerante) pero **nunca recupera autoridad**; un consumidor con
schema antiguo **rechaza una versión nueva con un mensaje que nombra la
actualización**. El runtime ledger tolera campos aditivos solo si los campos
conocidos son byte-idénticos al encoding canónico.

## 2. Alcance

**Dentro:**
- Pin de digest para contratos clave de Savia (settings.json hooks, schemas de
  veredicto/receipt/skill)
- Regla: consumidor con schema antiguo rechaza versión nueva nombrando el upgrade
- Regla: campos aditivos tolerados solo si los conocidos son byte-idénticos
- Catálogo de contratos con su digest actual y versiones previas (compat, sin autoridad)

**Fuera:**
- Migración de TODOS los contratos de golpe (por fases)
- Contratos externos (GitHub Actions, etc.)

## 3. Principios de diseño

1. **Digest pin por contrato**: cada contrato versionado lleva su sha256 canónico
   publicado. Se cambia solo con bump de versión + nuevo pin.
2. **Compat sin autoridad**: un lector antiguo puede leer versiones previas en
   modo compat (tolerante) pero ninguna versión vieja puede volver a ser la
   canónica.
3. **Rechazo explícito**: si un consumidor (script/hook) no conoce el schema,
   no interpreta en silencio — rechaza y dice "requiere upgrade a <versión>".
4. **Aditivo estricto**: una versión nueva puede añadir campos, pero los campos
   existentes deben ser byte-idénticos al encoding canónico (si un campo
   conocido cambia de formato, es breaking y exige bump).
5. **CRIT-001**: todo local, catálogo en el repo.

## 4. Diseño técnico

### 4.1 Catálogo `config/contract-digests.json`

```json
{
  "settings-hooks": {
    "current": {"version": 7, "digest": "sha256:abc...", "path": ".claude/settings.json"},
    "previous": [
      {"version": 6, "digest": "sha256:def...", "compat": true, "authoritative": false},
      {"version": 5, "digest": "sha256:ghi...", "compat": true, "authoritative": false}
    ]
  },
  "receipt-schema": {
    "current": {"version": 2, "digest": "sha256:jkl...", "path": "schema/audit/receipt.yaml"}
  }
}
```

### 4.2 `scripts/contract-pin.sh` (gestión + chequeo)

- `pin <name> --path <file>`: calcula digest, registra como current (bump).
- `check <name>`: verifica que el digest actual del fichero == pin canónico;
  si cambió sin bump → FAIL.
- `compat <name> --version <v>`: lista las versiones previas compatibles.
- `--validate`: el catálogo es consistente (un solo current por contrato, las
  previas tienen compat y no son authoritative).

### 4.3 Regla de consumo (para hooks/scripts que lean contratos)

- Antes de interpretar un contrato, `contract-pin.sh check` confirma digest.
- Si el schema del consumidor es anterior al current → rechaza con mensaje
  "requiere upgrade a <versión>" (no interpreta campos nuevos a ciegas).
- Los campos aditivos solo se aceptan si los conocidos son byte-idénticos.

## 5. Criterios de aceptación

- **AC-0** `pin` registra digest canónico y `check` pasa (test)
- **AC-1** `check` falla si el fichero cambió sin bump (test)
- **AC-2** Consumidor con schema antiguo rechaza versión nueva nombrando el
  upgrade (test)
- **AC-3** Campo aditivo aceptado solo si los conocidos son byte-idénticos (test)
- **AC-4** Versión previa se carga en compat pero nunca recupera autoridad (test)
- **AC-5** Catálogo `--validate` consistente (test)
- **AC-6** Piloto: settings.json hooks pineado; sin regresión en hooks existentes

## 6. OpenCode Implementation Plan

### Bindings touched
- `config/contract-digests.json` (nuevo)
- `scripts/contract-pin.sh` (nuevo)
- Hooks/scripts que lean contratos (chequeo digest; rechazo explícito)
- `.claude/settings.json` (piloto)

### Verification protocol
```bash
bats tests/bats/test-contract-pin.bats
bash scripts/contract-pin.sh pin settings-hooks --path .claude/settings.json
bash scripts/contract-pin.sh check settings-hooks
bash scripts/contract-pin.sh compat settings-hooks --version 6
```

### Portability classification
- Bash + sha256sum + JSON; local; portable; CRIT-001

## Referencias
- Digest pins + compat sin autoridad + rechazo explícito de schema nuevo
  (concepto, análisis 2026-09-02)
- Savia: SE-363 (records-not-files), SE-355 (audit receipts), hooks settings.json,
  CRIT-001
