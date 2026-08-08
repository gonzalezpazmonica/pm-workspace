import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { cn } from "@/lib/utils";
import type { Options, GpuInfo } from "@/lib/types";
import {
  MODEL_OPTIONS,
  MODEL_CATEGORIES,
  isEnglishOnlyModel,
} from "@/lib/constants";

// ============================================================================
// STEP: MODEL
// ============================================================================

const RatingBar = ({
  value,
  max = 5,
  label,
}: {
  value: number;
  max?: number;
  label: string;
}) => (
  <div className="flex items-center gap-3">
    <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/60 w-16 flex-shrink-0">
      {label}
    </span>
    <div className="flex gap-0.5 flex-1">
      {Array.from({ length: max }).map((_, i) => (
        <div
          key={i}
          className={cn(
            "h-1 flex-1 rounded-full",
            i < value ? "bg-accent-500" : "bg-cream-muted/15"
          )}
        />
      ))}
    </div>
  </div>
);

export const StepModel = ({
  language,
  setLanguage,
  model,
  setModel,
  options,
  device,
  gpuInfo,
}: {
  language: string;
  setLanguage: (l: string) => void;
  model: string;
  setModel: (m: string) => void;
  options: Options;
  device: string;
  gpuInfo: GpuInfo | null;
}) => {
  const selectedModel = MODEL_OPTIONS.find((m) => m.id === model);
  const categoryInfo = selectedModel
    ? MODEL_CATEGORIES[selectedModel.category]
    : null;
  const resolvedDevice =
    device === "auto" ? (gpuInfo?.cudaAvailable ? "cuda" : "cpu") : device;

  const handleModelSelect = (modelId: string) => {
    setModel(modelId);
    if (isEnglishOnlyModel(modelId) && language !== "en") setLanguage("en");
  };

  const handleLanguageChange = (nextLanguage: string) => {
    // English-only models can't transcribe other languages — keep "en" locked
    // in while one is selected.
    if (isEnglishOnlyModel(model) && nextLanguage !== "en") return;
    setLanguage(nextLanguage);
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6 w-full max-w-6xl h-full min-h-0">
      <div className="space-y-5 min-w-0 overflow-y-auto pr-2">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 mb-2">
            language
          </p>
          <Select value={language} onValueChange={handleLanguageChange}>
            <SelectTrigger className="h-10 bg-secondary/40 border-border hover:bg-secondary/60 transition-colors rounded-md max-w-sm">
              <SelectValue />
            </SelectTrigger>
            <SelectContent className="max-h-[280px]">
              {options.languages.map((lang) => (
                <SelectItem key={lang} value={lang}>
                  {lang === "auto" ? "Auto-detect" : lang.toUpperCase()}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              model
            </p>
            <div className="flex items-center gap-3 font-mono text-[10px] uppercase tracking-widest">
              <span
                className={
                  resolvedDevice === "cuda"
                    ? "text-accent-500"
                    : "text-cream-muted/60"
                }
              >
                {resolvedDevice}
              </span>
              <span className="text-cream-muted/30">·</span>
              <span className="text-accent-500/80">local only</span>
            </div>
          </div>

          <div
            className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2"
            role="radiogroup"
            aria-label="Select processing model"
          >
            {MODEL_OPTIONS.map((m) => {
              const isActive = model === m.id;
              return (
                <button
                  key={m.id}
                  type="button"
                  role="radio"
                  aria-checked={isActive}
                  className={cn(
                    "relative p-3 rounded-md text-left transition-colors flex flex-col gap-1 border",
                    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-500/40 focus-visible:ring-offset-1",
                    isActive
                      ? "bg-accent-500/[0.06] border-accent-500/40"
                      : "border-border bg-secondary/30 hover:bg-secondary/60"
                  )}
                  onClick={() => handleModelSelect(m.id)}
                >
                  <div className="flex items-center justify-between w-full">
                    <span className="font-display text-sm font-medium tracking-tight text-cream">
                      {m.label}
                    </span>
                    {isActive && (
                      <span
                        className="w-1.5 h-1.5 rounded-full bg-accent-500 flex-shrink-0"
                        aria-hidden="true"
                      />
                    )}
                  </div>
                  <span className="font-mono text-[10px] text-cream-muted/70">
                    {m.detail}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {selectedModel && (
        <div className="border border-border rounded-md bg-surface p-5 space-y-5 h-full overflow-y-auto min-h-0">
          <div className="space-y-2">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 flex items-center justify-between">
              <span>model</span>
              {categoryInfo && (
                <span
                  className={cn(
                    "normal-case tracking-normal text-[11px]",
                    categoryInfo.color
                  )}
                >
                  {categoryInfo.label}
                </span>
              )}
            </p>
            <h3 className="font-display text-lg font-medium text-cream tracking-tight leading-tight">
              {selectedModel.label}
            </h3>
            <p className="text-xs text-cream-muted leading-relaxed">
              {selectedModel.desc}
            </p>
          </div>

          <div className="space-y-2 pt-4 border-t border-border">
            <RatingBar value={selectedModel.speed} label="speed" />
            <RatingBar value={selectedModel.accuracy} label="accuracy" />
          </div>

          <dl className="font-mono text-[11px] grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 pt-4 border-t border-border">
            <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
              detail
            </dt>
            <dd className="text-cream">{selectedModel.detail}</dd>
            <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
              size
            </dt>
            <dd className="text-cream">{selectedModel.size}</dd>
          </dl>

          <div className="space-y-1.5 pt-4 border-t border-border">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              best for
            </p>
            <p className="text-xs text-cream-muted leading-relaxed">
              {selectedModel.bestFor}
            </p>
          </div>

          <div className="space-y-1.5">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              about
            </p>
            <p className="text-[11px] text-cream-muted leading-relaxed">
              {selectedModel.description}
            </p>
          </div>
        </div>
      )}
    </div>
  );
};
