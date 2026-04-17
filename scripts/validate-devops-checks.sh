# validate-devops-checks.sh — Check functions (sourced by validate-devops.sh)
# Each returns JSON: {check, status, message, details?, remediation?}
# Requires: ORG_URL, API_VERSION, PROJECT, TEAM, PROJECT_ID from caller.

check_connectivity() {
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "$(auth_header)" \
    "$ORG_URL/_apis/projects?\$top=1&api-version=$API_VERSION")
  if [[ "$code" == "200" ]]; then
    jq -n '{check:"connectivity",status:"PASS",message:"PAT authentication successful"}'
  else
    jq -n --arg c "$code" '{check:"connectivity",status:"FAIL",
      message:"Cannot authenticate (HTTP \($c))",
      remediation:"Regenerate PAT with scopes: Work Items R/W, Project+Team R, Analytics R, Code R/W, Build R/W, Process R"}'
  fi
}

check_project() {
  local resp
  resp=$(api_get "$ORG_URL/_apis/projects/$PROJECT?api-version=$API_VERSION")
  PROJECT_ID=$(echo "$resp" | jq -r '.id // empty')
  if [[ -n "$PROJECT_ID" ]]; then
    jq -n --arg id "$PROJECT_ID" '{check:"project",status:"PASS",message:"Project found",details:{projectId:$id}}'
  else
    jq -n --arg p "$PROJECT" '{check:"project",status:"FAIL",
      message:"Project \($p) not found",
      remediation:"Verify project name matches exactly (case-sensitive) in Azure DevOps"}'
  fi
}

check_process() {
  local proc_id proc_name processes
  processes=$(api_get "$ORG_URL/_apis/process/processes?api-version=$API_VERSION")
  proc_id=$(api_get "$ORG_URL/_apis/projects/$PROJECT/properties?keys=System.ProcessTemplateType&api-version=7.1-preview.1" \
    | jq -r '.value[]? | select(.name=="System.ProcessTemplateType") | .value // empty')
  proc_name=$(echo "$processes" | jq -r --arg id "$proc_id" '.value[]? | select(.typeId==$id) | .name // empty')
  local parent
  parent=$(echo "$processes" | jq -r --arg id "$proc_id" '.value[]? | select(.typeId==$id) | .parentProcessTypeId // empty')
  local parent_name=""
  [[ -n "$parent" && "$parent" != "null" ]] && \
    parent_name=$(echo "$processes" | jq -r --arg id "$parent" '.value[]? | select(.typeId==$id) | .name // empty')
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
  local types missing=""
  types=$(api_get "$ORG_URL/$PROJECT/_apis/wit/workitemtypes?api-version=$API_VERSION" \
    | jq -r '[.value[].name] | join(",")')
  for t in "Epic" "Feature" "User Story" "Task" "Bug"; do
    echo ",$types," | grep -qi ",$t," || missing="${missing}${missing:+, }$t"
  done
  if [[ -z "$missing" ]]; then
    jq -n '{check:"types",status:"PASS",message:"All required types present (Epic,Feature,User Story,Task,Bug)"}'
  else
    jq -n --arg m "$missing" '{check:"types",status:"FAIL",message:"Missing types: \($m)",
      remediation:"Use inherited Agile process to add missing types, or migrate to standard Agile"}'
  fi
}

_get_wit_data() { api_get "$ORG_URL/$PROJECT/_apis/wit/workitemtypes/${1// /%20}?api-version=$API_VERSION"; }

check_states() {
  local all_ok=true details="[]"
  local -A expected=(["User Story"]="New,Active,Resolved,Closed" ["Task"]="New,Active,Closed" ["Bug"]="New,Active,Resolved,Closed")
  for wit in "User Story" "Task" "Bug"; do
    local states missing=""
    states=$(_get_wit_data "$wit" | jq -r '[.states[]?.name] | join(",")')
    IFS=',' read -ra exp <<< "${expected[$wit]}"
    for s in "${exp[@]}"; do
      echo ",$states," | grep -q ",$s," || { missing="${missing}${missing:+, }$s"; all_ok=false; }
    done
    [[ -n "$missing" ]] && details=$(echo "$details" | jq --arg w "$wit" --arg m "$missing" '. + [{type:$w,missing:$m}]')
  done
  if $all_ok; then
    jq -n '{check:"states",status:"PASS",message:"All required states present per type"}'
  else
    jq -n --argjson d "$details" '{check:"states",status:"FAIL",message:"Missing states",details:$d,
      remediation:"Add missing states via inherited process: Organization Settings > Process > Work item types"}'
  fi
}

check_fields() {
  local all_ok=true details="[]"
  local -A wit_fields=(
    ["User Story"]="Microsoft.VSTS.Scheduling.StoryPoints,Microsoft.VSTS.Common.Priority"
    ["Task"]="Microsoft.VSTS.Scheduling.OriginalEstimate,Microsoft.VSTS.Scheduling.RemainingWork,Microsoft.VSTS.Scheduling.CompletedWork,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.Activity"
    ["Bug"]="Microsoft.VSTS.Scheduling.StoryPoints,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.Severity"
  )
  for wit in "User Story" "Task" "Bug"; do
    local fields missing=""
    fields=$(_get_wit_data "$wit" | jq -r '[.fields[]?.referenceName] | join(",")')
    IFS=',' read -ra req <<< "${wit_fields[$wit]}"
    for f in "${req[@]}"; do
      echo ",$fields," | grep -q ",$f," || { missing="${missing}${missing:+, }$f"; all_ok=false; }
    done
    [[ -n "$missing" ]] && details=$(echo "$details" | jq --arg w "$wit" --arg m "$missing" '. + [{type:$w,missing:$m}]')
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
  resp=$(api_get "$ORG_URL/$PROJECT/$TEAM/_apis/work/backlogconfiguration?api-version=$API_VERSION")
  bugs_behavior=$(echo "$resp" | jq -r '.bugsBehavior // "unknown"')
  has_us=$(echo "$resp" | jq '[.requirementBacklog.workItemTypes[]?.name] | any(. == "User Story")')
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
  resp=$(api_get "$ORG_URL/$PROJECT/$TEAM/_apis/work/teamsettings/iterations?api-version=$API_VERSION")
  total=$(echo "$resp" | jq '[.value[]?] | length')
  with_dates=$(echo "$resp" | jq '[.value[]? | select(.attributes.startDate != null)] | length')
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
