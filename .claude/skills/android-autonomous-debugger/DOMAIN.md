# Android Autonomous Debugger — Dominio

## Por que existe esta skill

Depurar aplicaciones Android en dispositivos fisicos requiere ciclos manuales repetitivos de instalacion, interaccion y captura de errores. Esta skill automatiza el ciclo completo via ADB, permitiendo que un agente instale, navegue, capture screenshots y diagnostique crashes sin intervencion humana, reduciendo el tiempo de verificacion de minutos a segundos.

## Conceptos de dominio

- **ADB (Android Debug Bridge)**: herramienta CLI que permite comunicarse con dispositivos Android conectados por USB
- **adb-run.sh**: wrapper que encapsula multiples funciones ADB en una sola invocacion, evitando problemas de permisos con cadenas de comandos
- **Ciclo autonomo**: secuencia Setup, Install, Interact, Verify, Report que el agente ejecuta sin intervencion
- **UI Hierarchy**: arbol XML del layout actual de la pantalla que permite localizar elementos por ID o texto
- **Modelo de seguridad**: clasificacion de operaciones ADB en Safe (screenshot), Risky (install) y Blocked (rm -rf)

## Reglas de negocio que implementa

- Siempre usar adb-run.sh como comando unico, nunca cadenas con source y operadores logicos
- Screenshots obligatorios antes y despues de cada interaccion como evidencia
- Usar adb_wait_for_text en vez de sleep para sincronizacion con la UI
- Operaciones bloqueadas (rm -rf, su, dd, format) siempre rechazadas por el hook de validacion

## Relacion con otras skills

- **Upstream**: spec-driven-development (specs definen los escenarios a verificar en dispositivo)
- **Downstream**: visual-quality (analisis de los screenshots capturados), code-improvement-loop (fixes basados en crashes)
- **Paralelo**: test-architect (diseno de tests E2E que el debugger ejecuta)

## Decisiones clave

- Wrapper adb-run.sh en vez de llamadas directas a ADB para evitar el bloqueo del sistema de permisos de Claude Code con cadenas de operadores logicos
- Clasificacion de seguridad en 3 niveles en vez de whitelist/blacklist para permitir operaciones utiles sin comprometer la seguridad
- Screenshots como evidencia principal en vez de solo logs porque los errores visuales no aparecen en logcat
