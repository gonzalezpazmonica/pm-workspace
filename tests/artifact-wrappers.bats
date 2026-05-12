#!/usr/bin/env bats
# tests/artifact-wrappers.bats
# Tests de integración para scripts/artifact-list.sh y scripts/artifact-export.sh.
# SPEC-AGENT-ARTIFACTS Slice 1.
#
# Requiere: bats-core, Python 3.10+, pydantic, pyyaml.
# Los tests usan un directorio temporal y NO tocan output/ real.

setup() {
  # Directorio temporal aislado
  export ARTIFACTS_TMP
  ARTIFACTS_TMP="$(mktemp -d)"
  export SAVIA_RUN_ID="run_bats_$(date +%s)"
  export SAVIA_ARTIFACT_SECRET_DEV_FALLBACK="dev-bats-fallback"
  # Crear un artifact de prueba vía Python para los tests de list/export
  PYTHONPATH="$(pwd)" python3 - << 'PYEOF'
import os, sys
sys.path.insert(0, '.')
from pathlib import Path
from scripts.lib.artifacts.store import ArtifactStore
from scripts.lib.artifacts.tools import save_artifact, configure_store

store = ArtifactStore(Path(os.environ["ARTIFACTS_TMP"]) / "artifacts")
configure_store(store)
ref = save_artifact(
    "bats_test.csv",
    "a,b\n1,2",
    "text/csv",
    run_id=os.environ["SAVIA_RUN_ID"],
    store=store,
)
print(ref.artifact_id)
PYEOF
}

teardown() {
  rm -rf "$ARTIFACTS_TMP"
}

@test "artifact-list.sh imprime JSON con al menos un artifact" {
  run bash scripts/artifact-list.sh \
    --artifacts-dir "$ARTIFACTS_TMP/artifacts" \
    --run-id "$SAVIA_RUN_ID"
  [ "$status" -eq 0 ]
  # La salida debe ser JSON array no vacío
  echo "$output" | python3 -c "import sys,json; items=json.load(sys.stdin); assert len(items)>=1"
}

@test "artifact-list.sh filtra por mime type correctamente" {
  run bash scripts/artifact-list.sh \
    --artifacts-dir "$ARTIFACTS_TMP/artifacts" \
    --run-id "$SAVIA_RUN_ID" \
    --mime "text/csv"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "
import sys, json
items = json.load(sys.stdin)
assert all(i['mime_type'] == 'text/csv' for i in items), f'unexpected: {items}'
"
}

@test "artifact-list.sh sin --run-id no falla" {
  run bash scripts/artifact-list.sh \
    --artifacts-dir "$ARTIFACTS_TMP/artifacts"
  # Puede devolver lista vacía o con el artifact; en cualquier caso exit 0
  [ "$status" -eq 0 ]
}
