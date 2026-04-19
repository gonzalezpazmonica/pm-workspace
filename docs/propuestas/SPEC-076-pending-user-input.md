---
id: SPEC-076
title: SPEC-076: PENDING_USER_INPUT — Pausa/Reanuda en Agentes Autónomos
status: Proposed
origin_date: "2026-03-25"
migrated_at: "2026-04-19"
migrated_from: body-prose
---

# SPEC-076: PENDING_USER_INPUT — Pausa/Reanuda en Agentes Autónomos

> Status: **DRAFT** · Fecha: 2026-03-25 · Score: 3.40
> Origen: Qwen-Agent pattern "PENDING_USER_INPUT state"
> Impacto: Agentes autónomos pueden pedir input sin bloquear ni abortar

---

## Problema

Los agentes autónomos de pm-workspace (overnight-sprint, consciousness,
Savia Teams) tienen dos opciones cuando necesitan input: abortar o improvisar.
Qwen-Agent introduce un tercer estado: PENDING_USER_INPUT — el agente pausa,
notifica al humano, y reanuda cuando llega la respuesta.

## Solución

Protocolo de estado PENDING_USER_INPUT para agentes autónomos:

```
Agente detecta que necesita input para continuar
  ↓
1. Escribir estado en ~/.savia/zeroclaw/pending/{session-id}.json:
   { "agent": "overnight-sprint", "question": "...", "context": "...", "ts": ... }
2. Notificar via Talk: "Necesito tu ayuda con X. ¿Puedes responderme aquí?"
3. Agente pausa (sin abortar) y sale de la tarea actual
4. Cuando llega respuesta en Talk:
   - poll_and_respond detecta respuesta
   - Inyecta respuesta en {session-id}.json: { "answer": "..." }
   - Agente reanuda desde el estado guardado
```

## Implementación

### Estado en disco

```python
# En consciousness.py / overnight-sprint
PENDING_DIR = os.path.expanduser("~/.savia/zeroclaw/pending")

def request_user_input(session_id, question, context=""):
    os.makedirs(PENDING_DIR, exist_ok=True)
    state = {"agent": session_id, "question": question,
             "context": context, "status": "waiting", "ts": time.time()}
    with open(f"{PENDING_DIR}/{session_id}.json", "w") as f:
        json.dump(state, f)
    _notify(f"Necesito tu ayuda: {question}")

def check_pending_answer(session_id):
    path = f"{PENDING_DIR}/{session_id}.json"
    if not os.path.isfile(path):
        return None
    with open(path) as f:
        state = json.load(f)
    return state.get("answer")  # None si aún esperando
```

### Integración con nctalk.py

En `poll_and_respond()`, detectar si el mensaje es respuesta a un pending:

```python
# Si hay pendientes, inyectar la respuesta antes de llamar a claude
pending = glob.glob(f"{PENDING_DIR}/*.json")
for p in pending:
    with open(p) as f: state = json.load(f)
    if state.get("status") == "waiting":
        # La respuesta del usuario va al pending
        state["answer"] = q
        state["status"] = "answered"
        with open(p, "w") as f: json.dump(state, f)
        send_message("Gracias, continúo.")
        return  # No procesar como pregunta nueva
```

## Degradación

Sin Talk configurado → PENDING_USER_INPUT escribe en log y espera restart manual.
Sin respuesta en 24h → agente abandona tarea con nota en audit log.

## Tests

- Agente escribe pending → aparece fichero en PENDING_DIR
- Respuesta en Talk → fichero actualizado con answer
- Agente detecta answer → reanuda tarea desde contexto guardado
- Timeout 24h → entrada en audit log con estado "abandoned"
