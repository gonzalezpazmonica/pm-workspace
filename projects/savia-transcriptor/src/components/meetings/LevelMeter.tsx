/* Single-line peak-dB meter. Two of these stack inline on the recorder page —
   "you" (mic) and "them" (loopback) — laid out as horizontal bars, not the
   typical column of vertical pixel-bars.

   Input is the peak in dBFS (negative numbers; 0 = clipping). Anything below
   `floorDb` clips to 0% width. */

import { cn } from "@/lib/utils";

interface LevelMeterProps {
  label: string;
  peakDb: number | null;
  floorDb?: number;
  className?: string;
  muted?: boolean;
}

export function LevelMeter({
  label,
  peakDb,
  floorDb = -60,
  className,
  muted = false,
}: LevelMeterProps) {
  const pct = (() => {
    if (peakDb == null || muted) return 0;
    if (peakDb >= 0) return 100;
    if (peakDb <= floorDb) return 0;
    return ((peakDb - floorDb) / -floorDb) * 100;
  })();

  // Color shifts hotter as the meter climbs; warns above -6 dB.
  const overload = peakDb != null && peakDb > -6;

  return (
    <div className={cn("flex items-center gap-3", className)}>
      <span
        className={cn(
          "font-mono text-[10px] uppercase tracking-[0.25em] w-12 shrink-0",
          muted ? "text-cream-muted/40" : "text-cream-muted/70",
        )}
      >
        {label}
      </span>
      <div className="flex-1 relative h-px bg-border overflow-visible">
        <div
          className={cn(
            "absolute inset-y-[-1px] left-0 transition-[width] duration-75 ease-out",
            overload ? "bg-destructive" : "bg-accent-500",
          )}
          style={{ width: `${pct}%` }}
        />
        {/* -6 dB ticked reference */}
        <span
          aria-hidden
          className="absolute top-[-2px] bottom-[-2px] w-px bg-border/80"
          style={{ left: `${((floorDb - -6) / floorDb) * 100}%` }}
        />
      </div>
      <span
        className={cn(
          "font-mono text-[10px] tabular-figs w-10 text-right",
          muted ? "text-cream-muted/40" : "text-cream-muted",
        )}
      >
        {peakDb == null || muted ? "—" : `${peakDb.toFixed(0)}`}
      </span>
    </div>
  );
}
