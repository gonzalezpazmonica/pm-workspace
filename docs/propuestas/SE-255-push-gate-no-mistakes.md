# SE-255 — Savia Push Gate: remote-swap pattern

**Inspiracion**: no-mistakes Gate Model (kunchenguid/no-mistakes)
**Principio**: structural enforcement > behavioral enforcement

---

## Problema recurrente

El agente hace `git push origin` directamente. Cada push invalida la firma de
confidencialidad y omite las 16 gates de `pr-plan.sh`. Resultado: el ciclo

```
push -> CI rompe (firma, BATS, lint) -> fix -> sign -> push -> CI rompe
```

se repite durante horas (PR #895: 9 iteraciones). Pedirle al agente que no lo
haga no funciona -- es un problema estructural, no conductual.

## Solucion: remote swap

En lugar del actual `origin -> GitHub`, se interpone un bare repo local como gate:

```
ANTES:   git push origin --------------------------------> GitHub
AHORA:   git push origin -> [bare repo gate] -> pr-plan -> sign -> origin-upstream -> GitHub
```

El agente puede seguir haciendo `git push origin` -- pero `origin` ya no es GitHub.
Es un bare repo local cuyo `post-receive` hook ejecuta las gates. Si pasan,
forwardea a `origin-upstream` (el GitHub real). Si fallan, el push se queda en
el gate y el agente recibe el diagnostico.

No hay camino a GitHub sin pasar por el gate. Es fisica de git, no una regla.

---

## Arquitectura

```
                          ~/.savia/gate.git
  ┌──────────────────────────────────────────────────────────┐
  │  hooks/post-receive                                      │
  │                                                          │
  │  1. recibe push (rama, old-sha, new-sha)                 │
  │  2. git clone --bare gate -> worktree temporal           │
  │  3. cd worktree && bash scripts/pr-plan.sh --gate-mode   │
  │     |                                                    │
  │     +- FAIL -> echo "GATE BLOCKED: <diagnostico>"        │
  │     |         cleanup worktree, exit 0 (no forward)      │
  │     |                                                    │
  │     +- PASS -> bash scripts/confidentiality-sign.sh sign │
  │               git push origin-upstream <rama>            │
  │               cleanup worktree                           │
  └──────────────────────────────────────────────────────────┘
```

### Init (`scripts/gate-init.sh`)

```bash
# 1. Renombrar origin actual
git remote rename origin origin-upstream

# 2. Crear bare repo gate
GATE_DIR="${SAVIA_GATE_DIR:-$HOME/.savia/gate.git}"
git init --bare "$GATE_DIR"

# 3. Instalar post-receive hook
cp scripts/gate-post-receive.sh "$GATE_DIR/hooks/post-receive"
chmod +x "$GATE_DIR/hooks/post-receive"

# 4. Apuntar origin al gate
git remote add origin "$GATE_DIR"

# 5. Registrar metadata
git config savia.gate.enabled true
git config savia.gate.upstream origin-upstream
```

`git push origin <rama>` ahora empuja al gate. El hook decide si forwardea.

### Post-receive hook (`scripts/gate-post-receive.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKTREE=$(mktemp -d)
UPSTREAM_REMOTE="origin-upstream"
trap 'rm -rf "$WORKTREE"' EXIT

while read -r _old _new ref; do
    branch="${ref#refs/heads/}"

    git --git-dir="$GIT_DIR" --work-tree="$WORKTREE" checkout -f "$branch"
    cd "$WORKTREE"

    if bash scripts/pr-plan.sh --gate-mode 2>&1; then
        SAVIA_CONFIDENTIALITY_AUDITED=1 bash scripts/confidentiality-sign.sh sign
        git add .confidentiality-signature
        git commit -m "chore: gate-signed" || true
        git push "$UPSTREAM_REMOTE" "$branch"
        echo "GATE PASSED -> pushed to $UPSTREAM_REMOTE/$branch"
    else
        echo "GATE BLOCKED: pr-plan failed for $branch"
        echo "Fix issues above and push again."
    fi
done
```

### Revert (`scripts/gate-teardown.sh`)

```bash
git remote remove origin
git remote rename origin-upstream origin
git config --unset savia.gate.enabled
git config --unset savia.gate.upstream
```

---

## Acceptance Criteria

### AC-1: Init configura el gate correctamente
- [ ] AC-1.1: `gate-init.sh` renombra origin -> origin-upstream
- [ ] AC-1.2: `gate-init.sh` crea bare repo en `~/.savia/gate.git`
- [ ] AC-1.3: `gate-init.sh` instala post-receive hook ejecutable
- [ ] AC-1.4: `gate-init.sh` apunta `origin` al bare repo local
- [ ] AC-1.5: `gate-init.sh` es idempotente
- [ ] AC-1.6: `gate-init.sh` detecta si el gate ya esta activo y hace skip

### AC-2: El gate bloquea pushes que no pasan pr-plan
- [ ] AC-2.1: push a rama con comando >150 lineas -> bloqueado
- [ ] AC-2.2: push a rama con firma invalida -> bloqueado
- [ ] AC-2.3: push a rama con working tree sucio -> bloqueado
- [ ] AC-2.4: El mensaje de bloqueo muestra que gate fallo y diagnostico

### AC-3: El gate forwardea pushes limpios
- [ ] AC-3.1: push a rama que pasa pr-plan -> forwardeado a origin-upstream
- [ ] AC-3.2: La firma de confidencialidad se actualiza antes del forward
- [ ] AC-3.3: El commit de firma no interfiere con el diff del PR

### AC-4: Teardown revierte todo
- [ ] AC-4.1: `gate-teardown.sh` restaura origin -> GitHub
- [ ] AC-4.2: `gate-teardown.sh` elimina la config `savia.gate.*`
- [ ] AC-4.3: Tras teardown, `git push origin` va directo a GitHub

### AC-5: Compatibilidad
- [ ] AC-5.1: `git fetch`, `git pull`, `git remote show` funcionan con `origin-upstream`
- [ ] AC-5.2: `gh pr create`, `gh pr view` siguen funcionando
- [ ] AC-5.3: El hook no interfiere con `git push --force-with-lease`
- [ ] AC-5.4: CI de GitHub se dispara normalmente al forwardear

### AC-6: BATS tests
- [ ] AC-6.1: Test: gate-init crea estructura correcta
- [ ] AC-6.2: Test: push a rama sucia -> bloqueado por el gate
- [ ] AC-6.3: Test: push a rama limpia -> forwardeado
- [ ] AC-6.4: Test: el hook ejecuta pr-plan con modo --gate-mode
- [ ] AC-6.5: Test: gate-teardown revierte correctamente
- [ ] AC-6.6: Test: init es idempotente

---

## Reglas de negocio

- **RN-01**: El gate es estructural. Una vez activado, no hay ruta a GitHub sin pasar por el.
- **RN-02**: El gate es opcional. `gate-init.sh` lo activa, `gate-teardown.sh` lo desactiva.
- **RN-03**: El gate usa `SAVIA_CONFIDENTIALITY_AUDITED=1` porque pr-plan G7 ya audita.
- **RN-04**: El hook NUNCA bloquea el push a nivel de git (exit 0 siempre). El forward se decide por la logica del hook. Esto evita que `git push` cuelgue.
- **RN-05**: El worktree temporal se limpia siempre (trap EXIT).
- **RN-06**: `pr-plan.sh --gate-mode` es no-interactivo (como --dry-run pero con exit code significativo).

---

## Riesgos

| Riesgo | Prob | Impacto | Mitigacion |
|---|---|---|---|
| pr-plan tarda ~5 min (BATS) | Alta | Medio | post-receive es asincrono; usuario sigue trabajando |
| Bare repo se corrompe | Baja | Alto | init idempotente + teardown revierte |
| Conflicto con herramientas que asumen origin=GitHub | Media | Medio | gh CLI usa tracked remote, no origin hardcodeado |
| Worktree no se limpia | Baja | Bajo | trap EXIT + mktemp en /tmp |

---

## Estimacion

| Slice | Que | Esfuerzo |
|---|---|---|
| S1 | `scripts/gate-init.sh` + `scripts/gate-teardown.sh` | 45min |
| S2 | `scripts/gate-post-receive.sh` (hook) | 1h |
| S3 | `pr-plan.sh --gate-mode` (modo no-interactivo) | 30min |
| S4 | BATS tests (6 tests) | 45min |
| S5 | Documentacion + regla autonomous-safety.md | 15min |

**Total**: ~3h 15min. Zero dependencias externas.

---

## Referencias

- no-mistakes Gate Model (kunchenguid/no-mistakes) -- arquitectura bare repo + post-receive
- `scripts/pr-plan.sh` -- 16 gates existentes (G0-G15)
- `scripts/confidentiality-sign.sh` -- firma de confidencialidad
- `docs/rules/domain/autonomous-safety.md` -- reglas de seguridad autonoma
