#!/usr/bin/env python3
"""goal-service.py — SE-326 S4: objetivo durable por sesión.

Inspirado en deepseek-harness packages/goal/goal (SE-326).

Fases: active | paused | blocked | complete. Cada mutación durable incrementa
`revision`; el caller pasa el ref esperado (id + revision) o falla con
version-conflict. `blocked` exige blocked_reason {code, message}. `clear`
retiene tombstone (el id no se reutiliza).

Uso:
  goal-service.py <session> create --objective "..." [--max-goal-rounds N]
  goal-service.py <session> edit <id> <revision> [--objective "..."] [--max-goal-rounds N]
  goal-service.py <session> pause <id> <revision>
  goal-service.py <session> resume <id> <revision>
  goal-service.py <session> complete <id> <revision>
  goal-service.py <session> block <id> <revision> --code <kebab> --message "..."
  goal-service.py <session> clear <id> <revision>
  goal-service.py <session> get
  goal-service.py <session> admit-round <id> <revision>   # atribuye un turno admitido

Exit codes: 0 OK, 3 version-conflict, 4 not-found, 5 invalid-request.
"""

import argparse
import json
import os
import sys
import time

DEFAULT_MAX_ROUNDS = 10
PHASES = ("active", "paused", "blocked", "complete")
ALLOWED_OPS = ("create", "edit", "pause", "resume", "complete", "block", "clear")

STATE_ROOT = os.environ.get("GOAL_STATE_ROOT", "output/goals")


def state_path(session: str) -> str:
    return os.path.join(STATE_ROOT, f"{session}.json")


def load(session: str) -> dict:
    path = state_path(session)
    if not os.path.exists(path):
        return {"goals": [], "next_id": 1}
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {"goals": [], "next_id": 1}


def save(session: str, state: dict) -> None:
    path = state_path(session)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def current_goal(state: dict) -> dict | None:
    for g in state["goals"]:
        if g.get("phase") != "cleared":
            return g
    return None


def find_goal(state: dict, goal_id: int) -> dict | None:
    for g in state["goals"]:
        if g.get("id") == goal_id:
            return g
    return None


def fail(code: int, message: str) -> int:
    print(json.dumps({"ok": False, "error": {"code": code, "message": message}}))
    return code


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("session")
    parser.add_argument("op")
    parser.add_argument("--objective", default="")
    parser.add_argument("--max-goal-rounds", type=int, default=0)
    parser.add_argument("--code", default="")
    parser.add_argument("--message", default="")
    parser.add_argument("--id", type=int, default=0)
    parser.add_argument("--revision", type=int, default=0)
    args = parser.parse_args()

    session = args.session
    op = args.op

    if op not in ALLOWED_OPS and op != "get" and op != "admit-round":
        return fail(5, f"operación no permitida: {op}")

    state = load(session)
    now = int(time.time() * 1000)

    if op == "create":
        if not args.objective.strip():
            return fail(5, "objective es obligatorio")
        cur = current_goal(state)
        if cur and cur["phase"] not in ("complete",):
            return fail(5, f"ya hay un goal activo (id {cur['id']}, fase {cur['phase']}) — clear o complete antes")
        max_rounds = args.max_goal_rounds or DEFAULT_MAX_ROUNDS
        goal = {
            "id": state["next_id"],
            "revision": 1,
            "phase": "active",
            "objective": args.objective.strip(),
            "max_goal_rounds": max_rounds,
            "rounds_started": 0,
            "created_at": now,
            "updated_at": now,
            "blocked_reason": None,
        }
        state["goals"].append(goal)
        state["next_id"] += 1
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    goal_id = args.id
    revision = args.revision
    goal = find_goal(state, goal_id)

    if op == "get":
        print(json.dumps({"ok": True, "goal": current_goal(state)}))
        return 0

    if goal is None or goal.get("phase") == "cleared":
        return fail(4, f"goal {goal_id} no encontrado")

    if op == "admit-round":
        if goal["revision"] != revision:
            return fail(3, f"version-conflict: esperaba rev {revision}, actual {goal['revision']}")
        if goal["phase"] != "active":
            return fail(5, f"goal no activo (fase {goal['phase']}) — no admite rondas")
        if goal["rounds_started"] >= goal["max_goal_rounds"]:
            goal["phase"] = "blocked"
            goal["blocked_reason"] = {"code": "round-cap-reached", "message": f"cap {goal['max_goal_rounds']} alcanzado"}
            goal["revision"] += 1
            goal["updated_at"] = now
            save(session, state)
            print(json.dumps({"ok": True, "goal": goal, "blocked": True}))
            return 0
        goal["rounds_started"] += 1
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if goal["revision"] != revision:
        return fail(3, f"version-conflict: esperaba rev {revision}, actual {goal['revision']}")

    if op == "edit":
        changed = False
        if args.objective.strip() and args.objective.strip() != goal["objective"]:
            goal["objective"] = args.objective.strip()
            changed = True
        if args.max_goal_rounds and args.max_goal_rounds != goal["max_goal_rounds"]:
            goal["max_goal_rounds"] = args.max_goal_rounds
            changed = True
        if not changed:
            return fail(5, "edit requiere al menos un campo")
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if op == "pause":
        if goal["phase"] != "active":
            return fail(5, f"no se puede pausar goal en fase {goal['phase']}")
        goal["phase"] = "paused"
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if op == "resume":
        if goal["phase"] not in ("active", "paused", "blocked"):
            return fail(5, f"no se puede reanudar goal en fase {goal['phase']}")
        if goal["phase"] == "blocked" and goal["rounds_started"] >= goal["max_goal_rounds"]:
            return fail(5, "round budget agotado — no se puede reanudar")
        goal["phase"] = "active"
        goal["blocked_reason"] = None
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if op == "complete":
        if goal["phase"] == "complete":
            return fail(5, "goal ya completado")
        goal["phase"] = "complete"
        goal["blocked_reason"] = None
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if op == "block":
        if not args.code.strip() or not args.message.strip():
            return fail(5, "block exige --code y --message no vacíos")
        goal["phase"] = "blocked"
        goal["blocked_reason"] = {"code": args.code.strip(), "message": args.message.strip()}
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "goal": goal}))
        return 0

    if op == "clear":
        goal["phase"] = "cleared"
        goal["cleared_at"] = now
        goal["revision"] += 1
        goal["updated_at"] = now
        save(session, state)
        print(json.dumps({"ok": True, "tombstone": {"id": goal["id"], "revision": goal["revision"]}}))
        return 0

    return fail(5, f"operación no permitida: {op}")


if __name__ == "__main__":
    sys.exit(main())
