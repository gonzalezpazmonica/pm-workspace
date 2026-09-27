---
bump: patch
section: Fixed
---

- Locale numérico: 16 scripts formateaban decimales con `printf`/`awk` sin fijar el locale; con `es_ES` emitían coma decimal, rompiendo el JSON y las comparaciones de umbral (`delta-tier` clasificaba una desviación de 49000 como `amber` en vez de `red`). Ahora fijan `LC_NUMERIC=C` y, si `LC_ALL` está definido, lo trasladan a `LANG` para que no anule la fijación. Nuevo `tests/test-numeric-locale.bats` con guarda para todo el repo.
