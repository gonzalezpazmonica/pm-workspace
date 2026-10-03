#!/usr/bin/env bats
# SE-376 — social-linkedin: import, digest y status contra exportaciones sintéticas con el
# formato de la exportación oficial (personas inventadas). Nunca toca ~/.savia/social/linkedin
# real: SOCIAL_STORE redirige el almacén a un directorio temporal.
# Ref: .claude/skills/social-linkedin/SKILL.md, docs/propuestas/ SE-385.
set -uo pipefail

bats_require_minimum_version 1.5.0
SCRIPT="scripts/social-linkedin-import.py"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  IMPORT="$REPO_ROOT/$SCRIPT"
  DIGEST="$REPO_ROOT/scripts/social-linkedin-digest.py"
  STATUS="$REPO_ROOT/scripts/social-linkedin-status.py"
  TMP="$(mktemp -d -p "$BATS_TEST_TMPDIR")"
  export SOCIAL_STORE="$TMP/store"
  # HOME falso: si algún script ignora SOCIAL_STORE, escribe aquí y el test lo detecta.
  export HOME="$TMP/home"
  mkdir -p "$HOME"
  ART="$SOCIAL_STORE/normalized/artifacts.jsonl"
}

teardown() { rm -rf "$TMP"; }

# mkzip <zip> <nombre-en-zip> <contenido> [<nombre> <contenido>]...
mkzip() {
  python3 - "$@" <<'PY'
import sys, zipfile
out, rest = sys.argv[1], sys.argv[2:]
with zipfile.ZipFile(out, "w") as z:
    for name, body in zip(rest[0::2], rest[1::2]):
        z.writestr(name, body.encode("utf-8"))
PY
}

shares_csv() {
  printf 'Date,ShareLink,ShareCommentary,SharedUrl,MediaUrl,Visibility\n'
  printf '2024-05-01 10:00:00,https://www.linkedin.com/feed/update/urn:li:activity:1,"Soberania cognitiva, agentes y criterio: el humano decide",,,MEMBER_NETWORK\n'
  printf '2024-06-01 09:30:00,https://www.linkedin.com/feed/update/urn:li:activity:2,"SDD con especificaciones ejecutables para agentes",,,MEMBER_NETWORK\n'
}

count() { [ -f "$ART" ] && grep -c . "$ART" || echo 0; }

@test "safety: los tres scripts compilan y el test aísla HOME (set -uo pipefail en el test)" {
  python3 -m py_compile "$IMPORT" "$DIGEST" "$STATUS"
  grep -q "set -uo pipefail" "$BATS_TEST_FILENAME"
}

@test "import: Shares.csv real (nombre plural) crea artefactos con provenance untrusted" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 2 ]
  python3 - "$ART" <<'PY'
import json, sys
for l in open(sys.argv[1]):
    a = json.loads(l)
    assert a["origin"]["trust"] == "untrusted" and a["origin"]["acquisition"] == "manual_export", a
    assert a["artifact_type"] == "post" and a["authored"] == "SELF_AUTHORED", a
    assert a["created_at"].startswith("2024-"), a
PY
}

@test "import: Shares_<idmiembro>.csv de la exportación completa también se reconoce" {
  mkzip "$TMP/e.zip" "Shares_506219023.csv" "$(shares_csv)"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 2 ]
}

@test "import: el nombre legado Share.csv sigue funcionando" {
  mkzip "$TMP/e.zip" "LinkedInExport/Share.csv" "$(shares_csv)"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 2 ]
}

@test "import: Comments.csv real (columna Message, comillas con barra invertida) importa el texto entero" {
  body=$'Date,Link,Message\n2024-07-02 08:00:00,https://www.linkedin.com/feed/update/urn:li:activity:9,"Totalmente de acuerdo con \\"el humano decide\\", Ana Ficticia"\n'
  mkzip "$TMP/e.zip" "Comments.csv" "$body"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 1 ]
  python3 - "$ART" <<'PY'
import json, sys
a = json.loads(open(sys.argv[1]).readline())
assert a["artifact_type"] == "comment" and a["authored"] == "MIXED", a
assert a["text"] == 'Totalmente de acuerdo con "el humano decide", Ana Ficticia', repr(a["text"])
assert a["created_at"] == "2024-07-02 08:00:00", a
PY
}

@test "import: CSV con BOM, comas, comillas dobles, unicode y saltos de línea en un campo" {
  body=$'\xef\xbb\xbfDate,ShareLink,ShareCommentary,Visibility\r\n2024-08-01,https://www.linkedin.com/feed/update/urn:li:activity:3,"Línea uno, con coma\r\nLínea dos con ""comillas"" y ñandú 🦉",PUBLIC\r\n'
  mkzip "$TMP/e.zip" "Shares.csv" "$body"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 1 ]
  python3 - "$ART" <<'PY'
import json, sys
a = json.loads(open(sys.argv[1]).readline())
assert a["created_at"] == "2024-08-01", "BOM rompe la cabecera Date: %r" % a["created_at"]
assert a["visibility"] == "PUBLIC", a
assert a["text"] == 'Línea uno, con coma\nLínea dos con "comillas" y ñandú 🦉', repr(a["text"])
PY
}

@test "import: re-importar el mismo ZIP es idempotente (0 creados, N duplicados)" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 creados, 2 duplicados"* ]]
  [ "$(count)" -eq 2 ]
  [ "$(ls "$SOCIAL_STORE/raw" | wc -l)" -eq 1 ]
}

@test "import: manifest y recibo son JSON válidos con los contadores del import" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  python3 - "$SOCIAL_STORE" <<'PY'
import glob, json, os, sys
s = sys.argv[1]
m = json.load(open(os.path.join(s, "manifest.json")))
assert m["provider"] == "linkedin" and m["exports"][-1]["created"] == 2, m
r = json.load(open(glob.glob(os.path.join(s, "receipts", "import-*.json"))[0]))
assert r["result"] == "success" and r["created"] == 2 and r["skipped_duplicates"] == 0, r
PY
}

@test "import: SOCIAL_STORE redirige el almacén y no se escribe nada en HOME" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  [ -f "$ART" ]
  [ ! -e "$HOME/.savia" ]
}

@test "import: PII de terceros — el almacén y la copia raw quedan solo para la propietaria (0700/0600)" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)" "Connections.csv" $'First Name,Last Name,Email Address\nAna,Ficticia,ana@example.invalid\n'
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  [ "$(stat -c %a "$SOCIAL_STORE")" = "700" ]
  [ "$(stat -c %a "$SOCIAL_STORE"/raw/export-*.zip)" = "600" ]
  # Contactos y mensajes no se normalizan: no aparecen en artifacts.jsonl
  ! grep -q "Ficticia" "$ART"
}

@test "import: rechaza (exit 2) un almacén dentro de un repositorio git para no versionar PII" {
  git init -q "$TMP/repo"
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  run python3 "$IMPORT" --zip "$TMP/e.zip" --store "$TMP/repo/output/linkedin"
  [ "$status" -eq 2 ]
  [[ "$output" == *"repositorio git"* ]]
  [ ! -e "$TMP/repo/output" ]
}

@test "import: ZIP con ruta maliciosa (zip-slip ../) no escribe fuera del almacén" {
  mkzip "$TMP/e.zip" "../../evil/Shares.csv" "$(shares_csv)" "../../evil.sh" "echo pwned"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ ! -e "$TMP/evil.sh" ] && [ ! -e "$TMP/evil" ] && [ ! -e "$BATS_TEST_TMPDIR/evil.sh" ]
  [ "$(count)" -eq 2 ]
}

@test "import: fichero que no es ZIP falla (exit 1) sin dejar copia raw ni traceback" {
  printf 'no soy un zip' > "$TMP/bad.zip"
  run python3 "$IMPORT" --zip "$TMP/bad.zip"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" != *"Traceback"* ]]
  [ ! -e "$SOCIAL_STORE/raw" ] || [ -z "$(ls -A "$SOCIAL_STORE/raw")" ]
}

@test "import: ZIP inexistente falla con exit 1 y el error va a stderr" {
  run --separate-stderr python3 "$IMPORT" --zip "$TMP/no-existe.zip"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"ERROR"* ]]
}

@test "import: sin --zip es un error de uso (exit 2)" {
  run python3 "$IMPORT"
  [ "$status" -eq 2 ]
}

@test "import: ZIP vacío (zero CSV reconocidos) termina en 0 con 0 creados" {
  mkzip "$TMP/e.zip" "README.txt" "nada"
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 creados"* ]]
}

@test "import: manifest corrupto se aparta con aviso en stderr en vez de perderse en silencio" {
  mkdir -p "$SOCIAL_STORE"
  printf '{roto' > "$SOCIAL_STORE/manifest.json"
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  run --separate-stderr python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"manifest"* ]]
  ls "$SOCIAL_STORE"/manifest.json.corrupt-* >/dev/null
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SOCIAL_STORE/manifest.json"
}

@test "import: campo de texto grande (boundary >128 KiB) no aborta el import" {
  python3 - "$TMP/e.zip" <<'PY2'
import sys, zipfile
big = "palabra " * 20000
csv = 'Date,ShareLink,ShareCommentary\n2024-01-01,https://www.linkedin.com/feed/update/urn:li:activity:7,"%s"\n' % big
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("Shares.csv", csv)
PY2
  run python3 "$IMPORT" --zip "$TMP/e.zip"
  [ "$status" -eq 0 ]
  [ "$(count)" -eq 1 ]
}

@test "digest: extracto con | y saltos de línea no rompe la tabla de savia-history" {
  body=$'Date,ShareLink,ShareCommentary\n2024-08-01,https://www.linkedin.com/feed/update/urn:li:activity:4,"Savia | agentes\nsegunda línea"\n'
  mkzip "$TMP/e.zip" "Shares.csv" "$body"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  run python3 "$DIGEST"
  [ "$status" -eq 0 ]
  H="$SOCIAL_STORE/derived/savia-history.md"
  row="$(grep '^| 2024-08-01' "$H")"
  [ -n "$row" ]
  # La fila es una sola línea completa: termina en " |" y tiene 5 separadores sin escapar
  [[ "$row" == *" |" ]]
  [ "$(printf '%s' "$row" | sed 's/\\|//g' | tr -cd '|' | wc -c)" -eq 5 ]
  ! grep -q '^segunda' "$H"
}

@test "digest: almacén vacío (empty) genera los tres derivados sin fallar" {
  run python3 "$DIGEST"
  [ "$status" -eq 0 ]
  for f in themes savia-history writing-style; do [ -f "$SOCIAL_STORE/derived/$f.md" ]; done
  grep -q "corpus_posts: 0" "$SOCIAL_STORE/derived/writing-style.md"
  grep -q "HISTORICAL" "$SOCIAL_STORE/derived/savia-history.md"
}

@test "digest: líneas JSONL inválidas o sin campos (null) se ignoran sin traceback" {
  mkdir -p "$SOCIAL_STORE/normalized"
  printf '[]\n{"text":"sin tipo"}\nno-json\n{"artifact_type":"post","text":null}\n' > "$ART"
  run python3 "$DIGEST"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Traceback"* ]]
}

@test "digest: writing-style solo usa SELF_AUTHORED (los comentarios MIXED no cuentan)" {
  body=$'Date,Link,Message\n2024-07-02,https://www.linkedin.com/feed/update/urn:li:activity:9,"Comentario largo sobre otro autor que no es mio en absoluto"\n'
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)" "Comments.csv" "$body"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  python3 "$DIGEST" >/dev/null
  grep -q "corpus_posts: 2" "$SOCIAL_STORE/derived/writing-style.md"
}

@test "status: lee SOCIAL_STORE y cuenta los artefactos importados" {
  mkzip "$TMP/e.zip" "Shares.csv" "$(shares_csv)"
  python3 "$IMPORT" --zip "$TMP/e.zip" >/dev/null
  run python3 "$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Local artifacts: 2"* ]]
  [[ "$output" == *"publish_post: NOT_GRANTED"* ]]
  [[ "$output" != *"Last sync: nunca"* ]]
}

@test "status: almacén inexistente (zero artefactos) informa 'nunca' y exit 0" {
  run python3 "$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Local artifacts: 0"* ]]
  [[ "$output" == *"Last sync: nunca"* ]]
}

@test "status: manifest corrupto avisa en stderr (invalid) sin fallar" {
  mkdir -p "$SOCIAL_STORE"
  printf '{roto' > "$SOCIAL_STORE/manifest.json"
  run --separate-stderr python3 "$STATUS"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"manifest"* ]]
}
