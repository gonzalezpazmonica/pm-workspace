# shellcheck shell=bash
# validate-devops-checks.sh — Check functions (sourced by validate-devops.sh)
# Each returns JSON: {check, status, message, details?, remediation?}
# Requires: ORG_URL, API_VERSION, PROJECT, TEAM, P_ENC, T_ENC and api_get from caller.
# Fail-closed: an API error or unreadable response is FAIL, never PASS/WARN.

api_fail() {
  jq -n --arg c "$1" --arg e "$2" '{check:$c,status:"FAIL",
    message:"API request failed: \($e)",
    remediation:"Check network, AZURE_DEVOPS_ORG_URL and PAT scopes, then re-run"}'
}

# missing_from JSON_ARRAY_OF_HAVE REQUIRED_CSV → comma-separated list of missing items
missing_from() {
  jq -rn --argjson have "$1" --arg req "$2" '[$req | split(",")[] | select(. as $r | $have | index($r) | not)] | join(", ")'
}

check_connectivity() {
  local resp
  if resp=$(api_get "$ORG_URL/_apis/projects?\$top=1&api-version=$API_VERSION"); then
    jq -n '{check:"connectivity",status:"PASS",message:"PAT authentication successful"}'
  else
    jq -n --arg e "$resp" '{check:"connectivity",status:"FAIL",
      message:"Cannot authenticate (\($e))",
      remediation:"Regenerate PAT with scopes: Work Items R/W, Project+Team R, Analytics R, Code R/W, Build R/W, Process R"}'
  fi
}

check_project() {
  local resp project_id
  if ! resp=$(api_get "$ORG_URL/_apis/projects/$P_ENC?api-version=$API_VERSION"); then
    [[ "$resp" == "HTTP 404" ]] || { api_fail project "$resp"; return 0; }
    resp='{}'
  fi
  project_id=$(jq -r '.id // empty' <<<"$resp")
  if [[ -n "$project_id" ]]; then
    jq -n --arg id "$project_id" '{check:"project",status:"PASS",message:"Project found",details:{projectId:$id}}'
  else
    jq -n --arg p "$PROJECT" '{check:"project",status:"FAIL",
      message:"Project \($p) not found",
      remediation:"Verify project name matches exactly (case-sensitive) in Azure DevOps"}'
  fi
}

check_process() {
  local processes props proc_id proc_name parent parent_name=""
  processes=$(api_get "$ORG_URL/_apis/process/processes?api-version=$API_VERSION") \
    || { api_fail process "$processes"; return 0; }
  props=$(api_get "$ORG_URL/_apis/projects/$P_ENC/properties?keys=System.ProcessTemplateType&api-version=7.1-preview.1") \
    || { api_fail process "$props"; return 0; }
  proc_id=$(jq -r '.value[]? | select(.name=="System.ProcessTemplateType") | .value // empty' <<<"$props")
  proc_name=$(jq -r --arg id "$proc_id" '.value[]? | select(.typeId==$id) | .name // empty' <<<"$processes")
  parent=$(jq -r --arg id "$proc_id" '.value[]? | select(.typeId==$id) | .parentProcessTypeId // empty' <<<"$processes")
  [[ -n "$parent" ]] && \
    parent_name=$(jq -r --arg id "$parent" '.value[]? | select(.typeId==$id) | .name // empty' <<<"$processes")
  local base="${parent_name:-$proc_name}"
  if [[ "$base" == "Agile" ]]; then
    jq -n --arg n "$proc_name" '{check:"process",status:"PASS",message:"Process template is Agile (\($n))"}'
  elif [[ "$base" == "Scrum" ]]; then
    jq -n --arg n "$proc_name" '{check:"process",status:"WARN",
      message:"Scrum process (\($n)) — compatible but states differ (Done vs Closed)",
      remediation:"Consider: Organization Settings > Process > Change process to Agile"}'
  else
    jq -n --arg n "$proc_name" --arg b "$base" '{check:"process",status:"FAIL",
      message:"Process \($n) (base: \($b)) not compatible",
      remediation:"Organization Settings > Process > Projects > Change process > select Agile"}'
  fi
}

check_types() {
  local resp have missing
  resp=$(api_get "$ORG_URL/$P_ENC/_apis/wit/workitemtypes?api-version=$API_VERSION") \
    || { api_fail types "$resp"; return 0; }
  have=$(jq -c '[.value[]?.name | ascii_downcase]' <<<"$resp")
  missing=$(jq -rn --argjson have "$have" \
    '["Epic","Feature","User Story","Task","Bug"] | map(select(ascii_downcase as $t | $have | index($t) | not)) | join(", ")')
  if [[ -z "$missing" ]]; then
    jq -n '{check:"types",status:"PASS",message:"All required types present (Epic,Feature,User Story,Task,Bug)"}'
  else
    jq -n --arg m "$missing" '{check:"types",status:"FAIL",message:"Missing types: \($m)",
      remediation:"Use inherited Agile process to add missing types, or migrate to standard Agile"}'
  fi
}

_get_wit_data() { api_get "$ORG_URL/$P_ENC/_apis/wit/workitemtypes/$(urlenc "$1")?api-version=$API_VERSION"; }

check_states() {
  local all_ok=true details="[]" wit data missing
  local -A expected=(["User Story"]="New,Active,Resolved,Closed" ["Task"]="New,Active,Closed" ["Bug"]="New,Active,Resolved,Closed")
  for wit in "User Story" "Task" "Bug"; do
    data=$(_get_wit_data "$wit") || { api_fail states "$data ($wit)"; return 0; }
    missing=$(missing_from "$(jq -c '[.states[]?.name]' <<<"$data")" "${expected[$wit]}")
    if [[ -n "$missing" ]]; then
      all_ok=false
      details=$(jq -c --arg w "$wit" --arg m "$missing" '. + [{type:$w,missing:$m}]' <<<"$details")
    fi
  done
  if $all_ok; then
    jq -n '{check:"states",status:"PASS",message:"All required states present per type"}'
  else
    jq -n --argjson d "$details" '{check:"states",status:"FAIL",message:"Missing states",details:$d,
      remediation:"Add missing states via inherited process: Organization Settings > Process > Work item types"}'
  fi
}

check_fields() {
  local all_ok=true details="[]" wit data missing
  local -A wit_fields=(
    ["User Story"]="Microsoft.VSTS.Scheduling.StoryPoints,Microsoft.VSTS.Common.Priority"
    ["Task"]="Microsoft.VSTS.Scheduling.OriginalEstimate,Microsoft.VSTS.Scheduling.RemainingWork,Microsoft.VSTS.Scheduling.CompletedWork,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.Activity"
    ["Bug"]="Microsoft.VSTS.Scheduling.StoryPoints,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.Severity"
  )
  for wit in "User Story" "Task" "Bug"; do
    data=$(_get_wit_data "$wit") || { api_fail fields "$data ($wit)"; return 0; }
    missing=$(missing_from "$(jq -c '[.fields[]?.referenceName]' <<<"$data")" "${wit_fields[$wit]}")
    if [[ -n "$missing" ]]; then
      all_ok=false
      details=$(jq -c --arg w "$wit" --arg m "$missing" '. + [{type:$w,missing:$m}]' <<<"$details")
    fi
  done
  if $all_ok; then
    jq -n '{check:"fields",status:"PASS",message:"All required fields present"}'
  else
    jq -n --argjson d "$details" '{check:"fields",status:"WARN",message:"Missing fields (queries may return nulls)",details:$d,
      remediation:"Add fields via inherited process: Organization Settings > Process > Work item types > Layout"}'
  fi
}

check_backlog() {
  local resp bugs_behavior has_us issues=""
  resp=$(api_get "$ORG_URL/$P_ENC/$T_ENC/_apis/work/backlogconfiguration?api-version=$API_VERSION") \
    || { api_fail backlog "$resp"; return 0; }
  bugs_behavior=$(jq -r '.bugsBehavior // "unknown"' <<<"$resp")
  has_us=$(jq '[.requirementBacklog.workItemTypes[]?.name] | any(. == "User Story")' <<<"$resp")
  [[ "$bugs_behavior" != "asRequirements" ]] && issues="Bug behavior is '$bugs_behavior' (expected 'asRequirements')"
  [[ "$has_us" != "true" ]] && issues="${issues}${issues:+; }User Story not in requirements backlog"
  if [[ -z "$issues" ]]; then
    jq -n '{check:"backlog",status:"PASS",message:"Backlog hierarchy and bug behavior correct"}'
  else
    jq -n --arg i "$issues" '{check:"backlog",status:"WARN",message:$i,
      remediation:"Project Settings > Boards > Team config > Bugs: select Bugs are managed with requirements"}'
  fi
}

check_iterations() {
  local resp total with_dates
  resp=$(api_get "$ORG_URL/$P_ENC/$T_ENC/_apis/work/teamsettings/iterations?api-version=$API_VERSION") \
    || { api_fail iterations "$resp"; return 0; }
  total=$(jq '[.value[]?] | length' <<<"$resp")
  with_dates=$(jq '[.value[]? | select(.attributes.startDate != null)] | length' <<<"$resp")
  if [[ "$total" -eq 0 ]]; then
    jq -n '{check:"iterations",status:"FAIL",message:"No iterations configured",
      remediation:"Project Settings > Boards > Iterations: add sprints with start/end dates"}'
  elif [[ "$with_dates" -eq 0 ]]; then
    jq -n --arg t "$total" '{check:"iterations",status:"WARN",
      message:"\($t) iteration(s) but none have dates",
      remediation:"Project Settings > Project configuration > Iterations: set dates for each sprint"}'
  else
    jq -n --arg t "$total" --arg d "$with_dates" \
      '{check:"iterations",status:"PASS",message:"\($d)/\($t) iterations have dates configured"}'
  fi
}
