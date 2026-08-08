import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Stats } from "@/lib/types";
import { cn } from "@/lib/utils";

type ConfigData = {
  model: string;
  language: string;
  micName: string;
  computeDevice: string;
  isUsingGpu: boolean;
};

type TodayStats = {
  words: number;
  entries: number;
};

interface StatsHeaderProps {
  todayStats?: TodayStats;
}

export function StatsHeader({ todayStats }: StatsHeaderProps) {
  const [stats, setStats] = useState<Stats | null>(null);
  const [config, setConfig] = useState<ConfigData | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        const statsData = await api.getStats();
        setStats(statsData);

        const [settings, options, gpuInfo] = await Promise.all([
          api.getSettings(),
          api.getOptions(),
          api.getGpuInfo(),
        ]);

        const currentMic = options.microphones.find(
          (m) => m.id === settings.microphone
        );
        const micName =
          settings.microphone === -1
            ? "System default"
            : currentMic?.name || "Unknown";

        const isUsingGpu =
          settings.device === "cuda" ||
          (settings.device === "auto" && gpuInfo.cudaAvailable);
        const computeDevice = isUsingGpu
          ? gpuInfo.gpuName
              ?.replace("NVIDIA ", "")
              .replace(" Laptop GPU", "") || "CUDA GPU"
          : "CPU";

        setConfig({
          model: settings.model,
          language: settings.language,
          micName,
          computeDevice,
          isUsingGpu,
        });
      } catch (error) {
        console.error("Failed to load stats:", error);
        setStats({
          totalTranscriptions: 0,
          totalWords: 0,
          totalCharacters: 0,
          streakDays: 0,
        });
      }
    };
    load();
  }, []);

  if (!stats) return <StatsSkeleton />;

  const streak = stats.streakDays;

  return (
    <section className="space-y-8">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-8 gap-y-8">
        <StatCell
          label="words"
          value={stats.totalWords.toLocaleString()}
          delta={
            todayStats && todayStats.words > 0
              ? `+${todayStats.words.toLocaleString()} today`
              : undefined
          }
        />
        <StatCell
          label="entries"
          value={stats.totalTranscriptions.toLocaleString()}
          delta={
            todayStats && todayStats.entries > 0
              ? `+${todayStats.entries} today`
              : undefined
          }
        />
        <StatCell
          label="chars"
          value={stats.totalCharacters.toLocaleString()}
        />
        <StatCell
          label="streak"
          value={`${streak} ${streak === 1 ? "day" : "days"}`}
          delta={streak > 0 ? "active" : "no streak yet"}
          active={streak > 0}
        />
      </div>

      <div className="border-t border-border" />

      <div>
        <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 mb-4">
          active
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-10 gap-y-2">
          <ConfigRow
            label="model"
            value={config ? capitalize(config.model) : "—"}
          />
          <ConfigRow
            label="microphone"
            value={config?.micName ?? "—"}
            truncate
          />
          <ConfigRow
            label="language"
            value={config ? formatLang(config.language) : "—"}
          />
          <ConfigRow
            label="compute"
            value={config?.computeDevice ?? "—"}
            active={config?.isUsingGpu}
            truncate
          />
        </div>
      </div>
    </section>
  );
}

function StatCell({
  label,
  value,
  delta,
  active,
}: {
  label: string;
  value: string;
  delta?: string;
  active?: boolean;
}) {
  return (
    <div className="space-y-2">
      <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60">
        {label}
      </p>
      <p
        className={cn(
          "font-display text-[2rem] md:text-4xl font-medium tracking-tight leading-none",
          active ? "text-accent-500" : "text-cream"
        )}
      >
        {value}
      </p>
      {delta && (
        <p
          className={cn(
            "font-mono text-[11px] flex items-center gap-1.5",
            active ? "text-accent-500/80" : "text-cream-muted/70"
          )}
        >
          {active && (
            <span className="w-1.5 h-1.5 rounded-full bg-accent-500" />
          )}
          {delta}
        </p>
      )}
    </div>
  );
}

function ConfigRow({
  label,
  value,
  active,
  truncate,
}: {
  label: string;
  value: string;
  active?: boolean;
  truncate?: boolean;
}) {
  return (
    <div className="flex items-baseline gap-3 min-w-0">
      <span className="font-mono text-[10px] uppercase tracking-[0.25em] text-cream-muted/60 w-24 flex-shrink-0">
        {label}
      </span>
      <span
        className={cn(
          "font-mono text-xs flex items-center gap-1.5 min-w-0",
          active ? "text-accent-500" : "text-cream",
          truncate && "truncate"
        )}
        title={truncate ? value : undefined}
      >
        {active && (
          <span className="w-1.5 h-1.5 rounded-full bg-accent-500 flex-shrink-0" />
        )}
        <span className={cn(truncate && "truncate")}>{value}</span>
      </span>
    </div>
  );
}

function StatsSkeleton() {
  return (
    <section className="space-y-8">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-x-8 gap-y-8">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="space-y-2">
            <div className="h-2 w-12 bg-secondary/50 rounded animate-pulse" />
            <div className="h-9 w-20 bg-secondary/40 rounded animate-pulse" />
            <div className="h-2 w-16 bg-secondary/40 rounded animate-pulse" />
          </div>
        ))}
      </div>
      <div className="border-t border-border" />
      <div className="space-y-3">
        <div className="h-2 w-12 bg-secondary/50 rounded animate-pulse" />
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="h-3 bg-secondary/40 rounded animate-pulse" />
          ))}
        </div>
      </div>
    </section>
  );
}

function capitalize(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function formatLang(l: string): string {
  if (l === "auto") return "auto-detect";
  return l.toUpperCase();
}
