import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowRight,
  ArrowLeft,
  Check,
  Mic,
  AlertCircle,
  Zap,
  Cpu,
  Download,
  HardDrive,
  Sparkles,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { ModelDownloadProgress } from "@/components/ModelDownloadProgress";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";
import { t } from "@/lib/i18n";
import type { Settings, Options, GpuInfo } from "@/lib/types";
import { StepWelcome } from "@/pages/onboarding/StepWelcome";
import { StepAudio } from "@/pages/onboarding/StepAudio";
import { StepHardware } from "@/pages/onboarding/StepHardware";
import { StepModel } from "@/pages/onboarding/StepModel";
import { StepTheme } from "@/pages/onboarding/StepTheme";
import { StepFinal } from "@/pages/onboarding/StepFinal";

// ============================================================================
// STEP CONFIGURATION
// ============================================================================

const STEPS_CONFIG = [
  {
    id: "welcome",
    title: t("onboarding.welcome"),
    subtitle: t("onboarding.welcomeSub"),
    icon: Sparkles,
  },
  {
    id: "audio",
    title: t("onboarding.audio"),
    subtitle: t("onboarding.audioSub"),
    icon: Mic,
  },
  {
    id: "hardware",
    title: t("onboarding.hardware"),
    subtitle: t("onboarding.hardwareSub"),
    icon: HardDrive,
  },
  {
    id: "model",
    title: t("onboarding.model"),
    subtitle: t("onboarding.modelSub"),
    icon: Cpu,
  },
  {
    id: "download",
    title: t("onboarding.download"),
    subtitle: t("onboarding.downloadSub"),
    icon: Download,
  },
  {
    id: "theme",
    title: t("onboarding.theme"),
    subtitle: t("onboarding.themeSub"),
    icon: Zap,
  },
  {
    id: "final",
    title: t("onboarding.final"),
    subtitle: t("onboarding.finalSub"),
    icon: Check,
  },
];

// ============================================================================
// MAIN COMPONENT
// ============================================================================

export function Onboarding() {
  const navigate = useNavigate();
  const [options, setOptions] = useState<Options | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [step, setStep] = useState(0);

  const [language, setLanguage] = useState("auto");
  const [model, setModel] = useState("tiny");
  const [autoStart, setAutoStart] = useState(true);
  const [retention] = useState(-1);
  const [theme, setTheme] = useState<Settings["theme"]>("dark");
  const [microphone, setMicrophone] = useState<number>(0);
  const [device, setDevice] = useState("auto");
  const [gpuInfo, setGpuInfo] = useState<GpuInfo | null>(null);
  const [isDownloading, setIsDownloading] = useState(false);

  useEffect(() => {
    const load = async () => {
      try {
        setError(null);
        const [optionsData, gpuData] = await Promise.all([
          api.getOptions(),
          api.getGpuInfo(),
        ]);
        setOptions(optionsData);
        setGpuInfo(gpuData);
        if (optionsData.microphones.length > 0) {
          setMicrophone(optionsData.microphones[0].id);
        }
      } catch (err) {
        console.error("Failed to load options:", err);
        setError(
          "Failed to load configuration. Please restart the application."
        );
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const refreshGpuInfo = async () => {
    try {
      const gpuData = await api.getGpuInfo();
      setGpuInfo(gpuData);
    } catch (err) {
      console.error("Failed to refresh GPU info:", err);
    }
  };

  useEffect(() => {
    const root = document.documentElement;
    const isDark =
      theme === "system"
        ? window.matchMedia("(prefers-color-scheme: dark)").matches
        : theme === "dark";
    root.classList.toggle("dark", isDark);
  }, [theme]);

  const handleFinish = async () => {
    setSaving(true);
    setError(null);
    try {
      await api.updateSettings({
        language,
        model,
        autoStart,
        retention,
        theme,
        microphone,
        device,
        onboardingComplete: true,
      });
      navigate("/dashboard");
    } catch (err) {
      console.error("Failed to save settings:", err);
      setError("Failed to save settings. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const nextStep = () => setStep((s) => s + 1);
  const prevStep = () => setStep((s) => s - 1);

  const handleDownloadStart = () => setIsDownloading(true);
  const handleDownloadComplete = () => setIsDownloading(false);
  const handleDownloadCancel = () => {
    setIsDownloading(false);
    prevStep();
  };

  if (loading) {
    return (
      <main
        className="min-h-screen flex items-center justify-center bg-background bg-dots"
        aria-busy="true"
      >
        <div className="flex flex-col items-center gap-4">
          <div className="w-8 h-8 rounded-full border-2 border-accent-500/30 border-t-accent-500 animate-spin" />
          <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-cream-muted/60">
            inicializando savia sonora…
          </p>
        </div>
      </main>
    );
  }

  if (error && !options) {
    return (
      <main className="min-h-screen flex items-center justify-center bg-background bg-dots px-6">
        <div
          className="border border-destructive/30 rounded-md bg-destructive/[0.03] p-8 max-w-md w-full text-center space-y-4"
          role="alert"
        >
          <p className="font-mono text-[11px] uppercase tracking-[0.25em] text-destructive">
            initialization failed
          </p>
          <h2 className="font-display text-xl font-medium text-cream tracking-tight">
            Something went wrong
          </h2>
          <p className="text-sm text-cream-muted leading-relaxed">{error}</p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="h-10 px-5 rounded-md border border-border bg-secondary/40 hover:bg-secondary/60 transition-colors font-mono text-xs uppercase tracking-widest text-cream-muted hover:text-cream"
          >
            try again
          </button>
        </div>
      </main>
    );
  }

  if (!options) return null;

  const currentStepConfig = STEPS_CONFIG[step];
  const isLastStep = step === STEPS_CONFIG.length - 1;
  const isFirstStep = step === 0;
  const StepIcon = currentStepConfig.icon;

  const renderStepContent = () => {
    switch (step) {
      case 0:
        return <StepWelcome />;
      case 1:
        return (
          <StepAudio
            microphone={microphone}
            setMicrophone={setMicrophone}
            options={options}
          />
        );
      case 2:
        return (
          <StepHardware
            device={device}
            setDevice={setDevice}
            gpuInfo={gpuInfo}
            onGpuInfoUpdate={refreshGpuInfo}
          />
        );
      case 3:
        return (
          <StepModel
            language={language}
            setLanguage={setLanguage}
            model={model}
            setModel={setModel}
            options={options}
            device={device}
            gpuInfo={gpuInfo}
          />
        );
      case 4:
        return (
          <ModelDownloadProgress
            modelName={model}
            onStart={handleDownloadStart}
            onComplete={handleDownloadComplete}
            onCancel={handleDownloadCancel}
            autoStart={true}
          />
        );
      case 5:
        return (
          <StepTheme
            theme={theme}
            setTheme={setTheme}
            autoStart={autoStart}
            setAutoStart={setAutoStart}
          />
        );
      case 6:
        return <StepFinal />;
      default:
        return null;
    }
  };

  return (
    <main className="h-screen flex flex-col bg-background bg-dots overflow-hidden">
      {error && options && (
        <div
          role="alert"
          className="fixed top-4 left-1/2 -translate-x-1/2 z-50 border border-destructive/30 bg-destructive/[0.05] backdrop-blur rounded-md px-4 py-2 flex items-center gap-3"
        >
          <AlertCircle
            className="w-4 h-4 flex-shrink-0 text-destructive"
            strokeWidth={2}
          />
          <span className="font-mono text-xs text-destructive">{error}</span>
        </div>
      )}

      <div className="flex-1 flex flex-col px-6 md:px-10 lg:px-16 py-6 min-h-0">
        {/* Progress indicator */}
        <div
          className="flex justify-center gap-1.5 mb-6 flex-shrink-0"
          aria-label={`Step ${step + 1} of ${STEPS_CONFIG.length}`}
        >
          {STEPS_CONFIG.map((_, idx) => (
            <button
              key={idx}
              type="button"
              onClick={() => idx < step && setStep(idx)}
              disabled={idx > step}
              aria-label={`Go to step ${idx + 1}`}
              className={cn(
                "h-1 rounded-full transition-all duration-300",
                idx === step
                  ? "w-8 bg-accent-500"
                  : idx < step
                    ? "w-5 bg-accent-500/40 hover:bg-accent-500/60 cursor-pointer"
                    : "w-1.5 bg-cream-muted/20"
              )}
            />
          ))}
        </div>

        {/* Header */}
        <header className="text-center mb-8 flex-shrink-0 space-y-3 max-w-2xl mx-auto">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 flex items-center justify-center gap-2">
            <StepIcon
              className="w-3 h-3 text-accent-500"
              strokeWidth={2.5}
            />
            step {String(step + 1).padStart(2, "0")} / {String(STEPS_CONFIG.length).padStart(2, "0")}
            <span className="text-cream-muted/30 mx-1">·</span>
            <span>{currentStepConfig.id}</span>
          </p>
          <h1 className="font-display text-3xl md:text-4xl lg:text-5xl font-medium tracking-tight text-cream leading-[1.05]">
            {(() => {
              const words = currentStepConfig.title.split(" ");
              const last = words[words.length - 1];
              const rest = words.slice(0, -1).join(" ");
              return (
                <>
                  {rest && <>{rest} </>}
                  <span className="text-accent-500">{last}</span>
                </>
              );
            })()}
          </h1>
          <p className="text-sm md:text-base text-cream-muted leading-relaxed max-w-xl mx-auto">
            {currentStepConfig.subtitle}
          </p>
        </header>

        {/* Step Content */}
        <div className="flex-1 flex items-center justify-center min-h-0 overflow-hidden">
          {renderStepContent()}
        </div>

        {/* Navigation */}
        <div className="flex items-center justify-center gap-3 pt-6 flex-shrink-0">
          {!isFirstStep && (
            <Button
              variant="ghost"
              size="lg"
              onClick={prevStep}
              disabled={isDownloading}
              className="rounded-md text-cream-muted hover:text-cream hover:bg-secondary/60 px-5"
            >
              <ArrowLeft className="mr-2 w-4 h-4" strokeWidth={2} />
              Back
            </Button>
          )}

          <button
            type="button"
            onClick={isLastStep ? handleFinish : nextStep}
            disabled={saving || isDownloading}
            className="h-11 px-6 rounded-md min-w-[160px] bg-accent-500 text-zinc-950 hover:bg-accent-600 transition-colors font-medium text-sm flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            {saving ? (
              <>
                <span className="w-3.5 h-3.5 border-2 border-current/30 border-t-current rounded-full animate-spin" />
                Saving…
              </>
            ) : isLastStep ? (
              <>
                Open dashboard
                <Check className="w-4 h-4" strokeWidth={2.5} />
              </>
            ) : (
              <>
                Continue
                <ArrowRight className="w-4 h-4" strokeWidth={2.5} />
              </>
            )}
          </button>
        </div>
      </div>

      <p className="text-center font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/40 pb-6">
        all processing happens locally · your voice never leaves your computer
      </p>
    </main>
  );
}
