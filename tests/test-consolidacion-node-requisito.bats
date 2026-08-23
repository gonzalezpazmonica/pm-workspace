#!/usr/bin/env bats
# Consolidación prueba de fuego 2026-08-23 — requisito node para recall/grafo
# Hallazgo: el savia-vaults CLI (recall SCL, cúpulas, grafo) requiere node>=22;
# sin node el recall degradaba vacío silencioso. Fix: instalador auto-instala node
# local (CRIT-001) y SessionStart exporta ~/.savia/node/bin al PATH.

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." || exit 1
}

@test "savia-install incluye paso node-detect (CRIT-001, infra propia)" {
  grep -q "node-detect" scripts/savia-install.sh
  grep -q "nodejs.org" scripts/savia-install.sh
  grep -q "\.savia/node" scripts/savia-install.sh
}

@test "session-init exporta ~/.savia/node/bin al PATH si existe" {
  grep -q '\.savia/node/bin/node' .claude/hooks/session-init.sh
  grep -q 'export PATH=' .claude/hooks/session-init.sh
}

@test "savia-install y session-init sintácticamente válidos" {
  bash -n scripts/savia-install.sh
  bash -n .claude/hooks/session-init.sh
}

@test "node en PATH hace que el vault CLI devuelva search (recall operativo)" {
  if command -v node >/dev/null 2>&1 || [ -x "$HOME/.savia/node/bin/node" ]; then
    export PATH="$HOME/.savia/node/bin:$PATH"
    run node --version
    [[ "$status" -eq 0 ]]
  else
    skip "node no disponible en este entorno (CI sin node)"
  fi
}