# CI-UNBLOCK - Modo ci-unblock de overnight-sprint

Satelite de SKILL.md. Detalle tecnico del modo --mode ci-unblock.

## Que hace

Itera sobre PRs con CI roto en GitHub por orden de PR# ascendente. Cada PR
se procesa en un nido aislado via scripts/nidos.sh para no interferir con
sesiones de desarrollo paralelas activas.

## Prerequisitos extra

gh CLI autenticado (gh auth status).
CI_UNBLOCK_NEST_ENABLED=true + doble opt-in SPEC-186:
  bash scripts/savia-double-optin-check.sh --skill overnight-sprint --confirm-autonomous

## Flujo completo

Listar PRs con CI roto (statusCheckRollup != SUCCESS, orden PR# ASC):
  gh pr list --state open --json number,headRefName,statusCheckRollup
  filtrando jq sort_by(.number)

Filtrar nidos activos: scripts/nidos.sh list -> no pisar sesion paralela.

LOOP por cada PR:
  1. scripts/nidos.sh create ci-pr-{PR} --branch {headRefName}
  2. gh run list --branch + gh run view --log-failed
  3. Categorizar fallo (tabla abajo)
  4. Fix? SI: fix + commit agent(ci-unblock) + push + gh run watch
         NO (infra) o 3er intento: SKIP + needs-human
  5. scripts/nidos.sh remove ci-pr-{PR}

## Categorizacion de fallos

lint   : SI  | autofix linter del proyecto
test   : SI  | fix minimo en codigo produccion, NO modificar tests
build  : SI  | resolver import o dep error
config : SI  | corregir YAML/JSON de pipeline
infra  : NO  | runner down o rate limit - SKIP siempre

## Commit

git commit -m "agent(ci-unblock): fix CI #PR -- CATEGORIA"
git push origin BRANCH  (nunca force)

## Restricciones

NUNCA  -> force push, merge, modificar tests, pisar nido de sesion ajena
SIEMPRE -> scripts/nidos.sh para aislamiento (no /tmp/ ad-hoc)
SIEMPRE -> scripts/nidos.sh remove al terminar

## Outputs

output/ci-unblock-YYYYMMDD.tsv (timestamp,pr_number,branch,categoria,accion,intentos,resultado,ci_url)
output/agent-runs/ci-unblock-YYYYMMDD-audit.log
