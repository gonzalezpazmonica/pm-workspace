#!/usr/bin/env bats
# SE-376 — devops-validation: validate-devops.sh audita un proyecto de Azure DevOps
# sin contactar servicios reales. curl es un stub en el PATH que sirve fixtures por URL,
# registra sus argumentos (para detectar el PAT en la línea de órdenes) y exige la
# cabecera Authorization exacta. El PAT es ficticio y vive en un directorio temporal.
# Ref: .claude/skills/devops-validation/SKILL.md · .claude/commands/devops-validate.md
set -uo pipefail
bats_require_minimum_version 1.5.0

SCRIPT="scripts/validate-devops.sh"

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMPDIR="$(mktemp -d)"
  FIX="$TMPDIR/fix"; BIN="$TMPDIR/bin"
  mkdir -p "$FIX" "$BIN"
  export STUB_FIX="$FIX" STUB_ARGV="$TMPDIR/curl-argv.log" STUB_STDIN="$TMPDIR/curl-stdin.log"
  : > "$STUB_ARGV"; : > "$STUB_STDIN"
  PAT="fakepat0123456789abcdefghijklmnopqrstuvwxyz0123"
  write_pat "$PAT"
  export AZURE_DEVOPS_ORG_URL="https://dev.azure.com/acme-test"
  export AZURE_DEVOPS_PAT_FILE="$TMPDIR/devops-pat"
  write_stub_curl
  export PATH="$BIN:$PATH"
  agile_fixtures
}

teardown() { rm -rf "$TMPDIR"; }

write_pat() {
  printf '%s\n' "$1" > "$TMPDIR/devops-pat"
  export STUB_EXPECT_AUTH="Basic $(printf ':%s' "$1" | base64 -w0)"
}

# Stub de curl: -s -S -f -o -w -H -K/--config -, URL. Sin red: STUB_NET=down (exit 7).
write_stub_curl() {
  cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s ' "$@" >> "$STUB_ARGV"; printf '\n' >> "$STUB_ARGV"
out="" fmt="" fail=0 url="" auth=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -w) fmt="$2"; shift 2 ;;
    -H) [[ "$2" == Authorization:* ]] && auth="${2#Authorization: }"; shift 2 ;;
    -K|--config)
      if [ "$2" = "-" ]; then
        cfg="$(cat)"; printf '%s\n' "$cfg" >> "$STUB_STDIN"
        line="$(grep -m1 '^header = "Authorization: ' <<<"$cfg")"
        [ -n "$line" ] && { auth="${line#header = \"Authorization: }"; auth="${auth%\"}"; }
      fi
      shift 2 ;;
    -*) [[ "$1" =~ ^-[a-zA-Z]*f ]] && fail=1; shift ;;
    *) url="$1"; shift ;;
  esac
done
emit_code() { [ -n "$fmt" ] && printf '%s' "${fmt//%\{http_code\}/$1}"; }
if [[ "$url" == *" "* ]]; then emit_code 000; exit 3; fi
if [ "${STUB_NET:-up}" = "down" ]; then emit_code 000; exit 7; fi
case "$url" in
  */_apis/projects\?*) key=connectivity ;;
  */_apis/projects/*/properties\?*) key=properties ;;
  */_apis/projects/*) key=project ;;
  */_apis/process/processes\?*) key=processes ;;
  */_apis/wit/workitemtypes\?*) key=types ;;
  */_apis/wit/workitemtypes/*) n="${url##*/workitemtypes/}"; n="${n%%\?*}"; key="wit-${n//%20/_}" ;;
  */_apis/work/backlogconfiguration\?*) key=backlog ;;
  */_apis/work/teamsettings/iterations\?*) key=iterations ;;
  *) key=unknown ;;
esac
printf '%s\n' "$url" >> "$STUB_FIX/urls.log"
code=200; [ -f "$STUB_FIX/$key.code" ] && code="$(cat "$STUB_FIX/$key.code")"
[ "$auth" = "$STUB_EXPECT_AUTH" ] || code=401
body="$STUB_FIX/$key.json"; [ -f "$body" ] || { body=/dev/null; [ "$code" = 200 ] && code=404; }
if [ "$code" -ge 400 ] && [ "$fail" = 1 ]; then emit_code "$code"; exit 22; fi
if [ -n "$out" ]; then cat "$body" > "$out"; else cat "$body"; fi
emit_code "$code"
exit 0
STUB
  chmod +x "$BIN/curl"
}

fx() { printf '%s\n' "$2" > "$FIX/$1.json"; }

agile_fixtures() {
  fx connectivity '{"count":1,"value":[{"name":"Acme"}]}'
  fx project '{"id":"p-0001","name":"Acme"}'
  fx properties '{"value":[{"name":"System.ProcessTemplateType","value":"t-agile"}]}'
  fx processes '{"value":[{"typeId":"t-agile","name":"Agile","parentProcessTypeId":null},{"typeId":"t-basic","name":"Basic"},{"typeId":"t-scrum","name":"Scrum"}]}'
  fx types '{"value":[{"name":"Epic"},{"name":"Feature"},{"name":"User Story"},{"name":"Task"},{"name":"Bug"}]}'
  fx wit-User_Story '{"states":[{"name":"New"},{"name":"Active"},{"name":"Resolved"},{"name":"Closed"}],"fields":[{"referenceName":"Microsoft.VSTS.Scheduling.StoryPoints"},{"referenceName":"Microsoft.VSTS.Common.Priority"}]}'
  fx wit-Task '{"states":[{"name":"New"},{"name":"Active"},{"name":"Closed"}],"fields":[{"referenceName":"Microsoft.VSTS.Scheduling.OriginalEstimate"},{"referenceName":"Microsoft.VSTS.Scheduling.RemainingWork"},{"referenceName":"Microsoft.VSTS.Scheduling.CompletedWork"},{"referenceName":"Microsoft.VSTS.Common.Priority"},{"referenceName":"Microsoft.VSTS.Common.Activity"}]}'
  fx wit-Bug '{"states":[{"name":"New"},{"name":"Active"},{"name":"Resolved"},{"name":"Closed"}],"fields":[{"referenceName":"Microsoft.VSTS.Scheduling.StoryPoints"},{"referenceName":"Microsoft.VSTS.Common.Priority"},{"referenceName":"Microsoft.VSTS.Common.Severity"}]}'
  fx backlog '{"bugsBehavior":"asRequirements","requirementBacklog":{"workItemTypes":[{"name":"User Story"}]}}'
  fx iterations '{"value":[{"name":"Sprint 1","attributes":{"startDate":"2026-09-21T00:00:00Z","finishDate":"2026-10-02T00:00:00Z"}}]}'
}

validate() { run --separate-stderr bash "$REPO_ROOT/$SCRIPT" "$@"; }
status_of() { jq -r --arg c "$1" '.checks[] | select(.check==$c) | .status' <<<"$output"; }

@test "safety: el script existe y declara set -uo pipefail" {
  [ -f "$REPO_ROOT/$SCRIPT" ]
  grep -qE '^set -e?uo pipefail' "$REPO_ROOT/$SCRIPT"
}

@test "positivo: proyecto Agile completo da 8 PASS, JSON válido y exit 0" {
  validate --project "Acme"
  [ "$status" -eq 0 ]
  jq -e . <<<"$output" >/dev/null
  [ "$(jq -r '.summary | "\(.total) \(.pass) \(.warn) \(.fail)"' <<<"$output")" = "8 8 0 0" ]
  [ "$(jq -r '[.checks[].check] | join(",")' <<<"$output")" = "connectivity,project,process,types,states,fields,backlog,iterations" ]
}

@test "límite: el equipo por defecto con espacio ('Acme Team') se codifica en la URL" {
  validate --project "Acme"
  [ "$(status_of backlog)" = "PASS" ]
  [ "$(status_of iterations)" = "PASS" ]
  grep -q '/Acme/Acme%20Team/_apis/work/backlogconfiguration' "$FIX/urls.log"
}

@test "límite: proyecto con espacio en el nombre se codifica en todas las URLs" {
  validate --project "Acme Web" --team "Core"
  [ "$status" -eq 0 ]
  ! grep -q ' ' "$FIX/urls.log"
  grep -q '/_apis/projects/Acme%20Web?' "$FIX/urls.log"
}

@test "seguridad: el PAT ni su base64 aparecen en los argumentos de curl" {
  validate --project "Acme"
  [ "$status" -eq 0 ]
  [ -s "$STUB_ARGV" ]
  ! grep -qF "$PAT" "$STUB_ARGV"
  ! grep -qF "${STUB_EXPECT_AUTH#Basic }" "$STUB_ARGV"
  ! grep -q 'Authorization' "$STUB_ARGV"
}

@test "seguridad: el PAT no aparece en stdout, stderr ni en el informe --output" {
  validate --project "Acme" --output "$TMPDIR/out/report.json"
  ! grep -qF "$PAT" <<<"$output$stderr"
  ! grep -qF "$PAT" "$TMPDIR/out/report.json"
}

@test "límite: PAT largo de 84 caracteres no rompe la cabecera (sin saltos de base64)" {
  write_pat "$(printf 'k%.0s' $(seq 1 84))"
  validate --project "Acme"
  [ "$status" -eq 0 ]
  [ "$(status_of connectivity)" = "PASS" ]
}

@test "negativo: sin fichero PAT aborta con exit 2, sin JSON y sin llamar a curl" {
  export AZURE_DEVOPS_PAT_FILE="$TMPDIR/no-existe"
  validate --project "Acme"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"PAT file not found"* ]]
  [ ! -s "$STUB_ARGV" ]
}

@test "negativo: org URL con el placeholder por defecto se rechaza sin enviar el PAT" {
  unset AZURE_DEVOPS_ORG_URL
  validate --project "Acme"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"AZURE_DEVOPS_ORG_URL"* ]]
  [ ! -s "$STUB_ARGV" ]
}

@test "negativo: PAT vacío (empty) se rechaza con exit 2" {
  : > "$TMPDIR/devops-pat"
  validate --project "Acme"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"empty"* ]]
  [ ! -s "$STUB_ARGV" ]
}

@test "negativo: sin red ningún check da PASS ni WARN (fail-closed) y exit 1" {
  export STUB_NET=down
  validate --project "Acme"
  [ "$status" -eq 1 ]
  jq -e . <<<"$output" >/dev/null
  [ "$(jq -r '.summary | "\(.total) \(.fail)"' <<<"$output")" = "8 8" ]
}

@test "negativo: PAT rechazado (HTTP 401) falla todos los checks con el código en el mensaje" {
  export STUB_EXPECT_AUTH="Basic otro"
  validate --project "Acme"
  [ "$status" -eq 1 ]
  [ "$(jq -r '.summary.fail' <<<"$output")" = "8" ]
  [[ "$(jq -r '.checks[] | select(.check=="backlog") | .message' <<<"$output")" == *"401"* ]]
}

@test "negativo: proyecto inexistente (404) da FAIL en project" {
  printf '404' > "$FIX/project.code"
  validate --project "Acme"
  [ "$status" -eq 1 ]
  [ "$(status_of project)" = "FAIL" ]
  [[ "$(jq -r '.checks[] | select(.check=="project") | .message' <<<"$output")" == *"not found"* ]]
}

@test "negativo: respuesta no JSON (HTML con 200) es FAIL invalid response, nunca PASS/WARN" {
  printf '<html>sign in</html>\n' > "$FIX/backlog.json"
  printf '<html>sign in</html>\n' > "$FIX/iterations.json"
  validate --project "Acme"
  [ "$status" -eq 1 ]
  jq -e . <<<"$output" >/dev/null
  [ "$(status_of backlog)" = "FAIL" ]
  [ "$(status_of iterations)" = "FAIL" ]
  [[ "$(jq -r '.checks[] | select(.check=="iterations") | .message' <<<"$output")" == *"invalid"* ]]
}

@test "negativo: proceso Basic da FAIL en process y exit 1" {
  fx properties '{"value":[{"name":"System.ProcessTemplateType","value":"t-basic"}]}'
  validate --project "Acme"
  [ "$status" -eq 1 ]
  [ "$(status_of process)" = "FAIL" ]
}

@test "positivo: proceso heredado de Agile da PASS; Scrum da WARN con exit 0" {
  fx processes '{"value":[{"typeId":"t-agile","name":"Agile"},{"typeId":"t-inh","name":"Acme Agile","parentProcessTypeId":"t-agile"},{"typeId":"t-scrum","name":"Scrum"}]}'
  fx properties '{"value":[{"name":"System.ProcessTemplateType","value":"t-inh"}]}'
  validate --project "Acme"
  [ "$(status_of process)" = "PASS" ]
  fx properties '{"value":[{"name":"System.ProcessTemplateType","value":"t-scrum"}]}'
  validate --project "Acme"
  [ "$status" -eq 0 ]
  [ "$(status_of process)" = "WARN" ]
}

@test "negativo: falta un tipo (Epic) da FAIL en types" {
  fx types '{"value":[{"name":"Feature"},{"name":"User Story"},{"name":"Task"},{"name":"Bug"}]}'
  validate --project "Acme"
  [ "$(status_of types)" = "FAIL" ]
  [[ "$(jq -r '.checks[] | select(.check=="types") | .message' <<<"$output")" == *"Epic"* ]]
}

@test "negativo: falta el estado Resolved en Bug da FAIL en states con el detalle" {
  fx wit-Bug '{"states":[{"name":"New"},{"name":"Active"},{"name":"Closed"}],"fields":[{"referenceName":"Microsoft.VSTS.Scheduling.StoryPoints"},{"referenceName":"Microsoft.VSTS.Common.Priority"},{"referenceName":"Microsoft.VSTS.Common.Severity"}]}'
  validate --project "Acme"
  [ "$status" -eq 1 ]
  [ "$(status_of states)" = "FAIL" ]
  [ "$(jq -r '.checks[] | select(.check=="states") | .details[0] | "\(.type):\(.missing)"' <<<"$output")" = "Bug:Resolved" ]
}

@test "límite: falta un campo (StoryPoints) es WARN no bloqueante y exit 0" {
  fx wit-User_Story '{"states":[{"name":"New"},{"name":"Active"},{"name":"Resolved"},{"name":"Closed"}],"fields":[{"referenceName":"Microsoft.VSTS.Common.Priority"}]}'
  validate --project "Acme"
  [ "$status" -eq 0 ]
  [ "$(status_of fields)" = "WARN" ]
}

@test "límite: un nombre de campo no casa por regex (el punto es literal)" {
  fx wit-User_Story '{"states":[{"name":"New"},{"name":"Active"},{"name":"Resolved"},{"name":"Closed"}],"fields":[{"referenceName":"MicrosoftXVSTSXSchedulingXStoryPoints"},{"referenceName":"Microsoft.VSTS.Common.Priority"}]}'
  validate --project "Acme"
  [ "$(status_of fields)" = "WARN" ]
}

@test "límite: cero iteraciones (empty) es FAIL; iteraciones sin fechas es WARN" {
  fx iterations '{"value":[]}'
  validate --project "Acme"
  [ "$status" -eq 1 ]
  [ "$(status_of iterations)" = "FAIL" ]
  fx iterations '{"value":[{"name":"Sprint 1","attributes":{"startDate":null}}]}'
  validate --project "Acme"
  [ "$(status_of iterations)" = "WARN" ]
}

@test "límite: bugs no gestionados como requisitos es WARN en backlog" {
  fx backlog '{"bugsBehavior":"off","requirementBacklog":{"workItemTypes":[{"name":"User Story"}]}}'
  validate --project "Acme"
  [ "$status" -eq 0 ]
  [ "$(status_of backlog)" = "WARN" ]
}

@test "positivo: --output escribe el mismo JSON y crea el directorio" {
  validate --project "Acme" --output "$TMPDIR/nested/dir/report.json"
  [ "$status" -eq 0 ]
  [ "$(jq -c 'del(.timestamp)' "$TMPDIR/nested/dir/report.json")" = "$(jq -c 'del(.timestamp)' <<<"$output")" ]
}

@test "uso: --help funciona sin PAT ni red y sale con 0" {
  export AZURE_DEVOPS_PAT_FILE="$TMPDIR/no-existe"
  validate --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--project"* ]]
}

@test "error: argumento desconocido, --project sin valor o sin --project da exit 2" {
  validate --project "Acme" --bogus
  [ "$status" -eq 2 ]
  validate --project
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--project"* ]]
  [[ "$stderr" != *"unbound"* ]]
  validate
  [ "$status" -eq 2 ]
  [ ! -s "$STUB_ARGV" ]
}
