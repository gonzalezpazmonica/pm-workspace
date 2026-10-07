---
bump: patch
section: Fixed
---

- `sovereignty-classify.sh`: el detector `dni_nif` marcaba como confidencial (0,99) cualquier secuencia de 8 dígitos seguida de una letra, por lo que bloqueaba código legítimo como el alfabeto de códigos de emparejamiento `"23456789ABCDEFGHJKMNPQRSTVWXYZ"`. Ahora solo cuenta si la letra es la de control (`TRWAGMYFPDXBNJZSQVHLCKE[n % 23]`, sin distinguir mayúsculas) y cubre también el NIE (X/Y/Z = 0/1/2 + 7 dígitos + letra). Los fixtures sintéticos de DNI del corpus del clasificador y de la línea base de hooks pasan a usar un DNI con letra válida.
