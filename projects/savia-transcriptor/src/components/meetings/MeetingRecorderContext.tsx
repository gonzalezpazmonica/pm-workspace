/* React context that tracks active-recording state across the dashboard.

   No polling. The backend pushes `meeting-state` events through Qt
   WebChannel (Pyloid's `window.invoke`) at 4 Hz while a recording is active.
   These arrive as `document` CustomEvent named `meeting-state` with detail =
   { state, durationMs, recordingId, micPeakDb, loopbackPeakDb }.

   This transport survives Chromium renderer freezes — the same freezes that
   killed the old HTTP-poll loop. Plus it eliminates the 34 % CPU hit the
   poll was costing the Python process.

   The visible `state.durationMs` is still wall-clock derived (same trick the
   popup pill uses) so the displayed counter never lies even if backend
   events are momentarily sparse or the renderer hiccups.

   Start / Stop / Pause commands still go over HTTP RPC for now — adding a
   custom Qt WebChannel slot for those is a larger change and the tray-menu
   "Stop active recording" is the throttling-immune escape hatch for the
   freeze case. */

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { api } from "@/lib/api";
import { useBackendEvent } from "@/hooks/useBackendEvent";
import type { RecorderState, RecorderStateName } from "@/lib/types";

interface RecorderContextValue {
  state: RecorderState;
  isLive: boolean;
  /** Force a re-fetch of the recorder state. Used by handleStart/handleStop
   *  to do a one-shot probe immediately after issuing a command, before the
   *  next push tick arrives. */
  refresh: () => Promise<void>;
}

const IDLE: RecorderState = {
  state: "idle",
  recordingId: null,
  durationMs: 0,
  micPeakDb: null,
  loopbackPeakDb: null,
};

const TICK_INTERVAL_MS = 250;

interface MeetingStateEvent {
  state: RecorderStateName;
  durationMs: number;
  recordingId: number | null;
  micPeakDb: number | null;
  loopbackPeakDb: number | null;
}

interface SyncBase {
  /** Wall-clock `Date.now()` at the moment we received `durationMs`. */
  at: number;
  /** Backend-reported duration at `at`. */
  durationMs: number;
}

const Context = createContext<RecorderContextValue>({
  state: IDLE,
  isLive: false,
  refresh: async () => {},
});

export function MeetingRecorderProvider({ children }: { children: ReactNode }) {
  const [pushedState, setPushedState] = useState<RecorderState>(IDLE);
  // `tick` exists only to trigger re-renders for the wall-clock duration
  // ticker. The value itself doesn't matter.
  const [tick, setTick] = useState(0);
  const syncBase = useRef<SyncBase>({ at: Date.now(), durationMs: 0 });

  const applyState = useCallback((next: RecorderState) => {
    // Re-anchor the wall-clock timer whenever a fresh duration arrives.
    // Paused/idle freeze the anchor (no advancing while paused).
    syncBase.current = { at: Date.now(), durationMs: next.durationMs };
    setPushedState(next);
  }, []);

  // One-shot probe — used at mount (so the sidebar reflects an in-progress
  // recording recovered from a previous session) and right after Start/Stop
  // commands as a safety net in case the first push event hasn't arrived
  // yet. NOT called on a timer.
  const refresh = useCallback(async () => {
    try {
      const next = await api.recordingsGetRecorderState();
      applyState(next);
    } catch (err) {
      // First time only — if refresh keeps failing the push events will
      // bring state in anyway.
      console.warn("[recorder] refresh probe failed:", err);
    }
  }, [applyState]);

  // Listen for backend push events. This is the primary state channel.
  useBackendEvent<MeetingStateEvent>("meeting-state", (detail) => {
    if (!detail || typeof detail.state !== "string") return;
    applyState({
      state: detail.state,
      recordingId: detail.recordingId ?? null,
      durationMs: Number(detail.durationMs ?? 0),
      micPeakDb: detail.micPeakDb ?? null,
      loopbackPeakDb: detail.loopbackPeakDb ?? null,
    });
  });

  // Initial probe at mount — covers two cases:
  //   - Page just loaded mid-recording (e.g. after dev-server hot-reload),
  //     no push event arrives until the next 250 ms tick.
  //   - Crash-recovered recording that already finished — state is idle but
  //     we want the right initial values.
  useEffect(() => {
    refresh();
  }, [refresh]);

  const isLive =
    pushedState.state === "recording" || pushedState.state === "paused";

  // Wall-clock ticker — only runs while actively recording so paused
  // duration stays frozen at whatever the backend last reported.
  useEffect(() => {
    if (pushedState.state !== "recording") return;
    const id = window.setInterval(() => {
      setTick((n) => n + 1);
    }, TICK_INTERVAL_MS);
    return () => window.clearInterval(id);
  }, [pushedState.state]);

  // Derive the visible state. Duration is wall-clock interpolated when
  // recording, frozen when paused, zero when idle.
  const state = useMemo<RecorderState>(() => {
    if (pushedState.state === "recording") {
      return {
        ...pushedState,
        durationMs:
          syncBase.current.durationMs + (Date.now() - syncBase.current.at),
      };
    }
    return pushedState;
  }, [pushedState, tick]);

  const value = useMemo(
    () => ({ state, isLive, refresh }),
    [state, isLive, refresh],
  );

  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function useMeetingRecorder(): RecorderContextValue {
  return useContext(Context);
}
