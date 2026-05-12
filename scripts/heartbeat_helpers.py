"""SPEC-SH03 — heartbeat IPC helpers.

Shared utilities for daemon handlers and clients to implement the
heartbeat protocol defined in SPEC-SH03.

Daemon handlers (browser-daemon.py):
    hb = HeartbeatWriter(result_path, account, op)
    hb.start()
    hb.update(phase="day-1/3", processed=0, total=N)
    ... do work ...
    hb.update(phase="day-2/3", processed=20)
    hb.terminal_done(extra={"events": [...], "count": 42})

Clients (calendar_72h.py, inbox-check.py, teams-check.py):
    poll = HeartbeatPoller(result_path, op="check-calendar",
                           hard_cap_s=600)
    final = poll.run_until_terminal()    # blocks, prints HEARTBEAT/RESULT
    sys.exit(poll.exit_code)             # 0/10/11/12

Exit code table (AC-2.2):
    0   done
    10  session_expired (NEEDS_AUTH)
    11  error
    12  stall (no terminal before client hard-cap)

Orchestrator (project-update.py):
    Reads stdout line-by-line, looks for:
      HEARTBEAT op=X phase=Y processed=N[/T] elapsed=Ts
      RESULT <one-line-json-or-path>
      LOG <free text>
    Stall detection on lines other than HEARTBEAT/RESULT.
"""
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, Optional

SCHEMA = "1"
HEARTBEAT_INTERVAL_S = 5.0   # AC-1.2: at least every 5s OR per-item
POLL_INTERVAL_S = 1.0        # AC-2.1: client polls 1Hz
DEFAULT_CLIENT_HARD_CAP_S = 600  # AC-2.2: client own hard-cap


def _atomic_write_json(path: Path, payload: Dict[str, Any]) -> None:
    """AC-1.3: write+rename atomic write so readers never see partial JSON."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


class HeartbeatWriter:
    """Daemon-side: write atomic intermediate result.json with progress.

    Used inside browser-daemon handlers (check-mail, check-calendar,
    check-teams). Single-writer per (alias, op): the handler.
    """

    def __init__(self, result_path: Path, account: str, op: str,
                 trace_path: Optional[Path] = None) -> None:
        self.path = Path(result_path)
        self.account = account
        self.op = op
        self.trace_path = trace_path  # optional jsonl trace (AC-6.1)
        self.started_at = _now_iso()
        self._processed = 0
        self._total: Optional[int] = None
        self._phase = "init"
        self._last_write = 0.0

    def _base_payload(self) -> Dict[str, Any]:
        out: Dict[str, Any] = {
            "schema": SCHEMA,
            "account": self.account,
            "op": self.op,
            "started_at": self.started_at,
            "last_event_ts": _now_iso(),
            "phase": self._phase,
            "processed": self._processed,
        }
        if self._total is not None:
            out["total"] = self._total
        return out

    def _trace(self, event: str, extra: Optional[Dict[str, Any]] = None) -> None:
        if not self.trace_path:
            return
        try:
            self.trace_path.parent.mkdir(parents=True, exist_ok=True)
            line = {
                "ts": _now_iso(),
                "event": event,
                "phase": self._phase,
                "processed": self._processed,
            }
            if extra:
                line.update(extra)
            with open(self.trace_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(line, ensure_ascii=False) + "\n")
        except Exception:
            # trace is best-effort; never break the handler
            pass

    def start(self) -> None:
        self._phase = "starting"
        payload = self._base_payload()
        payload["status"] = "running"
        payload["partial"] = True
        _atomic_write_json(self.path, payload)
        self._last_write = time.time()
        self._trace("start")

    def update(self, phase: Optional[str] = None,
               processed: Optional[int] = None,
               total: Optional[int] = None,
               force: bool = False) -> None:
        """Update progress. Writes if >= HEARTBEAT_INTERVAL_S elapsed,
        or when phase changes, or when force=True."""
        phase_changed = phase is not None and phase != self._phase
        if phase is not None:
            self._phase = phase
        if processed is not None:
            self._processed = processed
        if total is not None:
            self._total = total
        if not force and not phase_changed and \
           (time.time() - self._last_write) < HEARTBEAT_INTERVAL_S:
            return
        payload = self._base_payload()
        payload["status"] = "running"
        payload["partial"] = True
        _atomic_write_json(self.path, payload)
        self._last_write = time.time()
        self._trace("hb")

    def terminal_done(self, extra: Optional[Dict[str, Any]] = None) -> None:
        payload = self._base_payload()
        payload["status"] = "done"
        payload["ended_at"] = _now_iso()
        payload["partial"] = False
        if extra:
            payload.update(extra)
        _atomic_write_json(self.path, payload)
        self._trace("done")

    def terminal_session_expired(self, needs_auth_url: Optional[str] = None,
                                  extra: Optional[Dict[str, Any]] = None) -> None:
        payload = self._base_payload()
        payload["status"] = "session_expired"
        payload["ended_at"] = _now_iso()
        payload["partial"] = True
        if needs_auth_url:
            payload["needs_auth_url"] = needs_auth_url
        if extra:
            payload.update(extra)
        _atomic_write_json(self.path, payload)
        self._trace("session_expired")

    def terminal_error(self, error: str,
                       extra: Optional[Dict[str, Any]] = None) -> None:
        payload = self._base_payload()
        payload["status"] = "error"
        payload["ended_at"] = _now_iso()
        payload["partial"] = True
        payload["error"] = (error or "")[:500]
        if extra:
            payload.update(extra)
        _atomic_write_json(self.path, payload)
        self._trace("error", {"error": payload["error"]})


class HeartbeatPoller:
    """Client-side: poll result file, emit HEARTBEAT/RESULT lines, return final.

    Compatible with old daemons that write a single terminal payload
    (legacy mode): in that case no intermediate states arrive, the poller
    emits one synthetic HEARTBEAT periodically so the orchestrator does
    not stall, then sees the terminal.
    """

    EXIT_DONE = 0
    EXIT_SESSION_EXPIRED = 10
    EXIT_ERROR = 11
    EXIT_STALL = 12

    def __init__(self, result_path: Path, op: str,
                 hard_cap_s: float = DEFAULT_CLIENT_HARD_CAP_S,
                 stream: Any = None) -> None:
        self.path = Path(result_path)
        self.op = op
        self.hard_cap_s = hard_cap_s
        # AC-2.3: orchestrator parses stdout. We default to stdout.
        self.stream = stream or sys.stdout
        self.exit_code = self.EXIT_STALL
        self._started = time.time()
        self._last_processed = -1
        self._last_phase = ""
        self._last_status = ""
        self._last_legacy_hb = 0.0

    def _emit(self, line: str) -> None:
        try:
            self.stream.write(line + "\n")
            self.stream.flush()
        except Exception:
            pass

    def _emit_heartbeat(self, phase: str, processed: int,
                        total: Optional[int]) -> None:
        elapsed = int(time.time() - self._started)
        if total is not None:
            prog = "{}/{}".format(processed, total)
        else:
            prog = str(processed)
        self._emit("HEARTBEAT op={} phase={} processed={} elapsed={}s".format(
            self.op, phase or "?", prog, elapsed))

    def _emit_legacy_heartbeat(self) -> None:
        elapsed = int(time.time() - self._started)
        self._emit("HEARTBEAT op={} phase=waiting processed=0 elapsed={}s".format(
            self.op, elapsed))

    def _read_state(self) -> Optional[Dict[str, Any]]:
        if not self.path.exists():
            return None
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return None

    def run_until_terminal(self) -> Dict[str, Any]:
        """Block until terminal status or hard-cap. Returns last state."""
        last_state: Dict[str, Any] = {}
        while True:
            elapsed = time.time() - self._started
            if elapsed > self.hard_cap_s:
                self.exit_code = self.EXIT_STALL
                self._emit("LOG client_hard_cap_reached after={}s".format(
                    int(elapsed)))
                return last_state

            state = self._read_state()
            if state is not None:
                last_state = state
                status = state.get("status", "")
                phase = state.get("phase", "")
                processed = int(state.get("processed", 0) or 0)
                total = state.get("total")

                # Emit heartbeat on any change (phase, processed, status)
                changed = (phase != self._last_phase or
                           processed != self._last_processed or
                           status != self._last_status)
                if changed and status == "running":
                    self._emit_heartbeat(phase, processed, total)
                    self._last_phase = phase
                    self._last_processed = processed
                    self._last_status = status
                    self._last_legacy_hb = time.time()

                if status == "done":
                    self.exit_code = self.EXIT_DONE
                    self._emit_heartbeat(phase or "done", processed, total)
                    self._emit("RESULT " + json.dumps(state, ensure_ascii=False))
                    return state
                if status == "session_expired":
                    self.exit_code = self.EXIT_SESSION_EXPIRED
                    self._emit("RESULT " + json.dumps(state, ensure_ascii=False))
                    return state
                if status == "error":
                    self.exit_code = self.EXIT_ERROR
                    self._emit("RESULT " + json.dumps(state, ensure_ascii=False))
                    return state

            # Legacy fallback: result file does not exist OR has no schema.
            # Emit a synthetic heartbeat every HEARTBEAT_INTERVAL_S so the
            # orchestrator does not interpret silence as stall.
            if (time.time() - self._last_legacy_hb) >= HEARTBEAT_INTERVAL_S:
                self._emit_legacy_heartbeat()
                self._last_legacy_hb = time.time()

            time.sleep(POLL_INTERVAL_S)


def emit_log(msg: str, stream: Any = None) -> None:
    """Emit a LOG line for orchestrator (informational, no stall reset)."""
    s = stream or sys.stdout
    try:
        s.write("LOG " + msg + "\n")
        s.flush()
    except Exception:
        pass
