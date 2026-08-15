#!/usr/bin/env bash
# Fixture target para el test de ejecucion real de mutation-audit (SE-035 Slice 2).
# La funcion add debe conservar su operador suma para que el mutador pueda matarlo.
add() { echo $(( "$1" + "$2" )); }

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  add "$@"
fi
