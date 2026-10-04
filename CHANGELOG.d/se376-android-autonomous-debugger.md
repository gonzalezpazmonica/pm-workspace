---
version_bump: patch
section: Fixed
---

### Fixed

- android-autonomous-debugger calibrada contra un adb falso: adb-run.sh ya no evalúa sus argumentos (inyección de shell), adb_type/adb_tap/adb_key validan o escapan lo que llega al shell del dispositivo, logcat usa la ventana real de N segundos y no filtra por pid=0 tras un crash, tap_id/tap_text buscan el id y el texto exactos, las capturas no dan por buena una imagen antigua y 40 tests en tests/test-android-autonomous-debugger.bats

