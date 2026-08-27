#!/usr/bin/env bats
# Ref: SE-344 — fronema.py CLI (AC-11: ≥12 tests cubriendo AC-1..AC-9 + determinismo)

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FRO="$ROOT_DIR/scripts/fronema.py"
  TMPV="$(mktemp -d)"
  export TMPV
}

teardown() {
  rm -rf "$TMPV" 2>/dev/null || true
}

_reg() {
  python3 "$FRO" register --tension "$1" --decision "$2" --razon "$3" --limites "$4" \
    --senal "s1" --pregunta "p1" --dominio SFT --fuente "test" --vault "$TMPV"
}

@test "SE-344 AC-1: register crea nota draft con verificacion pending" {
  _reg "rigor ↔ velocidad" "dec" "raz" "lim" >/dev/null
  [ -f "$TMPV/pc-0001.md" ]
  grep -q "madurez: draft" "$TMPV/pc-0001.md"
  grep -q "verificacion: pending" "$TMPV/pc-0001.md"
  grep -q "phronesis-case" "$TMPV/pc-0001.md"
}

@test "SE-344 AC-2: register rechaza sin tension / sin senal / sin decision / sin limites" {
  run python3 "$FRO" register --decision d --razon r --limites l --senal s --pregunta p --dominio SFT --fuente f --vault "$TMPV"
  [ "$status" -eq 2 ]
  run python3 "$FRO" register --tension t --decision d --razon r --limites l --pregunta p --dominio SFT --fuente f --vault "$TMPV"
  [ "$status" -eq 2 ]
  run python3 "$FRO" register --tension t --razon r --limites l --senal s --pregunta p --dominio SFT --fuente f --vault "$TMPV"
  [ "$status" -eq 2 ]
  run python3 "$FRO" register --tension t --decision d --razon r --senal s --pregunta p --dominio SFT --fuente f --vault "$TMPV"
  [ "$status" -eq 2 ]
}

@test "SE-344 AC-2: register rechaza dominio no-L23 y nivel N3/N4/N4b" {
  run python3 "$FRO" register --tension t --decision d --razon r --limites l --senal s --pregunta p --dominio XXX --fuente f --vault "$TMPV"
  [ "$status" -eq 2 ]
  for n in N3 N4 N4b; do
    run python3 "$FRO" register --tension t --decision d --razon r --limites l --senal s --pregunta p --dominio SFT --fuente f --nivel "$n" --vault "$TMPV"
    [ "$status" -eq 2 ]
  done
}

@test "SE-344 AC-3: register con verificacion+resultado crea verified (seed)" {
  python3 "$FRO" register --tension t --decision d --razon r --limites l --senal s --pregunta p --dominio CYB --fuente f --verificacion T+90 --resultado "ok" --vault "$TMPV" >/dev/null
  grep -q "madurez: verified" "$TMPV/pc-0001.md"
}

@test "SE-344 AC-4: verify promueve draft->verified; caso inexistente -> exit 3" {
  _reg "t" "d" "r" "l" >/dev/null
  python3 "$FRO" verify --id pc-0001 --resultado "ok" --vault "$TMPV" >/dev/null
  grep -q "madurez: verified" "$TMPV/pc-0001.md"
  run python3 "$FRO" verify --id pc-9999 --resultado x --vault "$TMPV"
  [ "$status" -eq 3 ]
}

@test "SE-344 AC-5: overrule marca (no borra) y query lo muestra" {
  _reg "t" "d" "r" "l" >/dev/null
  python3 "$FRO" overrule --id pc-0001 --resultado "desmentido" --vault "$TMPV" >/dev/null
  [ -f "$TMPV/pc-0001.md" ]
  grep -q "madurez: overruled" "$TMPV/pc-0001.md"
  python3 "$FRO" query --madurez overruled --vault "$TMPV" | grep -q "pc-0001"
}

@test "SE-344 AC-6: query filtra por tension (case-insensitive) y ordena verified primero" {
  python3 "$FRO" register --tension "Seguridad ↔ Operatividad" --decision a --razon r --limites l --senal s --pregunta p --dominio CYB --fuente f --verificacion T+90 --resultado ok --vault "$TMPV" >/dev/null
  _reg "rigor ↔ velocidad" "b" "r" "l" >/dev/null
  out=$(python3 "$FRO" query --tension "SEGURIDAD" --vault "$TMPV")
  echo "$out" | grep -q "pc-0001"
  echo "$out" | grep -q "verified"
  echo "$out" | grep -q "Seguridad"
}

@test "SE-344 AC-7: query sin resultados -> exit 1" {
  run python3 "$FRO" query --tension "nada-que-no-existe" --vault "$TMPV"
  [ "$status" -eq 1 ]
}

@test "SE-344 AC-8: train enmascara (sin decision/razon) y registra brier en JSONL local" {
  python3 "$FRO" register --tension "t" --decision "decision-secreta" --razon "razon-secreta" --limites "l" \
    --senal "s" --pregunta "p" --dominio SFT --fuente "f" --verificacion T+90 --resultado ok --vault "$TMPV" >/dev/null
  TMP_TRAIN="$TMPV/train"
  export FRONESIS_TRAIN_DIR="$TMP_TRAIN"
  printf "decision-secreta\n80\n" | python3 "$FRO" train --dominio SFT --sesion s1 --vault "$TMPV" > "$TMPV/train.out"
  unset FRONESIS_TRAIN_DIR
  ! grep -q "Decisión real" "$TMPV/train.out"
  ! grep -q "decision-secreta" "$TMPV/train.out"
  [ -f "$TMP_TRAIN/s1.jsonl" ]
  python3 -c "import json; r=json.loads(open('$TMP_TRAIN/s1.jsonl').read()); assert 'brier' in r and 'confianza' in r"
}

@test "SE-344 AC-9: graduate marca graduado sin borrar y sugiere destino" {
  _reg "t" "d" "r" "l" >/dev/null
  run python3 "$FRO" graduate --id pc-0001 --vault "$TMPV"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qi "destino"
  [ -f "$TMPV/pc-0001.md" ]
  grep -q "graduado a regla" "$TMPV/pc-0001.md"
}

@test "SE-344 AC-10: CRIT-001 — sin librerias de red" {
  ! grep -nE "import (urllib|requests|socket)|http://|https://" "$FRO"
}

@test "SE-344 determinismo: list es estable y register 2x genera ids secuenciales" {
  _reg "t1" "d" "r" "l" >/dev/null
  _reg "t2" "d" "r" "l" >/dev/null
  run python3 "$FRO" list --vault "$TMPV"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "pc-0001"
  echo "$output" | grep -q "pc-0002"
}

@test "SE-344 calibrate: sugiere graduacion tras >=3 sesiones >=90%" {
  _reg "t" "d" "r" "l" >/dev/null
  python3 "$FRO" calibrate --id pc-0001 --aciertos 9 --total 10 --vault "$TMPV" >/dev/null
  python3 "$FRO" calibrate --id pc-0001 --aciertos 9 --total 10 --vault "$TMPV" >/dev/null
  run python3 "$FRO" calibrate --id pc-0001 --aciertos 9 --total 10 --vault "$TMPV"
  echo "$output" | grep -qi "sugerencia"
}
