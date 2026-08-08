/* Transcript segment list. Each row is the segment text prefixed by a small
   monospace `[mm:ss]` timestamp; clicking a row asks the audio player to
   seek to that segment's start. The active segment (matching audio playback
   position) is highlighted with a left edge mark, not a heavy background. */

import { useEffect, useMemo, useRef } from "react";
import type { RecordingSegment } from "@/lib/types";
import { cn } from "@/lib/utils";
import { findActiveSegment, formatTimestamp } from "./utils";

interface TranscriptViewProps {
  segments: RecordingSegment[];
  currentMs: number;
  onSeek(ms: number): void;
  className?: string;
}

export function TranscriptView({
  segments,
  currentMs,
  onSeek,
  className,
}: TranscriptViewProps) {
  const activeIndex = useMemo(
    () => findActiveSegment(segments, currentMs),
    [segments, currentMs],
  );
  const activeRef = useRef<HTMLLIElement>(null);

  // Keep the playing segment in view (smoothly).
  useEffect(() => {
    activeRef.current?.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }, [activeIndex]);

  if (segments.length === 0) {
    return (
      <div
        className={cn(
          "border border-dashed border-border rounded-md py-12 px-6 text-center space-y-3",
          className,
        )}
      >
        <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
          no transcript yet
        </p>
        <p className="text-sm text-cream-muted">
          Transcription runs locally and may take a moment.
        </p>
      </div>
    );
  }

  return (
    <ol className={cn("space-y-px", className)}>
      {segments.map((seg, i) => {
        const isActive = i === activeIndex;
        return (
          <li
            key={seg.id ?? `${seg.startMs}-${i}`}
            ref={isActive ? activeRef : null}
            className={cn(
              "group relative pl-6 pr-2 py-1.5 cursor-pointer transition-colors rounded-sm",
              "hover:bg-secondary/[0.25]",
              isActive && "bg-accent-500/[0.04]",
            )}
            onClick={() => onSeek(seg.startMs)}
          >
            {isActive && (
              <span
                aria-hidden
                className="absolute left-0 top-0 bottom-0 w-px bg-accent-500"
              />
            )}
            <button
              type="button"
              className="absolute left-1 top-1.5 font-mono text-[10px] tabular-figs text-cream-muted/60 group-hover:text-cream-muted transition-colors"
              tabIndex={-1}
              onClick={(e) => {
                e.stopPropagation();
                onSeek(seg.startMs);
              }}
              aria-label={`Jump to ${formatTimestamp(seg.startMs)}`}
            >
              {formatTimestamp(seg.startMs)}
            </button>
            <p className="ml-14 text-[15px] leading-relaxed text-cream/90 group-hover:text-cream transition-colors">
              {seg.text || (
                <span className="text-cream-muted/60">[silence]</span>
              )}
            </p>
          </li>
        );
      })}
    </ol>
  );
}
