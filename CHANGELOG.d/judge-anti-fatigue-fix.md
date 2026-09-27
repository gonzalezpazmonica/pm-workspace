---
bump: patch
section: Fixed
---

- `judge-anti-fatigue.sh` (SE-273): `reset` no reseteaba (el contador ignoraba el evento), `summary` contaba los eventos de escalado como verdicts ignorados, un `verdict_id` llamado "ignored" contaba como ignorado y `record` sin argumentos fallaba por variable sin asignar. Su suite tenía asserts que siempre pasaban y escribía en `output/` del repo.
