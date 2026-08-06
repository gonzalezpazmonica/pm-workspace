import { useEffect, useState } from "react";
import { AlertCircle, Zap, Cpu, Download } from "lucide-react";
import { api } from "@/lib/api";
import { cn } from "@/lib/utils";
import type { GpuInfo } from "@/lib/types";

// ============================================================================
// STEP: HARDWARE
// ============================================================================

const DEVICE_OPTIONS = [
  {
    id: "auto",
    label: "Auto",
    desc: "Recommended",
    detail: "Best available",
    description:
      "Automatically selects the best available compute device. Uses GPU if available and properly configured, otherwise falls back to CPU.",
    icon: Zap,
    bestFor:
      "Most users who want optimal performance without manual configuration.",
  },
  {
    id: "cuda",
    label: "CUDA GPU",
    desc: "NVIDIA only",
    detail: "Fastest",
    description:
      "Uses NVIDIA GPU with CUDA acceleration for maximum transcription speed. Requires compatible NVIDIA GPU with CUDA libraries (cuDNN + cuBLAS).",
    icon: Cpu,
    bestFor:
      "Users with NVIDIA GPUs who want the fastest possible transcription.",
  },
  {
    id: "cpu",
    label: "CPU only",
    desc: "Universal",
    detail: "Compatible",
    description:
      "Uses CPU for transcription. Works on any system but slower than GPU acceleration. Good fallback option.",
    icon: Cpu,
    bestFor:
      "Systems without compatible GPU or when GPU acceleration causes issues.",
  },
];

export const StepHardware = ({
  device,
  setDevice,
  gpuInfo,
  onGpuInfoUpdate,
}: {
  device: string;
  setDevice: (d: string) => void;
  gpuInfo: GpuInfo | null;
  onGpuInfoUpdate: () => void;
}) => {
  const [deviceError, setDeviceError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);
  const [downloadError, setDownloadError] = useState<string | null>(null);
  const [downloadProgress, setDownloadProgress] = useState<{
    percent: number;
    downloadedBytes: number;
    totalBytes: number;
  } | null>(null);

  useEffect(() => {
    if (!downloading) {
      setDownloadProgress(null);
      return;
    }
    const pollProgress = async () => {
      try {
        const progress = await api.getCudnnDownloadProgress();
        if (progress.downloading) {
          setDownloadProgress({
            percent: progress.percent,
            downloadedBytes: progress.downloadedBytes,
            totalBytes: progress.totalBytes,
          });
        } else if (progress.complete) {
          setDownloading(false);
          if (progress.success) onGpuInfoUpdate();
          else if (progress.error) setDownloadError(progress.error);
        }
      } catch (err) {
        console.error("Failed to poll progress:", err);
      }
    };
    const interval = setInterval(pollProgress, 500);
    pollProgress();
    return () => clearInterval(interval);
  }, [downloading, onGpuInfoUpdate]);

  const handleDeviceSelect = async (newDevice: string) => {
    setDeviceError(null);
    const validation = await api.validateDevice(newDevice);
    if (!validation.valid) {
      setDeviceError(validation.error);
      return;
    }
    setDevice(newDevice);
  };

  const handleDownloadCudnn = async () => {
    setDownloading(true);
    setDownloadError(null);
    setDownloadProgress(null);
    try {
      const result = await api.downloadCudnn();
      if (!result.success) {
        setDownloadError(result.error || "Failed to start download");
        setDownloading(false);
      }
    } catch {
      setDownloadError("Download failed. Check your internet connection.");
      setDownloading(false);
    }
  };

  const formatBytes = (bytes: number) => {
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const showDownloadButton = gpuInfo?.gpuName && !gpuInfo?.cudnnAvailable;
  const resolvedDevice =
    device === "auto"
      ? gpuInfo?.cudaAvailable
        ? "cuda"
        : "cpu"
      : device;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6 w-full max-w-5xl h-full min-h-0">
      <div className="space-y-4 min-w-0 overflow-y-auto pr-2">
        <div className="flex items-center justify-between">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            compute device
          </p>
          <p className="font-mono text-[10px] flex items-center gap-2">
            <span className="text-cream-muted/40 uppercase tracking-widest">
              resolves to
            </span>
            <span
              className={cn(
                resolvedDevice === "cuda"
                  ? "text-accent-500"
                  : "text-cream-muted",
                "uppercase tracking-widest"
              )}
            >
              {resolvedDevice}
            </span>
          </p>
        </div>

        <div
          className="grid grid-cols-3 gap-2"
          role="radiogroup"
          aria-label="Select compute device"
        >
          {DEVICE_OPTIONS.map((d) => {
            const isActive = device === d.id;
            const isDisabled = d.id === "cuda" && !gpuInfo?.cudaAvailable;
            return (
              <button
                key={d.id}
                type="button"
                role="radio"
                aria-checked={isActive}
                disabled={isDisabled}
                className={cn(
                  "relative p-4 rounded-md text-left transition-colors flex flex-col gap-2 border",
                  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-500/40 focus-visible:ring-offset-1",
                  isActive
                    ? "bg-accent-500/[0.06] border-accent-500/40"
                    : isDisabled
                      ? "border-border bg-secondary/20 opacity-50 cursor-not-allowed"
                      : "border-border bg-secondary/30 hover:bg-secondary/60"
                )}
                onClick={() => !isDisabled && handleDeviceSelect(d.id)}
              >
                <div className="flex items-center justify-between w-full">
                  <span
                    className={cn(
                      "font-display text-sm font-medium tracking-tight",
                      isActive ? "text-cream" : "text-cream"
                    )}
                  >
                    {d.label}
                  </span>
                  {isActive && (
                    <span
                      className="w-1.5 h-1.5 rounded-full bg-accent-500 flex-shrink-0"
                      aria-hidden="true"
                    />
                  )}
                </div>
                <span className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/60">
                  {d.desc}
                </span>
                {isDisabled && (
                  <span className="font-mono text-[10px] uppercase tracking-widest text-amber-500/80 mt-auto">
                    unavailable
                  </span>
                )}
              </button>
            );
          })}
        </div>

        {deviceError && (
          <p className="font-mono text-[11px] text-destructive flex items-center gap-2 border-l-2 border-destructive/40 pl-3 py-1">
            <AlertCircle className="w-3.5 h-3.5 flex-shrink-0" strokeWidth={2} />
            {deviceError}
          </p>
        )}

        {showDownloadButton && (
          <div className="border border-amber-500/30 bg-amber-500/[0.03] rounded-md p-4 space-y-3">
            <div className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
              <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-amber-500/90">
                gpu acceleration available
              </p>
            </div>
            <p className="text-xs text-cream-muted leading-relaxed">
              Download NVIDIA CUDA libraries (cuDNN + cuBLAS) to enable GPU
              acceleration.
            </p>
            <button
              type="button"
              onClick={handleDownloadCudnn}
              disabled={downloading}
              className="w-full flex items-center justify-center gap-2 h-10 rounded-md bg-accent-500 text-zinc-950 hover:bg-accent-600 transition-colors text-sm font-medium disabled:opacity-50"
            >
              {downloading ? (
                <>
                  <span className="w-3.5 h-3.5 border-2 border-current/30 border-t-current rounded-full animate-spin" />
                  {downloadProgress
                    ? `downloading… ${downloadProgress.percent}%`
                    : "starting…"}
                </>
              ) : (
                <>
                  <Download className="w-4 h-4" strokeWidth={2.5} />
                  Download CUDA libraries (~880 MB)
                </>
              )}
            </button>
            {downloading && downloadProgress && (
              <div className="space-y-1.5">
                <div className="h-1 w-full bg-secondary/50 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-accent-500 transition-[width] duration-300 ease-out"
                    style={{ width: `${downloadProgress.percent}%` }}
                  />
                </div>
                <p className="font-mono text-[10px] text-cream-muted/70 text-center">
                  {formatBytes(downloadProgress.downloadedBytes)} /{" "}
                  {formatBytes(downloadProgress.totalBytes)}
                </p>
              </div>
            )}
            {downloadError && (
              <p className="font-mono text-[11px] text-destructive">
                {downloadError}
              </p>
            )}
          </div>
        )}
      </div>

      <HardwareDetailsPanel device={device} gpuInfo={gpuInfo} />
    </div>
  );
};

function HardwareDetailsPanel({
  device,
  gpuInfo,
}: {
  device: string;
  gpuInfo: GpuInfo | null;
}) {
  const selected = DEVICE_OPTIONS.find((d) => d.id === device);
  const status = gpuInfo?.cudaAvailable
    ? { label: "ready", tone: "accent" as const }
    : gpuInfo?.gpuName && !gpuInfo?.cudnnAvailable
      ? { label: "setup needed", tone: "amber" as const }
      : { label: "cpu mode", tone: "muted" as const };

  return (
    <div className="border border-border rounded-md bg-surface p-5 space-y-5 h-full overflow-y-auto min-h-0">
      {selected && (
        <>
          <div className="space-y-2">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              selection
            </p>
            <h3 className="font-display text-lg font-medium text-cream tracking-tight leading-tight">
              {selected.label}
            </h3>
            <p className="font-mono text-[10px] uppercase tracking-[0.2em] text-cream-muted/60">
              {selected.detail}
            </p>
          </div>

          <div className="space-y-1.5 pt-4 border-t border-border">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              best for
            </p>
            <p className="text-xs text-cream-muted leading-relaxed">
              {selected.bestFor}
            </p>
          </div>

          <div className="space-y-1.5">
            <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
              about
            </p>
            <p className="text-[11px] text-cream-muted leading-relaxed">
              {selected.description}
            </p>
          </div>
        </>
      )}

      <div className="space-y-3 pt-4 border-t border-border">
        <div className="flex items-center justify-between">
          <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
            hardware
          </p>
          <span
            className={cn(
              "font-mono text-[10px] uppercase tracking-widest",
              status.tone === "accent" && "text-accent-500",
              status.tone === "amber" && "text-amber-500",
              status.tone === "muted" && "text-cream-muted/60"
            )}
          >
            {status.label}
          </span>
        </div>

        <dl className="font-mono text-[11px] grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5">
          {gpuInfo?.gpuName && (
            <>
              <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
                gpu
              </dt>
              <dd className="text-cream truncate" title={gpuInfo.gpuName}>
                {gpuInfo.gpuName}
              </dd>
              <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
                cuda
              </dt>
              <dd
                className={
                  gpuInfo.cudaAvailable ? "text-accent-500" : "text-cream-muted"
                }
              >
                {gpuInfo.cudaAvailable ? "available" : "unavailable"}
              </dd>
              <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
                cudnn
              </dt>
              <dd
                className={
                  gpuInfo.cudnnAvailable ? "text-accent-500" : "text-amber-500"
                }
              >
                {gpuInfo.cudnnAvailable ? "installed" : "missing"}
              </dd>
            </>
          )}
          {!gpuInfo?.gpuName && (
            <>
              <dt className="text-cream-muted/60 uppercase tracking-widest text-[9px] self-center">
                device
              </dt>
              <dd className="text-cream">cpu only</dd>
            </>
          )}
        </dl>

        {gpuInfo?.supportedComputeTypes &&
          gpuInfo.supportedComputeTypes.length > 0 && (
            <div className="space-y-1.5">
              <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
                compute types
              </p>
              <div className="flex flex-wrap gap-1">
                {gpuInfo.supportedComputeTypes.map((ct) => (
                  <span
                    key={ct}
                    className="font-mono text-[10px] px-1.5 py-0.5 rounded bg-secondary/50 text-cream-muted"
                  >
                    {ct}
                  </span>
                ))}
              </div>
            </div>
          )}

        <p className="text-[11px] text-cream-muted/70 leading-relaxed pt-1">
          {gpuInfo?.cudaAvailable
            ? "Your system is fully configured for GPU acceleration."
            : gpuInfo?.gpuName && !gpuInfo?.cudnnAvailable
              ? "Download CUDA libraries from the left to enable GPU acceleration."
              : "No compatible NVIDIA GPU detected. CPU transcription works well — just slower."}
        </p>
      </div>
    </div>
  );
}
