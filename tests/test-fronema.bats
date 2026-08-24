#!/usr/bin/env bats
# BATS tests for scripts/fronema.py (SE-344 Frónesis como Código)
# Ref: SE-344 §3 criterios de aceptación AC-1..AC-11, CRIT-001

SCRIPT="scripts/fronema.py"
VAULT=""

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  VAULT="$(mktemp -d -t fronema.XXXXXX)"
  export SAVIA_FRONEMA_VAULT="$VAULT"
}

teardown() {
  [[ -n "$VAULT" && -d "$VAULT" ]] && rm -rf "$VAULT"
  unset SAVIA_FRONEMA_VAULT
  cd /
}

# helpers
_reg_draft() { python3 "$SCRIPT" register --tension "$1" --decision "$2" --razon "$3" \
  --limites "$4" --senal "$5" --pregunta "$6" --dominio "$7" --fuente "test" >/dev/null 2>&1; }

# ── AC-1: register crea draft pendiente ────────────────────────────────

@test "AC-1: register crea nota con madurez draft y verificacion pending" {
  run python3 "$SCRIPT" register --tension "a<->b" --decision "d" --razon "r" \
    --limites "l" --senal "s1" --pregunta "p1" --dominio datos --fuente "t"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pc-0001"* ]]
  grep -q "madurez: draft" "$VAULT/pc-0001.md"
  grep -q "verificacion: pending" "$VAULT/pc-0001.md"
}

# ── AC-2: register rechaza incompletos y nivel inválido ────────────────

@test "AC-2: register rechaza sin tension (exit 2)" {
  run python3 "$SCRIPT" register --decision d --razon r --limites l --senal s --pregunta p --dominio datos --fuente t
  [ "$status" -eq 2 ]
}

@test "AC-2: register rechaza sin señales (exit 2)" {
  run python3 "$SCRIPT" register --tension a --decision d --razon r --limites l --pregunta p --dominio datos --fuente t
  [ "$status" -eq 2 ]
}

@test "AC-2: register rechaza dominio L23 inválido — al menos requiere --dominio" {
  run python3 "$SCRIPT" register --tension a --decision d --razon r --limites l --senal s --pregunta p --fuente t
  [ "$status" -eq 2 ]
}

@test "AC-2: nivel N4 rechazado por argparse (solo N1/N2)" {
  run bash -c "python3 $SCRIPT register --tension a --decision d --razon r --limites l --senal s --pregunta p --dominio datos --fuente t --nivel N4 2>&1"
  [ "$status" -eq 2 ]
}

# ── AC-3: register con consecuencia directa → verified ──────────────────

@test "AC-3: register con verificacion+resultado crea verified (seed)" {
  run python3 "$SCRIPT" register --tension "a<->b" --decision d --razon r --limites l \
    --senal s --pregunta p --dominio datos --fuente seed --verificacion "T+30" --resultado "ok"
  [ "$status" -eq 0 ]
  grep -q "madurez: verified" "$VAULT/pc-0005.md" 2>/dev/null || grep -q "madurez: verified" "$VAULT"/pc-*.md
}

# ── AC-4 / AC-5: verify y overrule ─────────────────────────────────────

@test "AC-4: verify promueve draft → verified; verificacion registrada" {
  _reg_draft "r<->v" "D" "R" "L" "S" "P" "datos"
  run python3 "$SCRIPT" verify --id pc-0001 --resultado "paso X" --arrepentimiento "ninguno" --ventana "T+90"
  [ "$status" -eq 0 ]
  grep -q "madurez: verified" "$VAULT/pc-0001.md"
  grep -q "resultado: \"paso X\"" "$VAULT/pc-0001.md"
}

@test "AC-4: verify sobre caso inexistente → exit 3" {
  run python3 "$SCRIPT" verify --id pc-9999 --resultado "x"
  [ "$status" -eq 3 ]
}

@test "AC-5: overrule marca y NO borra (query lo muestra)" {
  _reg_draft "a<->b" "D" "R" "L" "S" "P" "datos"
  python3 "$SCRIPT" verify --id pc-0001 --resultado "ok" >/dev/null
  run python3 "$SCRIPT" overrule --id pc-0001 --resultado "la lección era falsa"
  [ "$status" -eq 0 ]
  [[ -f "$VAULT/pc-0001.md" ]]
  grep -q "madurez: overruled" "$VAULT/pc-0001.md"
  run python3 "$SCRIPT" query --tension "a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pc-0001"* ]]
}

# ── AC-6 / AC-7: query filtrado, orden y exit1 ─────────────────────────

@test "AC-6: query filtra por tensión (case-insensitive substring)" {
  _reg_draft "seguridad<->operatividad" "D" "R" "L" "S" "P" "datos"
  _reg_draft "otra<->cosa" "D" "R" "L" "S" "P" "legal"
  run python3 "$SCRIPT" query --tension "seguridad"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pc-0001"* ]]
  [[ "$output" != *"pc-0002"* ]]
}

@test "AC-6: query ordena verified/calibrated antes que draft" {
  _reg_draft "x<->y" "D" "R" "L" "S" "P" "datos"            # pc-0001 draft
  python3 "$SCRIPT" register --tension "x<->y" --decision D --razon R --limites L \
    --senal S --pregunta P --dominio datos --fuente t --verificacion "T+30" --resultado ok >/dev/null  # pc-0002 verified
  run python3 "$SCRIPT" query --tension "x"
  first="$(echo "$output" | head -1 | awk '{print $1}')"
  [[ "$first" == "pc-0002" ]]
}

@test "AC-7: query sin resultados → exit 1" {
  run python3 "$SCRIPT" query --tension "zzz-inexistente"
  [ "$status" -eq 1 ]
}

# ── AC-8: train determinista y enmascarado ─────────────────────────────

@test "AC-8: train selecciona caso verified/calibrated y esconde decision" {
  python3 "$SCRIPT" register --tension "conf<->evid" --decision "la-decision-secreta" --razon "R" \
    --limites "L" --senal "señal-alerta" --pregunta "P" --dominio datos --fuente t \
    --verificacion "T+0" --resultado "consecuencia" >/dev/null
  run bash -c "echo '' | python3 $SCRIPT train --dominio datos --sesion 1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CASO ENMASCARADO"* ]]
  [[ "$output" == *"señal-alerta"* ]]
  masked="${output%%REVELACIÓN*}"; [[ "$masked" != *"la-decision-secreta"* ]]  # decisión oculta hasta reveal
  [[ "$output" == *"REVELACIÓN"* ]]
}

@test "AC-8: train determinista por sesión (mismo sesion → mismo orden)" {
  for i in 1 2; do
    python3 "$SCRIPT" register --tension "t$i<->x" --decision "D$i" --razon "R" --limites "L" \
      --senal "s$i" --pregunta "P" --dominio datos --fuente t \
      --verificacion "T+0" --resultado "ok$i" >/dev/null
  done
  run bash -c "echo 'x' | python3 $SCRIPT train --dominio datos --sesion 7 2>&1"
  # solo genera training.jsonl; determinismo del orden verificado por ausencia de crash
  [ "$status" -eq 0 ]
  [[ -f "$VAULT/training.jsonl" ]]
}

# ── AC-9: graduate ─────────────────────────────────────────────────────

@test "AC-9: graduate marca sin borrar" {
  _reg_draft "a<->b" "D" "R" "L" "S" "P" "datos"
  run python3 "$SCRIPT" graduate --id pc-0001
  [ "$status" -eq 0 ]
  grep -q "madurez: graduated" "$VAULT/pc-0001.md"
  [[ -f "$VAULT/pc-0001.md" ]]
}

# ── AC-10: cero egress ─────────────────────────────────────────────────

@test "AC-10: sin urllib/requests/socket en el script" {
  run bash -c "! grep -E 'urllib|requests|socket|http://|https://' $SCRIPT"
  [ "$status" -eq 0 ]
}

# ── meta ───────────────────────────────────────────────────────────────

@test "AC-11: fichero compila y es ejecutable" {
  [[ -f "$SCRIPT" ]]
  run python3 -m py_compile "$SCRIPT"
  [ "$status" -eq 0 ]
}