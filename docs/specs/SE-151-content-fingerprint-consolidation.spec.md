# SE-151 — Content Fingerprint Consolidation (Bioquimica frontmatter pilot)

**Status:** PROPOSED
**Fecha:** 2026-06-19
**Area:** Code consolidation / DRY / Frontmatter expressiveness
**Branch:** agent/biochem-context-20260619

---

## Origen

CLAUDE.md Rule #6: repetition 2+ debe consolidarse en skill. Auditoria
detecta 41 ficheros con sha256/sha1/md5 de los cuales 4 implementan
explicitamente el patron "short content fingerprint" (sha256 + cut -c1-N)
y 21 usan el patron "full content hash" con awk pipe. Cuatro mas
implementan cache_key derivation con codigo divergente.

Sesion previa (brainless-patterns, 2026-06-18) intento aplicar patrones
biologicos sin spec ni baseline y fue archivada como DO NOT MERGE.
Lecciones aplicadas: spec primero, dataset etiquetado, baseline real,
sin biomimetic theater en codigo, frontmatter solo en doc piloto.

Investigacion bioquimica complementa pero no dirige el diseño:
- Hebert 2003 DNA barcoding (doi:10.1098/rspb.2002.2218)
- Dasgupta-Stevens-Navlakha 2017 (doi:10.1126/science.aam9868)

El paper Dasgupta documenta LSH biologico (Drosophila olfactory tag) que
mejora nearest-neighbor sobre LSH clasico. Pero su aplicacion requiere
vectorizacion previa (MiniLM ya existe en memory-vector.py). Esta spec
NO implementa Dasgupta directamente; consolida el sustrato de hashing
sobre el cual una iteracion futura podria construirlo.

## Objetivo (scope-down agresivo tras adversarial pre-flight)

Consolidar las 4 implementaciones convergentes de "short content
fingerprint" en una skill `content-fingerprint` invocable desde bash y
python. NO tocar los 21 callers de full-hash (riesgo migracion alto, ROI
bajo). NO computar frontmatter de 6670 docs. NO usar nombres biologicos
en codigo de produccion. Si vocabulario bioquimica vive en frontmatter
de la propia skill SKILL.md como demostracion del patron solicitado.

## Out of scope explicito

- NO frontmatter computado en docs versionados (drift garantizado).
- NO migracion masiva de los 41 callers (solo los 4 short-fingerprint).
- NO Dasgupta-LSH; queda como roadmap futuro condicionado.
- NO `crispr_validated` ni equivalentes (campo derivable, no almacenable).
- NO sustituir HNSW; este patron complementa, no compite.

## Acceptance criteria (pre-comprometidos, falsifiables)

AC-1. Function `content_fingerprint(input, len)` en `scripts/content-fingerprint.sh`
      con tests bats que verifican:
      - len in {8, 16, 32, 64} produce hex de longitud exacta
      - input identico produce salida identica (determinismo)
      - input que difiere por 1 byte produce salida totalmente distinta
      - acepta stdin y argumentos
      - exit code 0 en exito, 2 en input invalido

AC-2. Skill `.opencode/skills/content-fingerprint/SKILL.md` con frontmatter
      que incluye seccion `bioquimica:` declarativa (no computada):
      ```
      bioquimica:
        inspiracion: "DNA barcoding (Hebert 2003), Drosophila LSH (Dasgupta 2017)"
        analogo_biologico: "fragmento canonico discriminativo"
        propiedad_aplicada: "fingerprint determinista corto invariante"
        no_aplicado_aun: ["Dasgupta sparse expansion", "winner-take-all"]
      ```
      Esta seccion documenta inspiracion sin pretender que el codigo la
      implementa. Es honesta. La skill misma es el unico lugar donde
      vocabulario biologico aparece.

AC-3. Migrar los 4 callers identificados (`ado-bridge.sh:cache_key`,
      `failure-pattern-memory.sh`, `semantic-map.sh`, `test-auditor.sh`)
      a usar la nueva funcion. Tests existentes de cada caller deben
      seguir verdes.

AC-4. Dataset etiquetado de near-duplicates en `tests/fixtures/fingerprint/`:
      - 5 pares de docs identicos (true positive duplicates)
      - 5 pares de docs near-duplicates (1 char de diferencia)
      - 5 pares de docs distintos (true negatives)
      Test bats verifica:
      - precision = 1.0 sobre identicos (mismo fingerprint)
      - recall sobre near-dups: 0.0 esperado (1 char cambia hash entero)
      - precision sobre distintos: 1.0 (diferentes hashes)

AC-5. Latencia: fingerprint de fichero <1KB debe completarse en <50ms p95
      en hardware de referencia (`time` sobre 100 invocaciones).

AC-6. Sin write a frontmatter de docs existentes. Si fingerprint se
      necesita por caller, se computa on-demand.

## Verification method

```bash
bats tests/skills/content-fingerprint.bats
bats tests/scripts/content-fingerprint.bats
bash scripts/content-fingerprint.sh --self-test
```

Resultado esperado: todos verdes. Si rojo, spec no esta cumplida.

## Diseño tecnico (minimo)

```bash
# scripts/content-fingerprint.sh
content_fingerprint() {
  local len="${1:-16}"
  case "$len" in
    8|16|32|64) ;;
    *) echo "ERROR: len must be 8/16/32/64" >&2; return 2 ;;
  esac
  if [[ -t 0 ]]; then
    echo "ERROR: input via stdin required" >&2; return 2
  fi
  sha256sum | awk -v n="$len" '{print substr($1, 1, n)}'
}
```

Sin estado. Sin flock necesario (sin estado mutable). Sin red. Sin LLM.

## Riesgos identificados pre-flight

R1. Migracion rompe callers existentes — mitigacion: tests bats de cada
    caller antes de cambio.
R2. Frontmatter biologico parece ceremonial — mitigacion: solo en SKILL.md
    de la propia skill, no en otros docs. Documenta inspiracion.
R3. Repeticion del patron brainless-patterns — mitigacion: spec ANTES de
    codigo, dataset etiquetado pre-comprometido, baseline = sha256sum
    directo (la skill solo ahorra duplicacion, no inventa metrica).

## Decision de adopcion (criterios revisados tras adversarial review)

HISTORIA: La spec original incluia "Reduccion neta de LOC en los 4 callers
migrados (DRY medible)" como criterio MERGE. Adversarial post-impl review
senalo que ese criterio NO se cumple (LOC neta repo: +446; LOC en los 4
callers: identica, +2). El criterio era ingenuo: cualquier consolidacion
que anade spec+tests+SKILL.md aumenta LOC sin reducir duplicacion de
produccion equivalente.

CRITERIO REVISADO (honesto, falsifiable):

MERGE si TODOS:
- AC-1 verde (14 tests bats sobre funcion pura)
- AC-3 verde con evidencia ejecutable (tests bats de los callers migrados,
  no afirmacion textual)
- AC-4 verde (dataset etiquetado de 30 fixtures, 15 pares)
- AC-5 verde (latencia <5s sobre 100 invocaciones)
- Equivalencia byte-a-byte verificada vs codigo pre-SE-151 sobre los 2
  callers migrados (regression-free hash output)
- SKILLS.md regenerado y skill descubrible
- Adversarial post-impl review sin findings CRITICAL no resueltos

DO NOT MERGE si:
- Algun test bats rojo
- Output de un caller migrado difiere del baseline pre-SE-151
- Skill no aparece en SKILLS.md
- Adversarial review encuentra CRITICAL sin fix aplicado

Lo que el criterio NO dice (y es honesto):
- NO promete reducir LOC. La skill aumenta superficie del repo.
- NO migra los 4 callers candidatos. Solo los 2 sin fallback. Los otros 2
  (ado-bridge.sh:36 y semantic-map.sh:78-87) tienen fallback cksum/shasum/
  nohash00 que aporta robustez a entornos sin sha256sum; migrarlos a la
  skill perderia ese fallback. Decision: no migrar.
- El valor real es: tests donde no habia, spec ejecutable, descubribilidad
  via SKILLS.md, frontmatter bioquimica declarativa demostrando el patron
  solicitado por el usuario.

## Referencias

- Hebert et al. 2003 doi:10.1098/rspb.2002.2218 (DNA barcoding)
- Dasgupta-Stevens-Navlakha 2017 doi:10.1126/science.aam9868 (Drosophila LSH)
- Charikar 2002 (SimHash, LSH baseline classico)
- Broder 1997 (MinHash)
- experiments/brainless/RESEARCH-LOG.md (lecciones sesion previa)
- CLAUDE.md Rule #6 (repetition 2+ → skill)
- CLAUDE.md Rule #8 (no merge sin spec)
- docs/rules/domain/autonomous-safety.md
- docs/rules/domain/radical-honesty.md (no biomimetic theater)
