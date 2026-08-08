import { useEffect, useState, useLayoutEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { api } from "@/lib/api";
import { useBackendEvent } from "@/hooks/useBackendEvent";

type PopupState =
  | "idle"
  | "recording"
  | "processing"
  | "meeting-recording"
  | "meeting-paused";

// Inline tokens. The popup loads with `transparent` overrides so utility
// classes can't reliably reach the surface, and the surface is always dark
// regardless of theme — so colors are pinned to fixed hexes that match the
// design tokens' visual character on a dark surface.
const ACCENT = "#8e6fbf"; // --primary-400 (Savia Web purple)
const ACCENT_DIM = "rgba(142, 111, 191, 0.7)";
const ACCENT_FAINT = "rgba(142, 111, 191, 0.18)";
// Destructive on dark surface. Same warm red the recorder page's REC dot
// resolves to in light mode (`--destructive` = #ef4444); a hair richer than
// the dark-mode variant so it pops against the popup's translucent black.
const REC_RED = "#ef4444";
const REC_RED_FAINT = "rgba(239, 68, 68, 0.18)";
const SURFACE = "rgba(9, 9, 11, 0.78)";
const BORDER = "rgba(255, 255, 255, 0.08)";

function formatMeetingDuration(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  const pad = (n: number) => (n < 10 ? `0${n}` : String(n));
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

// Compact display label per model. Keeps the pill narrow even for the
// long distilled/large variants.
function modelLabel(model: string | null): string {
  if (!model) return "";
  const m = model.toLowerCase();
  const map: Record<string, string> = {
    "tiny": "tiny",
    "base": "base",
    "small": "small",
    "medium": "med",
    "large-v1": "lg·v1",
    "large-v2": "lg·v2",
    "large-v3": "lg·v3",
    "turbo": "turbo",
    "tiny.en": "tiny·en",
    "base.en": "base·en",
    "small.en": "sm·en",
    "medium.en": "md·en",
    "distil-small.en": "ds·en",
    "distil-medium.en": "dm·en",
    "distil-large-v2": "dl·v2",
    "distil-large-v3": "dl·v3",
  };
  return map[m] ?? m;
}

export function Popup() {
  const [state, setState] = useState<PopupState>("idle");
  const [amplitude, setAmplitude] = useState(0);
  const [model, setModel] = useState<string | null>(null);
  const [meetingDurationMs, setMeetingDurationMs] = useState(0);
  // Base for the client-side timer: the duration the backend last reported,
  // and the wall-clock moment we received it. Local ticking interpolates
  // between backend updates so the counter feels live even if events are
  // sparse. Resets every backend `popup-state` event.
  const meetingBaseRef = useRef<{ at: number; dur: number }>({ at: 0, dur: 0 });
  const prefersReducedMotion = useRef(
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );

  useLayoutEffect(() => {
    document.documentElement.style.cssText =
      "background: transparent !important;";
    document.body.style.cssText =
      "background: transparent !important; margin: 0; padding: 0;";
    document.documentElement.classList.add("popup-transparent");

    const root = document.getElementById("root");
    if (root) {
      root.style.cssText = "background: transparent !important;";
    }
  }, []);

  // Fetch current model on mount, then re-fetch every 10s so the label
  // stays in sync if the user changes it from settings.
  useEffect(() => {
    let cancelled = false;
    const fetch = async () => {
      try {
        const s = await api.getSettings();
        if (!cancelled) setModel(s.model);
      } catch {
        // ignore - backend may not be ready yet
      }
    };
    fetch();
    const id = window.setInterval(fetch, 10_000);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, []);

  useBackendEvent<number>("amplitude", setAmplitude);
  useBackendEvent<{ state: PopupState; durationMs?: number }>(
    "popup-state",
    (detail) => {
      setState(detail.state);
      if (typeof detail.durationMs === "number") {
        meetingBaseRef.current = { at: Date.now(), dur: detail.durationMs };
        setMeetingDurationMs(detail.durationMs);
      }
    }
  );

  // Client-side meeting duration ticker. Runs only while actively recording
  // (paused → frozen at whatever the backend last reported). Resyncs whenever
  // a fresh `popup-state` event lands.
  useEffect(() => {
    if (state !== "meeting-recording") return;
    const id = window.setInterval(() => {
      const { at, dur } = meetingBaseRef.current;
      setMeetingDurationMs(dur + (Date.now() - at));
    }, 250);
    return () => window.clearInterval(id);
  }, [state]);

  const reduced = prefersReducedMotion.current;
  const label = modelLabel(model);

  return (
    <div
      className="w-screen h-screen flex items-center justify-center select-none"
      style={{ background: "transparent" }}
    >
      <AnimatePresence mode="wait">
        {state === "idle" && (
          <motion.div
            key="idle"
            initial={reduced ? false : { opacity: 0, scaleX: 0.6 }}
            animate={{ opacity: 1, scaleX: 1 }}
            exit={reduced ? { opacity: 0 } : { opacity: 0, scaleX: 0.6 }}
            transition={{ duration: 0.18, ease: [0.4, 0, 0.2, 1] }}
            style={{
              width: "32px",
              height: "4px",
              borderRadius: "2px",
              background: "rgba(255, 255, 255, 0.18)",
              transformOrigin: "center",
            }}
          />
        )}

        {state === "recording" && (
          <motion.div
            key="recording"
            initial={reduced ? false : { opacity: 0, y: 4, scale: 0.94 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={reduced ? { opacity: 0 } : { opacity: 0, y: -2, scale: 0.96 }}
            transition={{ duration: 0.22, ease: [0.4, 0, 0.2, 1] }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "5px 10px 5px 8px",
              borderRadius: "999px",
              background: SURFACE,
              border: `1px solid ${BORDER}`,
              backdropFilter: "blur(14px) saturate(140%)",
              WebkitBackdropFilter: "blur(14px) saturate(140%)",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.25)",
            }}
          >
            {/* Live red dot — recording indicator */}
            <span
              style={{
                width: "6px",
                height: "6px",
                borderRadius: "50%",
                background: ACCENT,
                boxShadow: `0 0 0 3px ${ACCENT_FAINT}`,
                animation: reduced ? "none" : "popup-pulse 1.2s ease-in-out infinite",
              }}
            />

            {/* Model label */}
            {label && (
              <span
                style={{
                  fontFamily:
                    "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
                  fontSize: "10px",
                  letterSpacing: "0.02em",
                  color: "rgba(255, 255, 255, 0.65)",
                  lineHeight: 1,
                }}
              >
                {label}
              </span>
            )}

            {/* Divider */}
            {label && (
              <span
                style={{
                  width: "1px",
                  height: "10px",
                  background: "rgba(255, 255, 255, 0.12)",
                }}
              />
            )}

            {/* Amplitude bars */}
            <div style={{ display: "flex", alignItems: "center", gap: "2px", height: "14px" }}>
              {[0, 1, 2, 3, 4].map((i) => {
                const center = 2;
                const distance = Math.abs(i - center);
                const scale = 1 - distance * 0.18;
                const height = Math.max(3, 3 + amplitude * 11 * scale);

                return (
                  <div
                    key={i}
                    style={{
                      width: "2px",
                      height: `${height}px`,
                      borderRadius: "1px",
                      background: ACCENT,
                      transition: "height 60ms cubic-bezier(0.4, 0, 0.2, 1)",
                    }}
                  />
                );
              })}
            </div>
          </motion.div>
        )}

        {(state === "meeting-recording" || state === "meeting-paused") && (
          <motion.div
            key="meeting"
            initial={reduced ? false : { opacity: 0, y: 4, scale: 0.94 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={reduced ? { opacity: 0 } : { opacity: 0, y: -2, scale: 0.96 }}
            transition={{ duration: 0.22, ease: [0.4, 0, 0.2, 1] }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "5px 12px 5px 8px",
              borderRadius: "999px",
              background: SURFACE,
              border: `1px solid ${BORDER}`,
              backdropFilter: "blur(14px) saturate(140%)",
              WebkitBackdropFilter: "blur(14px) saturate(140%)",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.25)",
            }}
          >
            {/* Dot + state label as one semantic unit. Matches the recorder
                page's header treatment so colour and word agree. */}
            <span
              style={{
                width: "6px",
                height: "6px",
                borderRadius: "50%",
                background:
                  state === "meeting-paused"
                    ? "rgba(250, 250, 250, 0.45)"
                    : REC_RED,
                boxShadow:
                  state === "meeting-paused"
                    ? "none"
                    : `0 0 0 3px ${REC_RED_FAINT}`,
                animation:
                  state === "meeting-recording" && !reduced
                    ? "popup-rec-pulse 1.6s cubic-bezier(0.215, 0.61, 0.355, 1) infinite"
                    : "none",
              }}
            />
            <span
              style={{
                fontFamily:
                  "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
                fontSize: "10px",
                fontWeight: 500,
                textTransform: "uppercase",
                letterSpacing: "0.25em",
                color:
                  state === "meeting-paused"
                    ? "rgba(250, 250, 250, 0.45)"
                    : REC_RED,
                lineHeight: 1,
              }}
            >
              {state === "meeting-paused" ? "paused" : "meeting"}
            </span>

            {/* Hairline divider — matches the dashboard's `h-px bg-border` rhythm. */}
            <span
              style={{
                width: "1px",
                height: "10px",
                background: "rgba(255, 255, 255, 0.12)",
              }}
            />

            {/* Duration in Clash Display tabular figures — same family as the
                recorder page timer, scaled down. */}
            <span
              style={{
                fontFamily:
                  "'Clash Display', system-ui, sans-serif",
                fontSize: "12px",
                fontWeight: 500,
                fontVariantNumeric: "tabular-nums",
                letterSpacing: "-0.01em",
                color:
                  state === "meeting-paused"
                    ? "rgba(250, 250, 250, 0.55)"
                    : "#fafafa",
                lineHeight: 1,
              }}
            >
              {formatMeetingDuration(meetingDurationMs)}
            </span>
          </motion.div>
        )}

        {state === "processing" && (
          <motion.div
            key="processing"
            initial={reduced ? false : { opacity: 0, y: 4, scale: 0.94 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={reduced ? { opacity: 0 } : { opacity: 0, y: -2, scale: 0.96 }}
            transition={{ duration: 0.22, ease: [0.4, 0, 0.2, 1] }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "8px",
              padding: "5px 12px 5px 10px",
              borderRadius: "999px",
              background: SURFACE,
              border: `1px solid ${BORDER}`,
              backdropFilter: "blur(14px) saturate(140%)",
              WebkitBackdropFilter: "blur(14px) saturate(140%)",
              boxShadow: "0 4px 20px rgba(0, 0, 0, 0.25)",
            }}
          >
            {/* Spinner */}
            <span
              style={{
                width: "10px",
                height: "10px",
                borderRadius: "50%",
                border: `1.5px solid ${ACCENT_FAINT}`,
                borderTopColor: ACCENT,
                animation: reduced ? "none" : "popup-spin 0.8s linear infinite",
              }}
            />

            {/* Model label */}
            {label && (
              <span
                style={{
                  fontFamily:
                    "'JetBrains Mono', ui-monospace, SFMono-Regular, Menlo, monospace",
                  fontSize: "10px",
                  letterSpacing: "0.02em",
                  color: "rgba(255, 255, 255, 0.65)",
                  lineHeight: 1,
                }}
              >
                {label}
              </span>
            )}

            {/* Divider */}
            {label && (
              <span
                style={{
                  width: "1px",
                  height: "10px",
                  background: "rgba(255, 255, 255, 0.12)",
                }}
              />
            )}

            {/* Wave-traveling dots */}
            <div style={{ display: "flex", alignItems: "center", gap: "3px" }}>
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  style={{
                    width: "3px",
                    height: "3px",
                    borderRadius: "50%",
                    background: ACCENT_DIM,
                    animation: reduced
                      ? "none"
                      : "popup-wave 1s ease-in-out infinite",
                    animationDelay: `${i * 0.15}s`,
                  }}
                />
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <style>{`
        @keyframes popup-pulse {
          0%, 100% {
            box-shadow: 0 0 0 3px ${ACCENT_FAINT};
            transform: scale(1);
          }
          50% {
            box-shadow: 0 0 0 5px rgba(34, 197, 94, 0.10);
            transform: scale(1.08);
          }
        }
        @keyframes popup-spin {
          to { transform: rotate(360deg); }
        }
        @keyframes popup-rec-pulse {
          0%   { box-shadow: 0 0 0 0   rgba(239, 68, 68, 0.45); }
          70%  { box-shadow: 0 0 0 8px rgba(239, 68, 68, 0);   }
          100% { box-shadow: 0 0 0 0   rgba(239, 68, 68, 0);   }
        }
        @keyframes popup-wave {
          0%, 100% {
            opacity: 0.35;
            transform: translateY(0);
          }
          50% {
            opacity: 1;
            transform: translateY(-2px);
          }
        }
      `}</style>
    </div>
  );
}
