import { ONBOARDING_FEATURES } from "@/lib/constants";

// ============================================================================
// STEP: WELCOME
// ============================================================================

export const StepWelcome = () => (
  <div className="space-y-8 max-w-2xl w-full">
    <p className="text-base md:text-lg leading-relaxed text-cream-muted text-center">
      Dictation designed for{" "}
      <span className="text-accent-500 font-medium">privacy</span> and{" "}
      <span className="text-accent-500 font-medium">flow</span>.
    </p>

    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
      {ONBOARDING_FEATURES.map((feature) => (
        <div
          key={feature.label}
          className="border border-border rounded-md bg-surface flex items-start gap-3 p-4 text-left"
        >
          <feature.icon
            className="w-4 h-4 mt-0.5 flex-shrink-0 text-accent-500"
            strokeWidth={2}
          />
          <div className="min-w-0">
            <p className="font-medium text-cream text-sm leading-tight">
              {feature.label}
            </p>
            <p className="text-[11px] text-cream-muted leading-relaxed mt-1">
              {feature.desc}
            </p>
          </div>
        </div>
      ))}
    </div>
  </div>
);
