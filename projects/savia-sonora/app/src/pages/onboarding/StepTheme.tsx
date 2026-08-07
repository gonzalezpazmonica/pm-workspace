import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";
import type { Settings } from "@/lib/types";
import { THEME_OPTIONS } from "@/lib/constants";

// ============================================================================
// STEP: THEME
// ============================================================================

export const StepTheme = ({
  theme,
  setTheme,
  autoStart,
  setAutoStart,
}: {
  theme: Settings["theme"];
  setTheme: (t: Settings["theme"]) => void;
  autoStart: boolean;
  setAutoStart: (b: boolean) => void;
}) => (
  <div className="space-y-8 max-w-md w-full">
    <fieldset className="space-y-3">
      <legend className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
        interface theme
      </legend>
      <div
        className="grid grid-cols-3 gap-3"
        role="radiogroup"
        aria-label="Theme selection"
      >
        {THEME_OPTIONS.map((opt) => {
          const isActive = theme === opt.val;
          return (
            <button
              key={opt.val}
              type="button"
              role="radio"
              aria-checked={isActive}
              className={cn(
                "relative p-5 rounded-md flex flex-col items-center gap-3 transition-colors border",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-500/40 focus-visible:ring-offset-1",
                isActive
                  ? "border-accent-500/40 bg-accent-500/[0.06]"
                  : "border-border bg-secondary/30 hover:bg-secondary/60"
              )}
              onClick={() => setTheme(opt.val as Settings["theme"])}
            >
              <div
                className={cn(
                  "w-12 h-12 rounded-md border border-border",
                  opt.val === "light"
                    ? "bg-[#fafafa]"
                    : opt.val === "dark"
                      ? "bg-[#09090b]"
                      : "bg-gradient-to-br from-[#fafafa] to-[#09090b]"
                )}
                aria-hidden
              />
              <span
                className={cn(
                  "font-mono text-[11px] uppercase tracking-widest",
                  isActive ? "text-cream" : "text-cream-muted"
                )}
              >
                {opt.label}
              </span>
              {isActive && (
                <span
                  className="absolute top-2 right-2 w-1.5 h-1.5 rounded-full bg-accent-500"
                  aria-hidden
                />
              )}
            </button>
          );
        })}
      </div>
    </fieldset>

    <div className="border-t border-border" />

    <div className="flex items-start justify-between gap-6">
      <div className="flex-1 min-w-0">
        <label
          htmlFor="onboarding-autostart"
          className="text-sm font-medium text-cream cursor-pointer"
        >
          Launch at login
        </label>
        <p className="text-xs text-cream-muted mt-1 leading-relaxed">
          Start VoiceFlow when you sign in to your computer.
        </p>
      </div>
      <Switch
        id="onboarding-autostart"
        checked={autoStart}
        onCheckedChange={setAutoStart}
        className="mt-0.5 flex-shrink-0"
      />
    </div>
  </div>
);
