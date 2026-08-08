import { Keyboard, Sparkles } from "lucide-react";

// ============================================================================
// STEP: FINAL
// ============================================================================

// The default hold hotkey is `ctrl+win` on every platform (see settings.py),
// but the Super key is labelled differently per OS — show the right one.
const platform =
  (navigator as unknown as { userAgentData?: { platform: string } }).userAgentData
    ?.platform ?? navigator.userAgent;
const superKeyLabel = /Mac/i.test(platform)
  ? "⌘"
  : /Linux/i.test(platform)
    ? "Super"
    : "Win";

export const StepFinal = () => (
  <div className="space-y-5 max-w-lg w-full">
    <div className="border border-border rounded-md bg-surface p-8 space-y-5">
      <div className="text-center space-y-3">
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 flex items-center justify-center gap-2">
          <Keyboard className="w-3 h-3 text-primary" strokeWidth={2.5} />
          atajo global
        </p>
        <div className="flex items-center justify-center gap-3 pt-1">
          <kbd className="min-w-[72px] py-2.5 rounded-md bg-secondary border border-border text-base font-mono font-medium text-cream">
            Ctrl
          </kbd>
          <span className="text-base text-cream-muted/40 font-mono">+</span>
          <kbd className="min-w-[72px] py-2.5 rounded-md bg-secondary border border-border text-base font-mono font-medium text-cream">
            {superKeyLabel}
          </kbd>
        </div>
        <p className="text-sm text-cream-muted">
          Mantén para grabar, suelta para transcribir.
        </p>
      </div>
    </div>

    <div className="flex items-center gap-3 px-4 py-3 border-l-2 border-accent-500/40">
      <Sparkles
        className="w-4 h-4 text-primary flex-shrink-0"
        strokeWidth={2}
      />
      <p className="text-sm text-cream-muted leading-relaxed">
        Savia Sonora corre en silencio en la bandeja del sistema. Pulsa el
        atajo en cualquier momento y sitio para empezar a dictar.
      </p>
    </div>
  </div>
);
