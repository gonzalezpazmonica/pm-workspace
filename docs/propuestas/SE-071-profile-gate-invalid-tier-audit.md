---
id: SE-071
title: Profile gate invalid tier audit — block-branch-switch-dirty + otros hooks
status: PROPOSED
priority: alta
origin: batch 48 hook coverage — test discovery
author: Savia
related: profile-gate.sh, block-branch-switch-dirty.sh
---

# SE-071 — Profile gate invalid tier audit

## Why

Durante batch 48 (test coverage de `block-branch-switch-dirty.sh`), descubri que el hook llama `profile_gate "minimal"` pero `"minimal"` NO es un tier valido.

Los tiers validos (segun `lib/profile-gate.sh`) son:
- `security` — hard blockers
- `standard` — quality gates
- `strict` — extra scrutiny

`"minimal"` es un VALOR de profile (SAVIA_HOOK_PROFILE), no un TIER. Cuando `profile_gate "minimal"` se ejecuta bajo `SAVIA_HOOK_PROFILE=standard` (el default), el case matcheo:

```bash
standard|ci)
  [[ "$required" == "security" || "$required" == "standard" ]] && return 0
  exit 0   # <-- minimal matchea NI security NI standard → skip silent
  ;;
```

Resultado: **el hook de seguridad NUNCA se ejecuta en profile standard** (el default). Un git checkout con árbol sucio NO se bloquea, contra la intencion declarada ("Tier: security (always active)").

## Impact

- `block-branch-switch-dirty.sh`: hook de seguridad silenciosamente deshabilitado
- Posibles otros hooks con el mismo bug (audit pendiente)
- Proteccion contra perdida de datos al cambiar de rama esta rota

## Verification

```bash
# Repro:
$ cd /tmp && mkdir test && cd test
$ git init -q && git config user.email t@t && git config user.name t
$ echo a > a.txt && git add a.txt && git commit -qm init
$ git branch feature
$ echo modified > a.txt
$ bash /home/monica/claude/.claude/hooks/block-branch-switch-dirty.sh \
    <<< '{"tool_input":{"command":"git checkout feature"}}'
$ echo $?
0    # <-- deberia ser 2 (BLOQUEADO)
```

## Proposed fix

En `block-branch-switch-dirty.sh`:

```diff
- source "$LIB_DIR/profile-gate.sh" && profile_gate "minimal"
+ source "$LIB_DIR/profile-gate.sh" && profile_gate "security"
```

Cambiar `"minimal"` (invalid tier) por `"security"` (tier valido que se ejecuta en TODOS los profiles, incluido `minimal`).

## Audit scope

Revisar TODOS los hooks para el mismo patron:

```bash
grep -rn 'profile_gate "minimal"' .claude/hooks/
grep -rn 'profile_gate "\(minimal\|ci\)"' .claude/hooks/
```

Cualquier tier !=  {security, standard, strict} es bug.

## Acceptance criteria

1. Todos los hooks usan tiers validos (security/standard/strict)
2. `block-branch-switch-dirty.sh` bloquea correctamente bajo profile default
3. Test regression: `bats tests/test-block-branch-switch-dirty.bats` pasa con `SAVIA_HOOK_PROFILE=standard` (sin necesidad de `strict`)
4. Audit script valida tiers en todos los hooks que llaman profile_gate

## Blocked by

- Permission hook bloquea auto-fix de safety hooks (correcto per user feedback "NEVER design overrides for safety hooks"). Requiere approval explicito de Monica.

## Effort

- agent_effort_minutes: 15 (fix + audit + test update)
- human_effort_hours: 0.5 (review del diff + approval)
- review_effort_minutes: 15
