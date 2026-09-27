---
bump: patch
section: Fixed
---

- 88 conteos con `grep -c ... || echo 0` en 51 scripts y hooks devolvían `0` repetido en dos líneas cuando no había coincidencias, rompiendo comparaciones y aritmética. Forma canónica: `grep -c ... || [ $? -eq 1 ] || echo 0`, con una guarda que impide reintroducir el patrón.
