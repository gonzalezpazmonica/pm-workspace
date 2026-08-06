/* Compact status indicator for transcript + summary state. Matches the
   `font-mono text-[10px] uppercase tracking-[0.25em]` rhythm used by every
   metadata strip in the app. */

import type {
  Recording,
  SummaryStatus,
  TranscriptStatus,
} from "@/lib/types";
import { cn } from "@/lib/utils";

interface StatusLineProps {
  recording: Pick<
    Recording,
    | "transcriptStatus"
    | "transcriptProgress"
    | "summaryStatus"
    | "summaryProgress"
  >;
  className?: string;
}

export function StatusLine({ recording, className }: StatusLineProps) {
  const parts: Array<{ text: string; tone: "active" | "done" | "error" | "idle" }> = [];

  parts.push(transcriptPart(recording.transcriptStatus, recording.transcriptProgress));
  if (recording.transcriptStatus === "done") {
    parts.push(summaryPart(recording.summaryStatus, recording.summaryProgress));
  }

  return (
    <span
      className={cn(
        "inline-flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.25em]",
        className,
      )}
    >
      {parts.map((part, i) => (
        <span key={i} className="flex items-center gap-2">
          {i > 0 && <span aria-hidden className="text-cream-muted/30">·</span>}
          <span
            className={cn(
              "flex items-center gap-1.5",
              part.tone === "active" && "text-accent-500",
              part.tone === "done" && "text-cream-muted",
              part.tone === "error" && "text-destructive",
              part.tone === "idle" && "text-cream-muted/60",
            )}
          >
            {part.tone === "active" && (
              <span className="w-1 h-1 rounded-full bg-current animate-pulse" />
            )}
            {part.text}
          </span>
        </span>
      ))}
    </span>
  );
}

function transcriptPart(
  status: TranscriptStatus,
  progress: number,
): { text: string; tone: "active" | "done" | "error" | "idle" } {
  switch (status) {
    case "pending":
      return { text: "queued", tone: "idle" };
    case "transcribing":
      return { text: `transcribing · ${Math.round(progress * 100)}%`, tone: "active" };
    case "done":
      return { text: "transcribed", tone: "done" };
    case "error":
      return { text: "transcribe failed", tone: "error" };
    case "cancelled":
      return { text: "transcribe cancelled", tone: "idle" };
  }
}

function summaryPart(
  status: SummaryStatus,
  progress: number,
): { text: string; tone: "active" | "done" | "error" | "idle" } {
  switch (status) {
    case "idle":
      return { text: "no summary", tone: "idle" };
    case "summarizing":
      return { text: `summarizing · ${Math.round(progress * 100)}%`, tone: "active" };
    case "done":
      return { text: "summarized", tone: "done" };
    case "error":
      return { text: "summary failed", tone: "error" };
  }
}
