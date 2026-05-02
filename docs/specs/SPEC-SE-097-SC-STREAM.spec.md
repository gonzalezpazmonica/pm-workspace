# Spec: SaviaClaw Streaming — Progressive Message Feedback

**Task ID:**        SPEC-SE-097-SC-STREAM
**PBI padre:**      Era 197 — SaviaClaw Autonomy
**Sprint:**         2026-05
**Fecha creacion:** 2026-05-02
**Creado por:**     Savia (analisis Hermes Agent streaming)

**Estimacion agent:** ~30 min
**Prioridad:** ALTA

---

## Problema

SaviaClaw responde "Procesando..." y luego silencio hasta que la tarea termina (o no).
Hermes Agent usa `edit_message` progresivo con cursor `▉` y texto acumulativo.
OpenClaw usa streaming de bloques parciales vía WebSocket.

Talk API no soporta `edit_message`, pero podemos emular feedback progresivo con
mensajes que se auto-reemplazan conceptualmente (enviar actualizaciones periódicas
con prefijo que el usuario reconozca como progreso de la misma tarea).

**Objetivo:** SaviaClaw debe dar feedback visible durante la ejecución de tareas largas.

## Requisitos

- **REQ-01** Durante `opencode run`, SaviaClaw captura stdout línea a línea.
  Cada línea que contiene texto significativo del modelo se envía a Talk con prefijo `▸`.

- **REQ-02** `_run_opencode_streaming()` — nueva función que usa `subprocess.Popen` en
  lugar de `subprocess.run`, leyendo stdout incrementalmente:
  ```python
  proc = subprocess.Popen(["opencode", "run", prompt], stdout=PIPE, stderr=PIPE,
                           text=True, bufsize=1, env={**env, "TERM": "dumb"})
  for line in proc.stdout:
      clean = line.strip()
      if clean and not clean.startswith("\x1b"):
          send_message(f"▸ {clean[:200]}")
  ```

- **REQ-03** Rate limit: máximo un mensaje de progreso cada 5 segundos para no saturar Talk.

- **REQ-04** Mensaje final sin prefijo — cuando la tarea termina, se envía el resultado
  completo como mensaje normal.

- **REQ-05** Si la tarea falla (timeout, error), se envía "✗ No pude completarlo: {error}".

## AC

- **AC-01** Tarea larga → Mónica ve mensajes "▸ Leyendo archivos...", "▸ Creando zip...",
  "▸ Enviando email..." en tiempo real.
- **AC-02** Máximo 1 mensaje cada 5s (rate limit).
- **AC-03** Resultado final sin prefijo "▸".
