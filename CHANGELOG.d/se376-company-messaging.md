---
version_bump: patch
section: Fixed
---

### Fixed

- company-messaging calibrada (SE-376): savia-branch.sh ya no traga pushes fallidos (write/ensure-orphan devuelven error) ni pierde mensajes cuando la rama local está obsoleta (base en origin y reintento ante rechazo); send resuelve el directorio en formato tabla con coincidencia exacta y valida handles; inbox ya no aborta (CYAN) ni duplica rutas; read mueve de unread a read sin reentrega; broadcast con IDs únicos; savia-crypto cifra textos con forma de opción, vacío sin leer stdin y descifra por stdin paquetes >128 KB; privacy-check detecta claves PEM (grep -e), se aplica en send/announce y escanea por rama. privacy-check ya no falla en abierto con mensajes de más de 64 KiB (SIGPIPE con pipefail; here-strings); el secreto AES va por fichero y el cuerpo por stdin, nunca por argv (descifra también el formato anterior); send refresca main antes de usar directorio y claves; inbox avisa si no alcanza el remoto; reintentos de push con espera aleatoria. el cuerpo del mensaje ya no se acepta en argv: send/reply/announce/broadcast lo leen de stdin o de --body-file (0600), y savia-branch.sh write acepta el contenido por stdin (-). tests/test-company-messaging.bats (47 tests, auditor 88).

