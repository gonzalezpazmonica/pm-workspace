import { useCallback, useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";

/* Pre-record source preview. Opens the picked source(s) backend-side without
   recording so the user can confirm levels are flowing, polls peak levels at
   5 Hz, and stops the preview on deselection/unmount. Suspended while a
   recording is live — the live meters take over there.

   `clear()` resets the preview before starting a real recording so the
   preview stream releases the devices first. */
export function useAudioSourcePreview(
  micId: string,
  loopId: string,
  isLive: boolean,
) {
  const [micPeakDb, setMicPeakDb] = useState<number | null>(null);
  const [loopbackPeakDb, setLoopbackPeakDb] = useState<number | null>(null);
  const activeKey = useRef<string>("");

  // Drive the source preview from the currently-picked dropdown values.
  useEffect(() => {
    if (isLive) {
      activeKey.current = "";
      api.recordingsPreviewStop().catch(() => {});
      setMicPeakDb(null);
      setLoopbackPeakDb(null);
      return;
    }
    const key = `${micId || "-"}|${loopId || "-"}`;
    if (key === "-|-") {
      activeKey.current = "";
      api.recordingsPreviewStop().catch(() => {});
      setMicPeakDb(null);
      setLoopbackPeakDb(null);
      return;
    }
    activeKey.current = key;
    let cancelled = false;
    (async () => {
      const result = await api
        .recordingsPreviewStart(
          micId ? Number(micId) : null,
          loopId ? Number(loopId) : null,
        )
        .catch((err: unknown) => {
          console.warn("preview start failed", err);
          return { ok: false } as const;
        });
      if (cancelled || activeKey.current !== key) return;
      if (!result.ok) {
        setMicPeakDb(null);
        setLoopbackPeakDb(null);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [micId, loopId, isLive]);

  // Always release the preview stream on unmount.
  useEffect(() => {
    return () => {
      api.recordingsPreviewStop().catch(() => {});
    };
  }, []);

  // Poll peak levels while a preview is active.
  useEffect(() => {
    if (isLive) return;
    const hasAny = micId !== "" || loopId !== "";
    if (!hasAny) return;
    let cancelled = false;
    const tick = async () => {
      try {
        const st = await api.recordingsPreviewState();
        if (cancelled) return;
        setMicPeakDb(st.hasMic ? st.micPeakDb : null);
        setLoopbackPeakDb(st.hasLoopback ? st.loopbackPeakDb : null);
      } catch {
        /* RPC blip — keep last value. */
      }
    };
    tick();
    const id = window.setInterval(tick, 200);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [micId, loopId, isLive]);

  const clear = useCallback(() => {
    activeKey.current = "";
    api.recordingsPreviewStop().catch(() => {});
    setMicPeakDb(null);
    setLoopbackPeakDb(null);
  }, []);

  return { micPeakDb, loopbackPeakDb, clear };
}
